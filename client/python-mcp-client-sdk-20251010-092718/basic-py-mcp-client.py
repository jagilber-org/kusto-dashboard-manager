#!/usr/bin/env python3

"""
Basic Python MCP Client - No Unicode Dependencies
Minimal MCP client for testing server connectivity
"""

import json
import subprocess
import sys
import time
from typing import Optional, Dict, Any, List

class BasicPyMCPClient:
    """Basic Python MCP client using JSON-RPC over stdio."""
    
    def __init__(self):
        self.server_process: Optional[subprocess.Popen] = None
        self.request_id = 1
    
    def connect(self, server_command: List[str]) -> bool:
        """Connect to MCP server."""
        try:
            print(f"Connecting to server: {' '.join(server_command)}")
            
            self.server_process = subprocess.Popen(
                server_command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            time.sleep(1)
            
            if self.server_process.poll() is not None:
                stderr_output = self.server_process.stderr.read()
                print(f"Server process exited early: {stderr_output}")
                return False
            
            init_request = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "basic-py-client", "version": "1.0.0"}
                }
            }
            self.request_id += 1
            
            self._send_request(init_request)
            response = self._read_response(timeout=5)
            
            if response and "result" in response:
                print("SUCCESS: Connected and initialized")
                return True
            else:
                print(f"FAILED: Initialization failed. Response: {response}")
                return False
                
        except Exception as error:
            print(f"ERROR: Connection failed: {error}")
            return False
    
    def _send_request(self, request: Dict[str, Any]) -> None:
        """Send JSON-RPC request."""
        if not self.server_process or not self.server_process.stdin:
            raise Exception("Server process not available")
        
        request_json = json.dumps(request)
        self.server_process.stdin.write(request_json + '\n')
        self.server_process.stdin.flush()
        print(f"SENT: {request_json[:100]}...")
    
    def _read_response(self, timeout: float = 5.0) -> Optional[Dict[str, Any]]:
        """Read JSON-RPC response with timeout."""
        if not self.server_process or not self.server_process.stdout:
            return None
        
        try:
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                self.server_process.poll()
                
                try:
                    line = self.server_process.stdout.readline()
                    if line.strip():
                        response = json.loads(line.strip())
                        print(f"RECEIVED: {str(response)[:100]}...")
                        return response
                except json.JSONDecodeError:
                    continue
                except Exception:
                    continue
                
                time.sleep(0.1)
            
            print(f"TIMEOUT: No response after {timeout}s")
            return None
            
        except Exception as error:
            print(f"ERROR: Failed to read response: {error}")
            return None
    
    def list_tools(self) -> List[Dict[str, Any]]:
        """List available tools."""
        try:
            request = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "tools/list",
                "params": {}
            }
            self.request_id += 1
            
            self._send_request(request)
            response = self._read_response()
            
            if response and "result" in response and "tools" in response["result"]:
                tools = response["result"]["tools"]
                print("Available tools:")
                for i, tool in enumerate(tools, 1):
                    print(f"  {i}. {tool.get('name', 'unknown')}: {tool.get('description', 'no description')}")
                return tools
            else:
                print(f"FAILED: No tools. Response: {response}")
                return []
            
        except Exception as error:
            print(f"ERROR: Tool listing failed: {error}")
            return []
    
    def call_tool(self, tool_name: str, args: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Call a tool with arguments."""
        try:
            request = {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": args
                }
            }
            self.request_id += 1
            
            self._send_request(request)
            response = self._read_response()
            
            if response and "result" in response:
                content = response["result"].get("content", [])
                if content and len(content) > 0:
                    result_text = content[0].get("text", "")
                    print(f"Tool '{tool_name}' result: {result_text}")
                    
                    try:
                        return json.loads(result_text)
                    except json.JSONDecodeError:
                        return {"raw_result": result_text}
                else:
                    print(f"ERROR: No content in response: {response}")
                    return None
            else:
                print(f"ERROR: Tool call failed. Response: {response}")
                return None
                
        except Exception as error:
            print(f"ERROR: Tool call failed: {error}")
            return None
    
    def disconnect(self):
        """Disconnect from server."""
        try:
            if self.server_process:
                self.server_process.terminate()
                self.server_process.wait(timeout=5)
            print("Disconnected from server")
        except Exception as error:
            print(f"WARNING: Disconnect issue: {error}")
    
    def run_tests(self) -> bool:
        """Run tests."""
        print("Starting Basic Python MCP Client Tests...")
        print("=" * 50)
        
        test_results = []
        
        # Test 1: Connection
        print("\n1. Testing server connection...")
        connected = self.connect(['node', 'simple-mcp-server.js'])
        test_results.append(("Connection", connected))
        
        if not connected:
            print("Cannot proceed without connection")
            return False
        
        # Test 2: Tool listing
        print("\n2. Testing tool listing...")
        tools = self.list_tools()
        tools_success = len(tools) > 0
        test_results.append(("Tool Listing", tools_success))
        
        # Test 3: Echo tool
        print("\n3. Testing echo tool...")
        echo_result = self.call_tool('echo', {'message': 'Hello from Basic Python!'})
        echo_success = echo_result and echo_result.get('message') == 'Hello from Basic Python!'
        test_results.append(("Echo Tool", echo_success))
        
        # Test 4: Math tool
        print("\n4. Testing math tool...")
        math_result = self.call_tool('math', {'operation': 'multiply', 'a': 6, 'b': 7})
        math_success = math_result and math_result.get('result') == 42
        test_results.append(("Math Tool", math_success))
        
        # Cleanup
        self.disconnect()
        
        # Summary
        print("\n" + "=" * 50)
        print("TEST SUMMARY:")
        all_passed = True
        for test_name, passed in test_results:
            status = "PASS" if passed else "FAIL"
            print(f"  {test_name}: {status}")
            if not passed:
                all_passed = False
        
        print(f"\nOverall Result: {'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")
        return all_passed


def main():
    """Main entry point."""
    try:
        client = BasicPyMCPClient()
        success = client.run_tests()
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\nTests interrupted by user")
        return 1
    except Exception as e:
        print(f"Test execution failed: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
