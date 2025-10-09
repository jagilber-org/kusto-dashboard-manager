"""Integration tests for BrowserManager"""
import pytest
import sys
import os
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from browser_manager import BrowserManager
from config import Config

@pytest.mark.asyncio
class TestBrowserManagerLaunch:
    """Test browser launch functionality"""
    
    async def test_launch_default_browser(self, mock_mcp_client, sample_config):
        """Test launching browser with default config"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.launch()
        
        assert manager.browser_launched == True
        assert len(mock_mcp_client.calls) == 1
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_launch"
        assert call["args"]["browser"] == "chrome"
        assert call["args"]["headless"] == True
    
    async def test_launch_custom_browser(self, mock_mcp_client):
        """Test launching with custom browser type"""
        config = Config({
            "browser": {
                "type": "firefox",
                "headless": False,
                "timeout": 10000
            }
        })
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.launch()
        
        call = mock_mcp_client.calls[0]
        assert call["args"]["browser"] == "firefox"
        assert call["args"]["headless"] == False
    
    async def test_launch_idempotent(self, mock_mcp_client, sample_config):
        """Test that multiple launch calls don't re-launch"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.launch()
        await manager.launch()
        await manager.launch()
        
        # Should only call launch once
        assert len(mock_mcp_client.calls) == 1
        assert manager.browser_launched == True


@pytest.mark.asyncio
class TestBrowserManagerNavigation:
    """Test browser navigation"""
    
    async def test_navigate(self, mock_mcp_client, sample_config):
        """Test navigating to URL"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        await manager.navigate(url)
        
        assert len(mock_mcp_client.calls) == 1
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_navigate"
        assert call["args"]["url"] == url
    
    async def test_navigate_with_response(self, mock_mcp_client, sample_config):
        """Test navigate returns MCP response"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {
            "success": True,
            "url": "https://example.com"
        })
        
        result = await manager.navigate("https://example.com")
        
        assert result["success"] == True
        assert result["url"] == "https://example.com"


@pytest.mark.asyncio
class TestBrowserManagerInteraction:
    """Test browser interaction methods"""
    
    async def test_click(self, mock_mcp_client, sample_config):
        """Test clicking element"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        selector = "button.export-button"
        await manager.click(selector)
        
        assert len(mock_mcp_client.calls) == 1
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_click"
        assert call["args"]["selector"] == selector
    
    async def test_get_text(self, mock_mcp_client, sample_config):
        """Test getting text from element"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": "Dashboard Title"
        })
        
        text = await manager.get_text("h1.title")
        
        assert text == "Dashboard Title"
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_evaluate"
        assert 'document.querySelector' in call["args"]["script"]
    
    async def test_get_text_empty(self, mock_mcp_client, sample_config):
        """Test getting text from non-existent element"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {})
        
        text = await manager.get_text("div.missing")
        
        assert text == ""
    
    async def test_wait_for_selector(self, mock_mcp_client, sample_config):
        """Test waiting for selector"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.wait_for_selector("div.loaded", timeout=15000)
        
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_wait_for"
        assert call["args"]["selector"] == "div.loaded"
        assert call["args"]["timeout"] == 15000
    
    async def test_wait_for_selector_default_timeout(self, mock_mcp_client, sample_config):
        """Test wait_for_selector with default timeout"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.wait_for_selector("div.content")
        
        call = mock_mcp_client.calls[0]
        assert call["args"]["timeout"] == 30000  # Default


@pytest.mark.asyncio
class TestBrowserManagerScriptExecution:
    """Test JavaScript execution"""
    
    async def test_execute_script(self, mock_mcp_client, sample_config):
        """Test executing JavaScript"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        script = "return document.title;"
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": "Page Title"
        })
        
        result = await manager.execute_script(script)
        
        assert result == "Page Title"
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_evaluate"
        assert call["args"]["script"] == script
    
    async def test_execute_script_complex(self, mock_mcp_client, sample_config):
        """Test executing complex JavaScript"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        script = """
        const tiles = document.querySelectorAll('.tile');
        return tiles.length;
        """
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": 5
        })
        
        result = await manager.execute_script(script)
        
        assert result == 5
    
    async def test_execute_script_no_result(self, mock_mcp_client, sample_config):
        """Test execute_script when no result returned"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {})
        
        result = await manager.execute_script("console.log('test');")
        
        assert result is None


@pytest.mark.asyncio
class TestBrowserManagerClose:
    """Test browser close functionality"""
    
    async def test_close(self, mock_mcp_client, sample_config):
        """Test closing browser"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        manager.browser_launched = True
        await manager.close()
        
        assert manager.browser_launched == False
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_close"
    
    async def test_close_not_launched(self, mock_mcp_client, sample_config):
        """Test closing when browser not launched"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        await manager.close()
        
        # Should not call MCP
        assert len(mock_mcp_client.calls) == 0
    
    async def test_close_error_handling(self, mock_mcp_client, sample_config):
        """Test close handles errors gracefully"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        # Make close raise error
        async def error_call(name, args):
            if name == "mcp_playwright_browser_close":
                raise Exception("Browser already closed")
            return {"success": True}
        
        mock_mcp_client.call_tool = error_call
        manager.browser_launched = True
        
        # Should not raise exception
        await manager.close()
        assert manager.browser_launched == False


@pytest.mark.asyncio
class TestBrowserManagerIntegration:
    """Test integrated workflows"""
    
    async def test_full_workflow(self, mock_mcp_client, sample_config):
        """Test complete browser automation workflow"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        # Launch
        await manager.launch()
        assert manager.browser_launched == True
        
        # Navigate
        await manager.navigate("https://example.com")
        
        # Wait for content
        await manager.wait_for_selector("div.content")
        
        # Get text
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": "Content loaded"
        })
        text = await manager.get_text("div.content")
        assert text == "Content loaded"
        
        # Click button
        await manager.click("button.action")
        
        # Execute script
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": True
        })
        result = await manager.execute_script("return true;")
        assert result == True
        
        # Close
        await manager.close()
        assert manager.browser_launched == False
        
        # Verify call sequence
        assert len(mock_mcp_client.calls) == 7
        assert mock_mcp_client.calls[0]["name"] == "mcp_playwright_browser_launch"
        assert mock_mcp_client.calls[1]["name"] == "mcp_playwright_browser_navigate"
        assert mock_mcp_client.calls[2]["name"] == "mcp_playwright_browser_wait_for"
        assert mock_mcp_client.calls[6]["name"] == "mcp_playwright_browser_close"
    
    async def test_state_tracking(self, mock_mcp_client, sample_config):
        """Test browser_launched state tracking"""
        config = Config(sample_config)
        manager = BrowserManager(mock_mcp_client, config)
        
        # Initially not launched
        assert manager.browser_launched == False
        
        # Launch sets flag
        await manager.launch()
        assert manager.browser_launched == True
        
        # Close clears flag
        await manager.close()
        assert manager.browser_launched == False
        
        # Can re-launch
        await manager.launch()
        assert manager.browser_launched == True
