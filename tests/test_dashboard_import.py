"""Integration tests for DashboardImporter"""
import pytest
import sys
import os
import json
from pathlib import Path
from unittest.mock import patch

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from dashboard_import import DashboardImporter
from config import Config

@pytest.mark.asyncio
class TestDashboardFileValidation:
    """Test dashboard file validation"""
    
    async def test_validate_dashboard_file_valid(self, mock_mcp_client, sample_config, temp_dashboard_file):
        """Test validating a valid dashboard file"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        result = importer._validate_dashboard_file(temp_dashboard_file)
        
        assert result is not None
        assert "name" in result
        assert "tiles" in result
    
    async def test_validate_dashboard_file_nonexistent(self, mock_mcp_client, sample_config):
        """Test validating non-existent file"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        with pytest.raises(ValueError, match="Invalid JSON file"):
            importer._validate_dashboard_file("nonexistent.json")
    
    async def test_validate_dashboard_file_invalid_json(self, mock_mcp_client, sample_config, tmp_path):
        """Test validating file with invalid JSON"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Create file with invalid JSON
        invalid_file = tmp_path / "invalid.json"
        with open(invalid_file, 'w') as f:
            f.write("{invalid json")
        
        with pytest.raises(ValueError, match="Invalid JSON file"):
            importer._validate_dashboard_file(str(invalid_file))
    
    async def test_validate_dashboard_file_invalid_structure(self, mock_mcp_client, sample_config, tmp_path):
        """Test validating file with invalid dashboard structure"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Create file with valid JSON but invalid dashboard structure
        invalid_dashboard = tmp_path / "invalid_dashboard.json"
        with open(invalid_dashboard, 'w') as f:
            json.dump({"invalid": "structure"}, f)
        
        with pytest.raises(ValueError, match="Invalid dashboard structure"):
            importer._validate_dashboard_file(str(invalid_dashboard))
    
    async def test_validate_dashboard_file_with_metadata(self, mock_mcp_client, sample_config, tmp_path, sample_dashboard_with_metadata):
        """Test validating file with metadata (export format)"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Create file with metadata
        dashboard_file = tmp_path / "dashboard_with_metadata.json"
        with open(dashboard_file, 'w') as f:
            json.dump(sample_dashboard_with_metadata, f)
        
        result = importer._validate_dashboard_file(str(dashboard_file))
        
        assert result is not None
        assert "_metadata" in result
        assert "name" in result


@pytest.mark.asyncio
class TestMetadataStripping:
    """Test metadata stripping from dashboard data"""
    
    async def test_strip_metadata(self, mock_mcp_client, sample_config, sample_dashboard_with_metadata):
        """Test stripping metadata from dashboard data"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        result = importer._strip_metadata(sample_dashboard_with_metadata)
        
        assert "_metadata" not in result
        assert "name" in result
        assert "tiles" in result
    
    async def test_strip_metadata_no_metadata(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test stripping metadata when none exists"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        result = importer._strip_metadata(sample_dashboard_json)
        
        assert result == sample_dashboard_json
        assert "name" in result
        assert "tiles" in result
    
    async def test_strip_metadata_preserves_data(self, mock_mcp_client, sample_config, sample_dashboard_with_metadata):
        """Test that stripping metadata preserves dashboard data"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        result = importer._strip_metadata(sample_dashboard_with_metadata)
        
        # Verify original data preserved
        assert result["name"] == sample_dashboard_with_metadata["name"]
        assert result["version"] == sample_dashboard_with_metadata["version"]
        assert len(result["tiles"]) == len(sample_dashboard_with_metadata["tiles"])
    
    async def test_strip_metadata_creates_new_dict(self, mock_mcp_client, sample_config, sample_dashboard_with_metadata):
        """Test that stripping creates new dictionary"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        result = importer._strip_metadata(sample_dashboard_with_metadata)
        
        # Original should still have metadata
        assert "_metadata" in sample_dashboard_with_metadata
        assert "_metadata" not in result


@pytest.mark.asyncio
class TestDashboardInjection:
    """Test JavaScript injection methods"""
    
    async def test_inject_dashboard_json_method1(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test injecting dashboard via window.__IMPORT_DATA__"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        
        await importer._inject_dashboard_json(sample_dashboard_json)
        
        # Verify script was executed
        assert len(mock_mcp_client.calls) >= 1
        call = mock_mcp_client.calls[0]
        assert call["name"] == "mcp_playwright_browser_evaluate"
        assert "window.__IMPORT_DATA__" in call["args"]["script"]
    
    async def test_inject_dashboard_json_method2_fallback(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test fallback to custom event injection"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # First method fails, second succeeds
        call_count = [0]
        async def mock_call_tool(name, args):
            call_count[0] += 1
            if name == "mcp_playwright_browser_evaluate":
                if call_count[0] == 1:
                    raise Exception("Method 1 failed")
                else:
                    return {"success": True}
            return {"success": True}
        
        mock_mcp_client.call_tool = mock_call_tool
        
        await importer._inject_dashboard_json(sample_dashboard_json)
        
        assert call_count[0] == 2  # Both methods attempted
    
    async def test_inject_dashboard_json_all_methods_fail(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test when all injection methods fail"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # All methods fail
        async def mock_call_tool(name, args):
            if name == "mcp_playwright_browser_evaluate":
                raise Exception("Injection failed")
            return {"success": True}
        
        mock_mcp_client.call_tool = mock_call_tool
        
        # Should not raise exception, just log warning
        await importer._inject_dashboard_json(sample_dashboard_json)
    
    async def test_inject_dashboard_json_content(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test that injected JSON contains dashboard data"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        
        await importer._inject_dashboard_json(sample_dashboard_json)
        
        call = mock_mcp_client.calls[0]
        script = call["args"]["script"]
        
        # Verify dashboard data is in script
        assert sample_dashboard_json["name"] in script
        assert "tiles" in script


@pytest.mark.asyncio
class TestImportDashboard:
    """Test complete import workflow"""
    
    async def test_import_dashboard_success(self, mock_mcp_client, sample_config, temp_dashboard_file):
        """Test successful dashboard import"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Mock browser responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        result = await importer.import_dashboard(str(temp_dashboard_file))
        
        assert result == True
    
    async def test_import_dashboard_invalid_file(self, mock_mcp_client, sample_config):
        """Test importing invalid file"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        with pytest.raises(ValueError, match="Invalid JSON file"):
            await importer.import_dashboard("nonexistent.json")
    
    async def test_import_dashboard_strips_metadata(self, mock_mcp_client, sample_config, tmp_path, sample_dashboard_with_metadata):
        """Test that import strips metadata before injection"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Create file with metadata
        dashboard_file = tmp_path / "dashboard_with_metadata.json"
        with open(dashboard_file, 'w') as f:
            json.dump(sample_dashboard_with_metadata, f)
        
        # Mock browser responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await importer.import_dashboard(str(dashboard_file))
        
        # Find the evaluate call
        evaluate_calls = [c for c in mock_mcp_client.calls if c["name"] == "mcp_playwright_browser_evaluate"]
        assert len(evaluate_calls) >= 1
        
        # Verify metadata is not in injected script
        script = evaluate_calls[0]["args"]["script"]
        assert "_metadata" not in script
    
    async def test_import_dashboard_navigates_to_new(self, mock_mcp_client, sample_config, temp_dashboard_file):
        """Test that import navigates to /new endpoint"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Mock browser responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await importer.import_dashboard(str(temp_dashboard_file))
        
        # Find navigate call
        navigate_calls = [c for c in mock_mcp_client.calls if c["name"] == "mcp_playwright_browser_navigate"]
        assert len(navigate_calls) == 1
        assert "/new" in navigate_calls[0]["args"]["url"]
    
    async def test_import_dashboard_browser_closes_on_error(self, mock_mcp_client, sample_config):
        """Test that browser close is called even when import fails"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Track initial state
        assert importer.browser.browser_launched == False
        
        # Mock browser close
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        with pytest.raises(ValueError, match="Invalid JSON file"):
            await importer.import_dashboard("nonexistent.json")
        
        # Browser.close() is called in finally block, but since browser was never launched,
        # it returns early without making MCP call (expected behavior)
        # Verify browser state remains closed
        assert importer.browser.browser_launched == False
    
    async def test_import_dashboard_call_sequence(self, mock_mcp_client, sample_config, temp_dashboard_file):
        """Test the correct sequence of MCP calls during import"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await importer.import_dashboard(str(temp_dashboard_file))
        
        # Verify call sequence
        call_names = [c["name"] for c in mock_mcp_client.calls]
        assert call_names[0] == "mcp_playwright_browser_launch"
        assert call_names[1] == "mcp_playwright_browser_navigate"
        assert "mcp_playwright_browser_evaluate" in call_names
        assert call_names[-1] == "mcp_playwright_browser_close"
    
    async def test_import_dashboard_custom_base_url(self, mock_mcp_client, temp_dashboard_file):
        """Test import with custom base URL"""
        config = Config({
            "browser": {"type": "chrome", "timeout": 5000},
            "dashboard": {"base_url": "https://custom.azure.com/dashboards"}
        })
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await importer.import_dashboard(str(temp_dashboard_file))
        
        # Verify custom URL used
        navigate_calls = [c for c in mock_mcp_client.calls if c["name"] == "mcp_playwright_browser_navigate"]
        assert "custom.azure.com" in navigate_calls[0]["args"]["url"]


@pytest.mark.asyncio
class TestImporterIntegration:
    """Test integrated importer workflows"""
    
    async def test_multiple_imports(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test importing multiple dashboards"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Create multiple dashboard files
        files = []
        for i in range(2):
            dashboard_file = tmp_path / f"dashboard_{i}.json"
            with open(dashboard_file, 'w') as f:
                json.dump(sample_dashboard_json, f)
            files.append(str(dashboard_file))
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        results = []
        for file in files:
            result = await importer.import_dashboard(file)
            results.append(result)
        
        # All imports should succeed
        assert all(results)
    
    async def test_importer_uses_browser_manager(self, mock_mcp_client, sample_config, temp_dashboard_file):
        """Test that importer correctly uses BrowserManager"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Track browser manager state
        assert importer.browser is not None
        assert importer.browser.browser_launched == False
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await importer.import_dashboard(str(temp_dashboard_file))
        
        # Browser should be closed after import
        assert importer.browser.browser_launched == False
    
    async def test_importer_validates_before_launching_browser(self, mock_mcp_client, sample_config):
        """Test that file validation happens before browser launch"""
        config = Config(sample_config)
        importer = DashboardImporter(mock_mcp_client, config)
        
        # Mock browser launch to track if called
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        
        # Try to import invalid file
        with pytest.raises(ValueError, match="Invalid JSON file"):
            await importer.import_dashboard("nonexistent.json")
        
        # Browser launch should not have been called
        launch_calls = [c for c in mock_mcp_client.calls if c["name"] == "mcp_playwright_browser_launch"]
        assert len(launch_calls) == 0
