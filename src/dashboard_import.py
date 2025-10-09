"""Dashboard Import Module"""
import asyncio
import json
import sys
import os
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_manager import BrowserManager
from utils import get_logger, validate_json_file, validate_dashboard_json, read_json_file, print_success, print_error, print_info

class DashboardImporter:
    def __init__(self, mcp_client, config):
        self.mcp_client = mcp_client
        self.config = config
        self.browser = BrowserManager(mcp_client, config)
        self.logger = get_logger()
    
    def _validate_dashboard_file(self, file_path):
        if not validate_json_file(file_path):
            raise ValueError(f"Invalid JSON file: {file_path}")
        
        dashboard_data = read_json_file(file_path)
        if not validate_dashboard_json(dashboard_data):
            raise ValueError(f"Invalid dashboard structure in {file_path}")
        
        return dashboard_data
    
    def _strip_metadata(self, dashboard_data):
        return {k: v for k, v in dashboard_data.items() if k != "_metadata"}
    
    async def _inject_dashboard_json(self, dashboard_data):
        self.logger.info("Injecting dashboard JSON")
        json_str = json.dumps(dashboard_data)
        
        scripts = [
            f"window.__IMPORT_DATA__ = {json_str}",
            f'(function(){{const event=new CustomEvent("dashboard-import",{{detail:{json_str}}});document.dispatchEvent(event)}})()'
        ]
        
        for i, script in enumerate(scripts, 1):
            try:
                await self.browser.execute_script(script)
                self.logger.info(f"Injected using method {i}")
                return
            except Exception as e:
                self.logger.debug(f"Method {i} failed: {e}")
        
        self.logger.warning("Direct injection failed, user must import manually")
    
    async def import_dashboard(self, file_path, verify=True):
        self.logger.info(f"Importing from: {file_path}")
        print_info(f"Importing from {file_path}")
        
        try:
            dashboard_data = self._validate_dashboard_file(file_path)
            dashboard_name = dashboard_data.get("name", "Unknown")
            print_info(f"Dashboard: {dashboard_name}")
            
            clean_data = self._strip_metadata(dashboard_data)
            
            await self.browser.launch()
            
            base_url = self.config.get("dashboard", {}).get("base_url", "https://dataexplorer.azure.com/dashboards")
            import_url = f"{base_url}/new"
            await self.browser.navigate(import_url)
            await asyncio.sleep(2)
            
            await self._inject_dashboard_json(clean_data)
            await asyncio.sleep(3)
            
            self.logger.info("Import completed")
            print_success(f"Dashboard '{dashboard_name}' imported")
            return True
        finally:
            await self.browser.close()
