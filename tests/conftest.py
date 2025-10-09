"""Pytest configuration and fixtures"""
import pytest
import sys
import os
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

@pytest.fixture
def sample_config():
    """Sample configuration for testing"""
    return {
        "environment": "test",
        "browser": {
            "type": "chrome",
            "headless": True,
            "timeout": 5000
        },
        "dashboard": {
            "base_url": "https://dataexplorer.azure.com/dashboards",
            "timeout": 5000
        },
        "logging": {
            "enabled": False,
            "level": "DEBUG",
            "file": None
        },
        "exports_directory": "test_exports"
    }

@pytest.fixture
def sample_dashboard_json():
    """Sample dashboard JSON for testing"""
    return {
        "name": "Test Dashboard",
        "version": "1.0",
        "tiles": [
            {
                "id": "tile-1",
                "type": "query",
                "query": "StormEvents | take 10",
                "title": "Storm Events"
            },
            {
                "id": "tile-2",
                "type": "markdown",
                "content": "# Test Markdown"
            }
        ]
    }

@pytest.fixture
def sample_dashboard_with_metadata():
    """Sample dashboard with metadata for export testing"""
    return {
        "_metadata": {
            "exportedAt": "2024-10-09T14:30:22.123Z",
            "sourceUrl": "https://dataexplorer.azure.com/dashboards/test-123",
            "dashboardId": "test-123",
            "exporterVersion": "1.0.0"
        },
        "name": "Test Dashboard",
        "version": "1.0",
        "tiles": [
            {
                "id": "tile-1",
                "type": "query",
                "query": "StormEvents | take 10"
            }
        ]
    }

class MockMCPClient:
    """Mock MCP client for testing"""
    
    def __init__(self):
        self.connected = False
        self.calls = []
        self.responses = {}
    
    async def connect(self):
        """Mock connect"""
        self.connected = True
    
    async def call_tool(self, name, args):
        """Mock tool call"""
        self.calls.append({"name": name, "args": args})
        return self.responses.get(name, {"success": True})
    
    async def close(self):
        """Mock close"""
        self.connected = False
    
    def set_response(self, tool_name, response):
        """Set mock response for a tool"""
        self.responses[tool_name] = response

@pytest.fixture
def mock_mcp_client():
    """Mock MCP client fixture"""
    return MockMCPClient()

@pytest.fixture
def temp_config_file(tmp_path, sample_config):
    """Create temporary config file"""
    import json
    config_file = tmp_path / "test_config.json"
    with open(config_file, 'w') as f:
        json.dump(sample_config, f)
    return config_file

@pytest.fixture
def temp_dashboard_file(tmp_path, sample_dashboard_json):
    """Create temporary dashboard JSON file"""
    import json
    dashboard_file = tmp_path / "test_dashboard.json"
    with open(dashboard_file, 'w') as f:
        json.dump(sample_dashboard_json, f)
    return dashboard_file
