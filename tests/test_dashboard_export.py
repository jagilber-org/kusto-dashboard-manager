"""Integration tests for DashboardExporter"""
import pytest
import sys
import os
import json
from pathlib import Path
from datetime import datetime
from unittest.mock import patch, MagicMock

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from dashboard_export import DashboardExporter
from config import Config

@pytest.mark.asyncio
class TestDashboardIdExtraction:
    """Test dashboard ID extraction from URLs"""
    
    async def test_get_dashboard_id_simple(self, mock_mcp_client, sample_config):
        """Test extracting dashboard ID from simple URL"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/abc123"
        dashboard_id = exporter._get_dashboard_id(url)
        
        assert dashboard_id == "abc123"
    
    async def test_get_dashboard_id_with_query_params(self, mock_mcp_client, sample_config):
        """Test extracting dashboard ID from URL with query parameters"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/xyz789?tab=overview&filter=test"
        dashboard_id = exporter._get_dashboard_id(url)
        
        assert dashboard_id == "xyz789"
    
    async def test_get_dashboard_id_with_path(self, mock_mcp_client, sample_config):
        """Test extracting dashboard ID from URL with additional path"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-dashboard-id"
        dashboard_id = exporter._get_dashboard_id(url)
        
        assert dashboard_id == "test-dashboard-id"


@pytest.mark.asyncio
class TestOutputPathGeneration:
    """Test output path generation"""
    
    async def test_get_output_path_with_custom_path(self, mock_mcp_client, sample_config):
        """Test output path when custom path provided"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        custom_path = "custom/path/dashboard.json"
        result = exporter._get_output_path(custom_path, "Test Dashboard")
        
        assert result == custom_path
    
    async def test_get_output_path_auto_generated(self, mock_mcp_client, sample_config):
        """Test auto-generated output path"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        with patch('dashboard_export.datetime') as mock_datetime:
            mock_now = MagicMock()
            mock_now.strftime.return_value = "20241009-143000"
            mock_datetime.now.return_value = mock_now
            
            result = exporter._get_output_path(None, "Test Dashboard")
            
            assert "Test-Dashboard-20241009-143000.json" in result
            assert "test_exports" in result
    
    async def test_get_output_path_sanitizes_name(self, mock_mcp_client, sample_config):
        """Test that dashboard name is sanitized in output path"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        with patch('dashboard_export.datetime') as mock_datetime:
            mock_now = MagicMock()
            mock_now.strftime.return_value = "20241009-143000"
            mock_datetime.now.return_value = mock_now
            
            result = exporter._get_output_path(None, "Dashboard/With Spaces")
            
            # Spaces and slashes should be replaced with dashes
            assert "Dashboard-With-Spaces-20241009-143000.json" in result
    
    async def test_get_output_path_uses_custom_exports_dir(self, mock_mcp_client):
        """Test using custom exports directory from config"""
        config = Config({
            "exports_directory": "custom_exports",
            "browser": {"type": "chrome", "timeout": 5000}
        })
        exporter = DashboardExporter(mock_mcp_client, config)
        
        result = exporter._get_output_path(None, "Dashboard")
        
        assert "custom_exports" in result


@pytest.mark.asyncio
class TestDashboardJsonExtraction:
    """Test dashboard JSON extraction methods"""
    
    async def test_extract_dashboard_json_method1(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test extraction using window.__DASHBOARD_DATA__"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        # Mock browser execute_script to return dashboard data
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        
        result = await exporter._extract_dashboard_json()
        
        assert result == sample_dashboard_json
        assert "name" in result
        assert "tiles" in result
    
    async def test_extract_dashboard_json_method2(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test extraction using React props"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        # First method returns None, second returns data
        call_count = [0]
        async def mock_call_tool(name, args):
            call_count[0] += 1
            if name == "mcp_playwright_browser_evaluate":
                if call_count[0] == 1:
                    return {"result": None}  # Method 1 fails
                else:
                    return {"result": sample_dashboard_json}  # Method 2 succeeds
            return {"success": True}
        
        mock_mcp_client.call_tool = mock_call_tool
        
        result = await exporter._extract_dashboard_json()
        
        assert result == sample_dashboard_json
        assert call_count[0] >= 2
    
    async def test_extract_dashboard_json_from_string(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test extraction when result is JSON string"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        # Return JSON as string
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": json.dumps(sample_dashboard_json)
        })
        
        result = await exporter._extract_dashboard_json()
        
        assert result == sample_dashboard_json
        assert isinstance(result, dict)
    
    async def test_extract_dashboard_json_all_methods_fail(self, mock_mcp_client, sample_config):
        """Test extraction when all methods fail"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        # All methods return None
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": None
        })
        
        with pytest.raises(Exception, match="Failed to extract dashboard JSON"):
            await exporter._extract_dashboard_json()
    
    async def test_extract_dashboard_json_invalid_data(self, mock_mcp_client, sample_config):
        """Test extraction with invalid data (no name or tiles)"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        # Return data without name or tiles
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": {"invalid": "data"}
        })
        
        with pytest.raises(Exception, match="Failed to extract dashboard JSON"):
            await exporter._extract_dashboard_json()


