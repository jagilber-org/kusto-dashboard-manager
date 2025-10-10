#!/usr/bin/env python3
import asyncio
import json

class PlaywrightMCPClient:
    def __init__(self):
        self.proc = None
        self.stdin = None
        self.stdout = None
        self.request_id = 1
        self.connected = False
        # On Windows, use cmd.exe to run npx
        import platform
        if platform.system() == "Windows":
            self.server_command = ["cmd", "/c", "npx", "@playwright/mcp@latest"]
        else:
            self.server_command = ["npx", "@playwright/mcp@latest"]
        self.verbose = True
    
    async def _read_message(self, timeout=10.0):
        try:
            line = await asyncio.wait_for(self.stdout.readline(), timeout=timeout)
            if not line:
                return None
            return json.loads(line.decode('utf-8').strip())
        except Exception:
            return None
    
    async def _send_request(self, payload):
        message = json.dumps(payload) + '\n'
        try:
            self.stdin.write(message.encode('utf-8'))
            await self.stdin.drain()
            if self.verbose:
                print(f"   → {payload.get('method', 'unknown')}")
        except Exception as e:
            if self.verbose:
                print(f"[!] Send failed: {e}")
            return None
        response = await self._read_message(timeout=15.0)
        if response and self.verbose:
            if 'result' in response:
                print(f"   [+] Response received")
        return response
    
    async def connect(self):
        if self.connected:
            return True
        try:
            if self.verbose:
                print("[*] Starting Playwright MCP...")
            self.proc = await asyncio.create_subprocess_exec(
                *self.server_command,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            self.stdin = self.proc.stdin
            self.stdout = self.proc.stdout
            self.stderr = self.proc.stderr
            
            if not self.stdin or not self.stdout:
                raise Exception("Failed to create subprocess pipes")
            
            # Give the process a moment to start
            await asyncio.sleep(0.5)
            
            init_req = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "kusto-dashboard-manager", "version": "1.0.0"}
                }
            }
            self.request_id += 1
            resp = await self._send_request(init_req)
            if resp and 'result' in resp:
                if self.verbose:
                    info = resp['result'].get('serverInfo', {})
                    print(f"[+] Connected to {info.get('name', 'MCP')} v{info.get('version', '?')}")
                self.connected = True
                notif = {"jsonrpc": "2.0", "method": "notifications/initialized"}
                self.stdin.write((json.dumps(notif) + '\n').encode('utf-8'))
                await self.stdin.drain()
                return True
            return False
        except Exception as e:
            if self.verbose:
                print(f"[!] Error: {e}")
            return False
    
    async def disconnect(self):
        if self.proc:
            try:
                if self.stdin:
                    self.stdin.close()
                    await self.stdin.wait_closed()
                self.proc.terminate()
                await asyncio.wait_for(self.proc.wait(), timeout=2.0)
            except:
                if self.proc:
                    self.proc.kill()
            finally:
                self.proc = None
                self.stdin = None
                self.stdout = None
                self.stderr = None
                self.connected = False
    
    async def list_tools(self):
        req = {"jsonrpc": "2.0", "id": self.request_id, "method": "tools/list", "params": {}}
        self.request_id += 1
        resp = await self._send_request(req)
        if resp and 'result' in resp:
            return resp['result'].get('tools', [])
        return []
    
    async def call_tool(self, name, arguments):
        req = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments}
        }
        self.request_id += 1
        resp = await self._send_request(req)
        if not resp or 'result' not in resp:
            return None
        content = resp['result'].get('content')
        if content and isinstance(content, list) and len(content) > 0:
            first = content[0]
            if first.get('type') == 'text':
                try:
                    return json.loads(first.get('text', ''))
                except:
                    return {"raw": first.get('text', '')}
        return resp['result']

WorkingPyMCPClient = PlaywrightMCPClient
SimplePyMCPClient = PlaywrightMCPClient
