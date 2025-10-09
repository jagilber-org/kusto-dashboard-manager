"""
Kusto Dashboard Manager MCP Server
Exposes dashboard operations as MCP tools for VS Code Copilot
"""
import asyncio
import json
import sys
import os
from pathlib import Path
from typing import Any, Dict, List

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dashboard_export import DashboardExporter
from dashboard_import import DashboardImporter
from playwright_mcp_client import PlaywrightMCPClient
from config import Config
from utils import get_logger, validate_dashboard_url

class KustoDashboardMCPServer:
    """MCP Server for Kusto Dashboard Management"""
    
    def __init__(self):
        self.logger = get_logger()
        self.config = Config()
        self.mcp_client = PlaywrightMCPClient()
        self.request_id = 0
        
    def _next_id(self) -> int:
        """Generate next request ID"""
        self.request_id += 1
        return self.request_id
    
    def _create_response(self, id: int, result: Any = None, error: Dict = None) -> Dict:
        """Create JSON-RPC 2.0 response"""
        response = {"jsonrpc": "2.0", "id": id}
        if error:
            response["error"] = error
        else:
            response["result"] = result
        return response
    
    def _create_error(self, code: int, message: str, data: Any = None) -> Dict:
        """Create JSON-RPC error object"""
        error = {"code": code, "message": message}
        if data:
            error["data"] = data
        return error
    
    async def _export_dashboard(self, url: str, output_path: str = None) -> Dict:
        """Export a single dashboard"""
        try:
            exporter = DashboardExporter(self.mcp_client, self.config.data)
            path = await exporter.export_dashboard(url, output_path)
            return {
                "success": True,
                "outputPath": path,
                "url": url
            }
        except Exception as e:
            self.logger.error(f"Export failed: {e}")
            raise
    
    async def _import_dashboard(self, url: str, json_path: str, force: bool = False) -> Dict:
        """Import a dashboard from JSON"""
        try:
            importer = DashboardImporter(self.mcp_client, self.config.data)
            result = await importer.import_dashboard(url, json_path, force)
            return {
                "success": True,
                "url": url,
                "jsonPath": json_path,
                "result": result
            }
        except Exception as e:
            self.logger.error(f"Import failed: {e}")
            raise
    
    async def _validate_dashboard(self, json_path: str) -> Dict:
        """Validate dashboard JSON without importing"""
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Check required fields
            required = ["name", "tiles"]
            missing = [field for field in required if field not in data]
            
            if missing:
                return {
                    "valid": False,
                    "errors": [f"Missing required field: {field}" for field in missing]
                }
            
            return {
                "valid": True,
                "name": data.get("name"),
                "tileCount": len(data.get("tiles", [])),
                "metadata": data.get("_metadata", {})
            }
        except json.JSONDecodeError as e:
            return {
                "valid": False,
                "errors": [f"Invalid JSON: {str(e)}"]
            }
        except Exception as e:
            return {
                "valid": False,
                "errors": [str(e)]
            }
    
    async def _export_all_dashboards(self, list_url: str = "https://dataexplorer.azure.com/dashboards") -> Dict:
        """Export all dashboards created by current user"""
        try:
            # TODO: Implement dashboard list parsing
            # This will use Playwright MCP to:
            # 1. Navigate to dashboards page
            # 2. Take accessibility snapshot
            # 3. Parse snapshot for dashboard links
            # 4. Filter by creator (current user)
            # 5. Export each dashboard
            
            self.logger.info("Bulk export not yet implemented")
            return {
                "success": False,
                "error": "Bulk export functionality coming soon"
            }
        except Exception as e:
            self.logger.error(f"Bulk export failed: {e}")
            raise
    
    def _get_tool_definitions(self) -> List[Dict]:
        """Return MCP tool definitions"""
        return [
            {
                "name": "export_dashboard",
                "description": "Export an Azure Data Explorer dashboard to JSON",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "url": {
                            "type": "string",
                            "description": "Dashboard URL (https://dataexplorer.azure.com/dashboards/...)"
                        },
                        "outputPath": {
                            "type": "string",
                            "description": "Optional output file path (default: auto-generated)"
                        }
                    },
                    "required": ["url"]
                }
            },
            {
                "name": "import_dashboard",
                "description": "Import a dashboard from JSON to Azure Data Explorer",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "url": {
                            "type": "string",
                            "description": "Target dashboard URL or base URL"
                        },
                        "jsonPath": {
                            "type": "string",
                            "description": "Path to JSON file containing dashboard definition"
                        },
                        "force": {
                            "type": "boolean",
                            "description": "Force overwrite if dashboard exists",
                            "default": False
                        }
                    },
                    "required": ["url", "jsonPath"]
                }
            },
            {
                "name": "validate_dashboard",
                "description": "Validate dashboard JSON file without importing",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "jsonPath": {
                            "type": "string",
                            "description": "Path to JSON file to validate"
                        }
                    },
                    "required": ["jsonPath"]
                }
            },
            {
                "name": "export_all_dashboards",
                "description": "Export all dashboards created by current user (bulk export)",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "listUrl": {
                            "type": "string",
                            "description": "Dashboards list URL",
                            "default": "https://dataexplorer.azure.com/dashboards"
                        }
                    }
                }
            }
        ]
    
    async def handle_request(self, request: Dict) -> Dict:
        """Handle incoming JSON-RPC request"""
        try:
            method = request.get("method")
            params = request.get("params", {})
            req_id = request.get("id")
            
            if method == "initialize":
                return self._create_response(req_id, {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "kusto-dashboard-manager",
                        "version": "1.0.0"
                    }
                })
            
            elif method == "tools/list":
                return self._create_response(req_id, {
                    "tools": self._get_tool_definitions()
                })
            
            elif method == "tools/call":
                tool_name = params.get("name")
                arguments = params.get("arguments", {})
                
                if tool_name == "export_dashboard":
                    result = await self._export_dashboard(
                        arguments["url"],
                        arguments.get("outputPath")
                    )
                elif tool_name == "import_dashboard":
                    result = await self._import_dashboard(
                        arguments["url"],
                        arguments["jsonPath"],
                        arguments.get("force", False)
                    )
                elif tool_name == "validate_dashboard":
                    result = await self._validate_dashboard(
                        arguments["jsonPath"]
                    )
                elif tool_name == "export_all_dashboards":
                    result = await self._export_all_dashboards(
                        arguments.get("listUrl", "https://dataexplorer.azure.com/dashboards")
                    )
                else:
                    return self._create_response(req_id, error=self._create_error(
                        -32601, f"Unknown tool: {tool_name}"
                    ))
                
                return self._create_response(req_id, {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(result, indent=2)
                        }
                    ]
                })
            
            else:
                return self._create_response(req_id, error=self._create_error(
                    -32601, f"Method not found: {method}"
                ))
        
        except Exception as e:
            self.logger.error(f"Request handling error: {e}", exc_info=True)
            return self._create_response(
                request.get("id"),
                error=self._create_error(-32603, str(e))
            )
    
    async def run(self):
        """Run the MCP server (stdio transport)"""
        self.logger.info("Kusto Dashboard Manager MCP Server starting")
        
        try:
            while True:
                # Read JSON-RPC message from stdin
                line = await asyncio.get_event_loop().run_in_executor(
                    None, sys.stdin.readline
                )
                
                if not line:
                    break
                
                try:
                    request = json.loads(line.strip())
                    response = await self.handle_request(request)
                    
                    # Write response to stdout
                    print(json.dumps(response), flush=True)
                
                except json.JSONDecodeError as e:
                    self.logger.error(f"Invalid JSON: {e}")
                    error_response = self._create_response(
                        None,
                        error=self._create_error(-32700, "Parse error")
                    )
                    print(json.dumps(error_response), flush=True)
        
        except KeyboardInterrupt:
            self.logger.info("Server interrupted")
        finally:
            self.logger.info("Server shutting down")

def main():
    """Entry point"""
    server = KustoDashboardMCPServer()
    asyncio.run(server.run())

if __name__ == "__main__":
    main()
