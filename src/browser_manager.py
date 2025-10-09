"""Browser Manager - Wraps MCP client for browser automation"""
import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils import get_logger

class BrowserManager:
    def __init__(self, mcp_client, config):
        self.mcp_client = mcp_client
        self.config = config
        self.logger = get_logger()
        self.browser_launched = False
    
    async def launch(self):
        if self.browser_launched:
            return
        browser_type = self.config.get("browser", {}).get("type", "chromium")
        headless = self.config.get("browser", {}).get("headless", False)
        self.logger.info(f"Launching {browser_type} browser", headless=headless)
        
        result = await self.mcp_client.call_tool("mcp_playwright_browser_launch", {
            "browser": browser_type,
            "headless": headless
        })
        self.browser_launched = True
        self.logger.info("Browser launched")
        return result
    
    async def navigate(self, url):
        self.logger.info(f"Navigating to {url}")
        return await self.mcp_client.call_tool("mcp_playwright_browser_navigate", {"url": url})
    
    async def click(self, selector):
        self.logger.debug(f"Clicking {selector}")
        return await self.mcp_client.call_tool("mcp_playwright_browser_click", {"selector": selector})
    
    async def get_text(self, selector):
        self.logger.debug(f"Getting text from {selector}")
        result = await self.mcp_client.call_tool("mcp_playwright_browser_evaluate", {
            "script": f'document.querySelector("{selector}")?.innerText'
        })
        return result.get("result", "")
    
    async def wait_for_selector(self, selector, timeout=30000):
        return await self.mcp_client.call_tool("mcp_playwright_browser_wait_for", {
            "selector": selector,
            "timeout": timeout
        })
    
    async def execute_script(self, script):
        result = await self.mcp_client.call_tool("mcp_playwright_browser_evaluate", {"script": script})
        return result.get("result")
    
    async def close(self):
        if not self.browser_launched:
            return
        self.logger.info("Closing browser")
        try:
            await self.mcp_client.call_tool("mcp_playwright_browser_close", {})
        except:
            pass
        finally:
            self.browser_launched = False
