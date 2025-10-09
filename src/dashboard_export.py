"""Dashboard Export Module"""
import asyncio
import json
import sys
import os
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_manager import BrowserManager
from utils import get_logger, validate_dashboard_url, write_json_file, ensure_directory, print_success, print_error, print_info

class DashboardExporter:
    def __init__(self, mcp_client, config):
        self.mcp_client = mcp_client
        self.config = config
        self.browser = BrowserManager(mcp_client, config)
        self.logger = get_logger()
    
    def _get_dashboard_id(self, url):
        return url.split("/")[-1].split("?")[0]
    
    def _get_output_path(self, output_path, dashboard_name):
        if output_path:
            return output_path
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        safe_name = dashboard_name.replace(" ", "-").replace("/", "-")
        filename = f"{safe_name}-{timestamp}.json"
        exports_dir = self.config.get("exports_directory", "exports")
        ensure_directory(exports_dir)
        return str(Path(exports_dir) / filename)
    
    async def _extract_dashboard_json(self):
        self.logger.info("Extracting dashboard JSON")
        scripts = [
            "window.__DASHBOARD_DATA__",
            '(function(){const el=document.querySelector("[data-dashboard-id]");return el?.__reactProps$?.dashboard})()',
            "document.querySelector('script[type=\"application/json\"]')?.textContent"
        ]
        
        for i, script in enumerate(scripts, 1):
            try:
                result = await self.browser.execute_script(script)
                if result and isinstance(result, (dict, str)):
                    if isinstance(result, str):
                        result = json.loads(result)
                    if "name" in result or "tiles" in result:
                        self.logger.info(f"Extracted using method {i}")
                        return result
            except Exception as e:
                self.logger.debug(f"Method {i} failed: {e}")
        
        raise Exception("Failed to extract dashboard JSON")
    
    def _enrich_dashboard_data(self, dashboard_data, url):
        return {
            "_metadata": {
                "exportedAt": datetime.utcnow().isoformat(),
                "sourceUrl": url,
                "dashboardId": self._get_dashboard_id(url),
                "exporterVersion": "1.0.0"
            },
            **dashboard_data
        }
    
    async def export_dashboard(self, url, output_path=None):
        if not validate_dashboard_url(url):
            raise ValueError(f"Invalid dashboard URL: {url}")
        
        self.logger.info(f"Exporting dashboard: {url}")
        print_info(f"Exporting from {url}")
        
        try:
            await self.browser.launch()
            await self.browser.navigate(url)
            await asyncio.sleep(3)  # Wait for page load
            
            dashboard_data = await self._extract_dashboard_json()
            enriched_data = self._enrich_dashboard_data(dashboard_data, url)
            
            dashboard_name = enriched_data.get("name", "dashboard")
            final_path = self._get_output_path(output_path, dashboard_name)
            
            write_json_file(final_path, enriched_data, indent=2)
            
            self.logger.info(f"Exported to {final_path}")
            print_success(f"Exported to: {final_path}")
            return final_path
        finally:
            await self.browser.close()