@pytest.mark.asyncio
class TestMetadataEnrichment:
    """Test dashboard metadata enrichment"""
    
    async def test_enrich_dashboard_data(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test enriching dashboard data with metadata"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        
        with patch('dashboard_export.datetime') as mock_datetime:
            mock_utcnow = MagicMock()
            mock_utcnow.isoformat.return_value = "2024-10-09T14:30:22.123000"
            mock_datetime.utcnow.return_value = mock_utcnow
            
            result = exporter._enrich_dashboard_data(sample_dashboard_json, url)
            
            assert "_metadata" in result
            assert result["_metadata"]["exportedAt"] == "2024-10-09T14:30:22.123000"
            assert result["_metadata"]["sourceUrl"] == url
            assert result["_metadata"]["dashboardId"] == "test-123"
            assert result["_metadata"]["exporterVersion"] == "1.0.0"
    
    async def test_enrich_dashboard_data_preserves_original(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test that enrichment preserves original dashboard data"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        result = exporter._enrich_dashboard_data(sample_dashboard_json, url)
        
        # Original data should be preserved
        assert result["name"] == sample_dashboard_json["name"]
        assert result["version"] == sample_dashboard_json["version"]
        assert result["tiles"] == sample_dashboard_json["tiles"]
    
    async def test_enrich_dashboard_data_metadata_first(self, mock_mcp_client, sample_config, sample_dashboard_json):
        """Test that metadata is added as first key"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        result = exporter._enrich_dashboard_data(sample_dashboard_json, url)
        
        # Metadata should be first key
        keys = list(result.keys())
        assert keys[0] == "_metadata"


@pytest.mark.asyncio
class TestExportDashboard:
    """Test complete export workflow"""
    
    async def test_export_dashboard_success(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test successful dashboard export"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        output_path = str(tmp_path / "test_dashboard.json")
        
        # Mock browser responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        result_path = await exporter.export_dashboard(url, output_path)
        
        assert result_path == output_path
        assert Path(output_path).exists()
        
        # Verify file content
        with open(output_path, 'r') as f:
            data = json.load(f)
        
        assert "_metadata" in data
        assert data["name"] == sample_dashboard_json["name"]
        assert data["tiles"] == sample_dashboard_json["tiles"]
    
    async def test_export_dashboard_invalid_url(self, mock_mcp_client, sample_config):
        """Test export with invalid URL"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        invalid_url = "https://invalid.com/not-a-dashboard"
        
        with pytest.raises(ValueError, match="Invalid dashboard URL"):
            await exporter.export_dashboard(invalid_url)
    
    async def test_export_dashboard_auto_output_path(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test export with auto-generated output path"""
        # Override exports directory to use tmp_path
        sample_config["exports_directory"] = str(tmp_path)
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        result_path = await exporter.export_dashboard(url)
        
        assert result_path is not None
        assert Path(result_path).exists()
        assert "Test-Dashboard" in result_path
        assert result_path.endswith(".json")
    
    async def test_export_dashboard_browser_closes_on_error(self, mock_mcp_client, sample_config):
        """Test that browser closes even when export fails"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        
        # Mock responses - extraction fails
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": None  # Causes extraction to fail
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        with pytest.raises(Exception, match="Failed to extract dashboard JSON"):
            await exporter.export_dashboard(url)
        
        # Verify browser close was called
        close_calls = [c for c in mock_mcp_client.calls if c["name"] == "mcp_playwright_browser_close"]
        assert len(close_calls) == 1
    
    async def test_export_dashboard_call_sequence(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test the correct sequence of MCP calls during export"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        output_path = str(tmp_path / "test.json")
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await exporter.export_dashboard(url, output_path)
        
        # Verify call sequence
        call_names = [c["name"] for c in mock_mcp_client.calls]
        assert call_names[0] == "mcp_playwright_browser_launch"
        assert call_names[1] == "mcp_playwright_browser_navigate"
        assert "mcp_playwright_browser_evaluate" in call_names
        assert call_names[-1] == "mcp_playwright_browser_close"


@pytest.mark.asyncio
class TestExporterIntegration:
    """Test integrated exporter workflows"""
    
    async def test_multiple_exports(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test exporting multiple dashboards"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        urls = [
            "https://dataexplorer.azure.com/dashboards/test-1",
            "https://dataexplorer.azure.com/dashboards/test-2"
        ]
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        results = []
        for i, url in enumerate(urls):
            output_path = str(tmp_path / f"dashboard_{i}.json")
            result = await exporter.export_dashboard(url, output_path)
            results.append(result)
        
        # All exports should succeed
        assert len(results) == 2
        for result in results:
            assert Path(result).exists()
    
    async def test_exporter_uses_browser_manager(self, mock_mcp_client, sample_config, sample_dashboard_json, tmp_path):
        """Test that exporter correctly uses BrowserManager"""
        config = Config(sample_config)
        exporter = DashboardExporter(mock_mcp_client, config)
        
        url = "https://dataexplorer.azure.com/dashboards/test-123"
        output_path = str(tmp_path / "test.json")
        
        # Track browser manager state
        assert exporter.browser is not None
        assert exporter.browser.browser_launched == False
        
        # Mock responses
        mock_mcp_client.set_response("mcp_playwright_browser_launch", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
        mock_mcp_client.set_response("mcp_playwright_browser_evaluate", {
            "result": sample_dashboard_json
        })
        mock_mcp_client.set_response("mcp_playwright_browser_close", {"success": True})
        
        await exporter.export_dashboard(url, output_path)
        
        # Browser should be closed after export
        assert exporter.browser.browser_launched == False
