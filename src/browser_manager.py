"""Browser Manager - Wraps MCP client for browser automation"""
import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils import get_logger
from tracer import trace_mcp_call, trace_info, trace_error

# Try to import VS Code MCP functions if available
try:
    # When running as MCP server called by VS Code, these should be available
    from vscode import mcp_playwright_browser_launch, mcp_playwright_browser_navigate, \
                       mcp_playwright_browser_snapshot, mcp_playwright_browser_close, \
                       mcp_playwright_browser_evaluate
    VSCODE_MCP_AVAILABLE = True
    print("[MCP] VS Code Playwright MCP functions loaded", file=sys.stderr)
except ImportError:
    VSCODE_MCP_AVAILABLE = False
    print("[MCP] VS Code Playwright MCP functions not available, will use subprocess", file=sys.stderr)

class BrowserManager:
    def __init__(self, mcp_client, config):
        self.mcp_client = mcp_client
        self.config = config
        self.logger = get_logger()
        self.browser_launched = False
        self.current_url = None
        self.use_vscode_mcp = VSCODE_MCP_AVAILABLE
        print(f"[MCP] BrowserManager initialized, use_vscode_mcp={self.use_vscode_mcp}", file=sys.stderr)
    
    async def launch(self):
        if self.browser_launched:
            trace_info("Browser already launched, skipping")
            return
        
        browser_type = self.config.get("browser", {}).get("type", "chromium")
        headless = self.config.get("browser", {}).get("headless", False)
        trace_info("Launching browser", browser=browser_type, headless=headless)
        self.logger.info(f"Launching {browser_type} browser", headless=headless)
        
        params = {"browser": browser_type, "headless": headless}
        try:
            if self.use_vscode_mcp:
                # VS Code Playwright is already launched, just mark as ready
                print(f"[DEBUG] Using VS Code's Playwright browser (already launched)", file=sys.stderr)
                self.browser_launched = True
                trace_mcp_call("browser_launch", params, "skipped - using VS Code browser")
                return True
            else:
                result = await self.mcp_client.call_tool("browser_launch", params)
                self.browser_launched = True
                self.logger.info("Browser launched")
                trace_mcp_call("browser_launch", params, "success")
                return result
        except Exception as e:
            print(f"[DEBUG] launch failed: {e}", file=sys.stderr)
            trace_mcp_call("browser_launch", params, error=str(e))
            raise
    
    async def navigate(self, url):
        trace_info("Navigate", url=url)
        self.logger.info(f"Navigating to {url}")
        self.current_url = url
        params = {"url": url}
        
        try:
            if self.use_vscode_mcp:
                print(f"[DEBUG] Calling mcp_playwright_browser_navigate({url}) directly", file=sys.stderr)
                result = await mcp_playwright_browser_navigate(url=url)
                trace_mcp_call("browser_navigate", params, "success via VS Code MCP")
                return result
            else:
                result = await self.mcp_client.call_tool("browser_navigate", params)
                trace_mcp_call("browser_navigate", params, "success")
                return result
        except Exception as e:
            print(f"[DEBUG] navigate failed: {e}", file=sys.stderr)
            trace_mcp_call("browser_navigate", params, error=str(e))
            raise
    
    async def click(self, selector):
        self.logger.debug(f"Clicking {selector}")
        return await self.mcp_client.call_tool("browser_click", {"selector": selector})
    
    async def get_text(self, selector):
        self.logger.debug(f"Getting text from {selector}")
        result = await self.mcp_client.call_tool("browser_evaluate", {
            "function": f'() => document.querySelector("{selector}")?.innerText'
        })
        return result if result else ""
    
    async def wait_for_selector(self, selector, timeout=30000):
        return await self.mcp_client.call_tool("browser_wait_for", {
            "selector": selector,
            "timeout": timeout
        })
    
    async def execute_script(self, script):
        # Call Playwright MCP's browser_evaluate tool
        trace_info("Execute script", script_length=len(script))
        params = {"function": script}
        try:
            result = await self.mcp_client.call_tool("browser_evaluate", params)
            trace_mcp_call("browser_evaluate", params, str(result)[:200])
            # The PlaywrightMCPClient.call_tool() already parses the response
            return result
        except Exception as e:
            trace_mcp_call("browser_evaluate", params, error=str(e))
            raise
    
    async def snapshot(self):
        """Take accessibility snapshot of the current page"""
        trace_info("Taking accessibility snapshot")
        self.logger.debug("Taking accessibility snapshot")
        print(f"[DEBUG] browser_manager.snapshot() called, use_vscode_mcp={self.use_vscode_mcp}", file=sys.stderr)
        
        try:
            if self.use_vscode_mcp:
                # Call VS Code's Playwright MCP function directly
                print(f"[DEBUG] Calling mcp_playwright_browser_snapshot() directly", file=sys.stderr)
                result = await mcp_playwright_browser_snapshot()
                print(f"[DEBUG] mcp_playwright_browser_snapshot returned: type={type(result)}", file=sys.stderr)
                # Extract the raw YAML from the result
                if isinstance(result, dict) and 'raw' in result:
                    trace_mcp_call("browser_snapshot", {}, f"success via VS Code MCP")
                    return result
                else:
                    print(f"[DEBUG] Unexpected result format: {result}", file=sys.stderr)
                    return result
            else:
                # Fall back to subprocess client
                print(f"[DEBUG] Calling mcp_client.call_tool('browser_snapshot', {{}})", file=sys.stderr)
                result = await self.mcp_client.call_tool("browser_snapshot", {})
                print(f"[DEBUG] browser_snapshot returned: type={type(result)}, value={result is not None}", file=sys.stderr)
                result_size = len(str(result)) if result else 0
                trace_mcp_call("browser_snapshot", {}, f"success, size: {result_size}")
                return result
        except Exception as e:
            print(f"[DEBUG] browser_snapshot failed: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)
            trace_mcp_call("browser_snapshot", {}, error=str(e))
            raise
    
    async def close(self):
        if not self.browser_launched:
            trace_info("Browser not launched, skipping close")
            return
        trace_info("Closing browser")
        self.logger.info("Closing browser")
        try:
            await self.mcp_client.call_tool("browser_close", {})
            trace_mcp_call("browser_close", {}, "success")
        except Exception as e:
            trace_mcp_call("browser_close", {}, error=str(e))
        finally:
            self.browser_launched = False
