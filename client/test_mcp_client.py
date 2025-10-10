#!/usr/bin/env python3
"""
Simple MCP client to test the kusto-dashboard-manager MCP server
"""
import asyncio
import json
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))


class MCPClient:
    """Simple JSON-RPC client for testing MCP servers"""
    
    def __init__(self):
        self.request_id = 1
        self.proc = None
        self.stdin = None
        self.stdout = None
    
    async def start_server(self):
        """Start the MCP server as subprocess"""
        server_dir = Path(__file__).parent.parent
        print(f"[*] Starting MCP server from {server_dir}")
        
        self.proc = await asyncio.create_subprocess_exec(
            sys.executable, "-m", "src.mcp_server",
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(server_dir)
        )
        
        self.stdin = self.proc.stdin
        self.stdout = self.proc.stdout
        
        print("[+] Server process started")
    
    async def send_request(self, method: str, params: dict = None):
        """Send JSON-RPC request to server"""
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }
        self.request_id += 1
        
        message = json.dumps(request) + "\n"
        print(f"\n→ Sending: {method}")
        
        self.stdin.write(message.encode('utf-8'))
        await self.stdin.drain()
        
        # Read response
        line = await self.stdout.readline()
        if not line:
            print("[!] No response received")
            return None
        
        line_str = line.decode('utf-8')
        print(f"← Raw response: {line_str[:200]}")
        
        try:
            response = json.loads(line_str)
            print(f"← Received response (id={response.get('id')})")
        except json.JSONDecodeError as e:
            print(f"[!] JSON parse error: {e}")
            print(f"[!] Full line: {line_str}")
            return None
        
        if 'error' in response:
            print(f"[!] Error: {response['error']}")
            return None
        
        return response.get('result')
    
    async def initialize(self):
        """Initialize the MCP session"""
        result = await self.send_request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        })
        
        if result:
            print(f"[+] Server: {result.get('serverInfo', {}).get('name')}")
            print(f"[+] Capabilities: {list(result.get('capabilities', {}).keys())}")
        
        # Send initialized notification (no response expected)
        # Skip this for now - not critical for testing
        
        return result
    
    async def list_tools(self):
        """List available tools"""
        result = await self.send_request("tools/list")
        if result:
            tools = result.get('tools', [])
            print(f"\n[+] Available tools ({len(tools)}):")
            for tool in tools:
                print(f"  - {tool['name']}")
                print(f"    {tool.get('description', 'No description')[:80]}")
        return result
    
    async def call_tool(self, name: str, arguments: dict):
        """Call a tool"""
        result = await self.send_request("tools/call", {
            "name": name,
            "arguments": arguments
        })
        
        if result:
            content = result.get('content', [])
            if content and len(content) > 0:
                text = content[0].get('text', '')
                try:
                    data = json.loads(text)
                    print(f"\n[+] Tool result:")
                    print(json.dumps(data, indent=2))
                    return data
                except:
                    print(f"\n[+] Tool result: {text[:200]}")
                    return text
        
        return None
    
    async def shutdown(self):
        """Shutdown the server"""
        if self.stdin:
            self.stdin.close()
            await self.stdin.wait_closed()
        
        if self.proc:
            try:
                self.proc.terminate()
                await asyncio.wait_for(self.proc.wait(), timeout=2.0)
            except asyncio.TimeoutError:
                self.proc.kill()
                await self.proc.wait()
        
        print("\n[*] Server shutdown")


async def test_parse_dashboards():
    """Test the parse_dashboards_from_snapshot tool with sample data"""
    client = MCPClient()
    
    try:
        # Start server
        await client.start_server()
        await asyncio.sleep(1)  # Give server time to start
        
        # Initialize
        await client.initialize()
        
        # List tools
        await client.list_tools()
        
        # Test with simple snapshot data
        print("\n" + "="*60)
        print("Testing parse_dashboards_from_snapshot")
        print("="*60)
        
        sample_snapshot = """
- row "test-dashboard 1 day ago 10/10/2025 Jason Gilbertson" [ref=e1]:
  - rowheader "test-dashboard" [ref=e2]:
    - link "test-dashboard" [ref=e3]:
      - /url: /dashboards/12345678-1234-1234-1234-123456789abc
  - gridcell "1 day ago" [ref=e4]
  - gridcell "10/10/2025" [ref=e5]
  - gridcell "Jason Gilbertson" [ref=e6]
"""
        
        result = await client.call_tool("parse_dashboards_from_snapshot", {
            "snapshot_yaml": sample_snapshot,
            "creatorFilter": "Jason Gilbertson"
        })
        
        if result:
            print("\n✅ Test PASSED - Tool working!")
        else:
            print("\n❌ Test FAILED - No result returned")
    
    except Exception as e:
        print(f"\n❌ Test FAILED with error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        await client.shutdown()


async def main():
    """Main entry point"""
    print("="*60)
    print("MCP Server Test Client")
    print("="*60)
    
    await test_parse_dashboards()


if __name__ == "__main__":
    asyncio.run(main())
