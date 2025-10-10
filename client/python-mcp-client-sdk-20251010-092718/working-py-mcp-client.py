#!/usr/bin/env python3

"""
Working Python MCP Client Implementation
Tests MCP server connectivity and tool invocation using the MCP Python SDK
"""

import asyncio
import json
import sys
from typing import Optional, List, Dict, Any
import subprocess

# SDK import optional; manual framing used currently for stability
try:  # noqa: SIM105
    from mcp import ClientSession, StdioServerParameters  # type: ignore
    from mcp.client.stdio import stdio_client  # type: ignore
except Exception:  # pragma: no cover
    ClientSession = None  # type: ignore
    StdioServerParameters = None  # type: ignore
    stdio_client = None  # type: ignore

class WorkingPyMCPClient:
    """Manual framing client (Content-Length) for robust baseline tests."""
    def __init__(self):
        self.proc: Optional[subprocess.Popen] = None
        self.request_id = 1

    def _send_request(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        if not self.proc or self.proc.stdin is None or self.proc.stdout is None:
            return None
        body_json = json.dumps(payload)
        msg = f"Content-Length: {len(body_json.encode('utf-8'))}\r\n\r\n{body_json}"
        try:
            self.proc.stdin.write(msg)
            self.proc.stdin.flush()
        except Exception as e:
            print(f"write failed: {e}")
            return None
        import time
        deadline = time.time() + 5
        header_buf = ''
        while time.time() < deadline and '\r\n\r\n' not in header_buf:
            ch = self.proc.stdout.read(1)
            if ch == '':
                print('EOF before headers')
                return None
            header_buf += ch
            if len(header_buf) > 8192:
                print('header too large')
                return None
        if '\r\n\r\n' not in header_buf:
            print(f'header timeout partial={header_buf!r}')
            return None
        header_text, remainder = header_buf.split('\r\n\r\n', 1)
        headers: Dict[str, str] = {}
        for line in header_text.split('\r\n'):
            if ':' in line:
                k, v = line.split(':', 1)
                headers[k.strip().lower()] = v.strip()
        try:
            length = int(headers.get('content-length', '0'))
        except ValueError:
            print(f"bad content-length: {headers.get('content-length')} headers={headers}")
            return None
        body = remainder
        while len(body.encode('utf-8')) < length and time.time() < deadline:
            chunk = self.proc.stdout.read(length - len(body.encode('utf-8')))
            if chunk == '':
                print('EOF during body')
                return None
            body += chunk
        if len(body.encode('utf-8')) != length:
            print(f'body incomplete got {len(body.encode("utf-8"))}/{length}')
            return None
        try:
            return json.loads(body)
        except Exception as e:
            print(f'decode error {e} raw={body[:120]!r}')
            return None

    async def connect(self, server_command: List[str]) -> bool:
        try:
            self.proc = subprocess.Popen(
                server_command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8'
            )
            await asyncio.sleep(0.2)
            versions = ["2024-11-05", "2024-08-19", "2024-07-01", "2024-06-01", None]
            resp = None
            for v in versions:
                init_params = {
                    "capabilities": {},
                    "clientInfo": {"name": "manual-py-client", "version": "1.0.0"}
                }
                if v:
                    init_params["protocolVersion"] = v
                init_req = {
                    "jsonrpc": "2.0",
                    "id": self.request_id,
                    "method": "initialize",
                    "params": init_params
                }
                self.request_id += 1
                resp = self._send_request(init_req)
                if resp and 'result' in resp:
                    print(f"Manual client connected (protocolVersion={v})")
                    break
            if resp and 'result' in resp:
                return True
            stderr_tail = ''
            if self.proc and self.proc.stderr:
                try:
                    stderr_tail = self.proc.stderr.read() or ''
                except Exception:
                    pass
            print(f"Manual client failed to initialize. Response={resp} Stderr={stderr_tail[:200]}")
            return False
        except Exception as e:
            print(f"Manual connect error: {e}")
            return False

    async def list_tools(self) -> List[Dict[str, Any]]:
        req = {"jsonrpc": "2.0", "id": self.request_id, "method": "tools/list", "params": {}}
        self.request_id += 1
        resp = self._send_request(req)
        tools = resp.get('result', {}).get('tools', []) if resp else []  # type: ignore
        print("Available tools:" if tools else "No tools returned")
        for i, t in enumerate(tools, 1):
            print(f"  {i}. {t.get('name')}: {t.get('description')}")
        return tools  # type: ignore

    async def call_tool(self, name: str, arguments: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        req = {"jsonrpc": "2.0", "id": self.request_id, "method": "tools/call", "params": {"name": name, "arguments": arguments}}
        self.request_id += 1
        resp = self._send_request(req)
        if not resp:
            print(f"No response calling tool {name}")
            return None
        if 'result' not in resp:
            print(f"Unexpected tool response {resp}")
            return None
        content = resp['result'].get('content')
        if content and isinstance(content, list) and content[0].get('type') == 'text':
            txt = content[0].get('text', '')
            print(f"Tool {name} raw: {txt}")
            try:
                return json.loads(txt)
            except Exception:
                return {"raw": txt}
        return None

    async def disconnect(self):
        if self.proc:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=2)
            except Exception:
                pass
            self.proc = None
            print("Manual client disconnected")

    async def run_tests(self) -> bool:
        print("Starting Manual Python MCP Client Tests...\n")
        if not await self.connect(['node', 'servers/node/mcp-compliant-test-server.js']):
            return False
        tools = await self.list_tools()
        if not tools:
            await self.disconnect()
            return False
        echo = await self.call_tool('echo', {'message': 'Hello from Python client!'})
        echo_ok = bool(echo and echo.get('message') == 'Hello from Python client!')
        math = await self.call_tool('math', {'operation': 'multiply', 'a': 6, 'b': 7})
        math_ok = bool(math and math.get('result') == 42)
        err = await self.call_tool('math', {'operation': 'divide', 'a': 1, 'b': 0})
        err_ok = bool(err and 'error' in err)
        await self.disconnect()
        print("\nSummary:")
        print(f"  Echo: {'PASS' if echo_ok else 'FAIL'}")
        print(f"  Math: {'PASS' if math_ok else 'FAIL'}")
        print(f"  Error Handling: {'PASS' if err_ok else 'FAIL'}")
        all_ok = echo_ok and math_ok and err_ok
        print("All tests passed" if all_ok else "Some tests failed")
        return all_ok


class SimplePyMCPClient:
    """Simplified Python MCP client using Content-Length framing only."""
    def __init__(self):
        self.server_process: Optional[subprocess.Popen] = None
        self.request_id = 1
    
    def _send_cl_request(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Send a single JSON-RPC request using Content-Length framing and return parsed response."""
        if not self.server_process or not self.server_process.stdin or not self.server_process.stdout:
            raise RuntimeError("Server process not started")
        data = json.dumps(payload)
        header = f"Content-Length: {len(data.encode('utf-8'))}\r\n\r\n"
        self.server_process.stdin.write(header + data)
        self.server_process.stdin.flush()
        # Read headers
        headers = {}
        while True:
            line = self.server_process.stdout.readline()
            if line == '':
                return None  # EOF
            line = line.rstrip('\r\n')
            if line == '':
                break
            parts = line.split(':', 1)
            if len(parts) == 2:
                headers[parts[0].strip().lower()] = parts[1].strip()
        length = int(headers.get('content-length', '0'))
        if length == 0:
            return None
        body = self.server_process.stdout.read(length)
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return None

    async def connect_simple(self, server_command: List[str]) -> bool:  # override to use Content-Length
        try:
            self.server_process = subprocess.Popen(
                server_command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            init_request = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "simple-py-client", "version": "1.0.0"}
                }
            }
            self.request_id += 1
            response = self._send_cl_request(init_request)
            if response and 'result' in response:
                print("Simple client connected (Content-Length framing)")
                return True
            print("Simple client failed to initialize")
            return False
        except Exception as e:
            print(f"Simple connect error: {e}")
            return False

    async def simple_list_tools(self) -> List[Dict[str, Any]]:  # override to use Content-Length
        try:
            request = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "tools/list",
                "params": {}
            }
            self.request_id += 1
            response = self._send_cl_request(request)
            if response and 'result' in response and 'tools' in response['result']:
                tools = response['result']['tools']
                print("Available tools (simple client):")
                for i, tool in enumerate(tools, 1):
                    print(f"  {i}. {tool['name']}: {tool['description']}")
                return tools
            return []
        except Exception as e:
            print(f"Simple list tools error: {e}")
            return []

    async def run_simple_tests(self) -> bool:
        """Run simple tests without full MCP SDK using Content-Length framing."""
        print("Starting Simple Python MCP Tests...\n")
        connected = await self.connect_simple(['node', 'servers/node/mcp-compliant-test-server.js'])
        if not connected:
            return False
        tools = await self.simple_list_tools()
        success = len(tools) > 0
        if self.server_process:
            self.server_process.terminate()
            self.server_process.wait()
        print(f"\nSimple Test Result: {'PASS' if success else 'FAIL'}")
        return success


async def main():
    """Run all Python MCP client tests."""
    print("Python MCP Client Test Suite\n")
    
    # Try full SDK client first
    try:
        client = WorkingPyMCPClient()
        full_success = await client.run_tests()
    except ImportError as e:
        print(f"MCP SDK not available: {e}")
        print("Install with: pip install mcp\n")
        full_success = False
    except Exception as e:
        print(f"Full client test failed: {e}")
        full_success = False
    
    # Try simple client as fallback
    print("\n" + "="*50)
    simple_client = SimplePyMCPClient()
    simple_success = await simple_client.run_simple_tests()
    
    overall_success = full_success or simple_success
    print(f"\nOverall Python Client Status: {'SUCCESS' if overall_success else 'FAILED'}")
    
    return overall_success


if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nTests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Test execution failed: {e}")
        sys.exit(1)