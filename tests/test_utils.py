"""Unit tests for utils module"""
import pytest
import json
from pathlib import Path
from utils import (
    Logger, get_logger, set_logger,
    validate_dashboard_url, validate_json_file, validate_dashboard_json,
    ensure_directory, read_json_file, write_json_file,
    format_error, print_success, print_error, print_info, print_header
)

class TestLogger:
    """Test Logger class"""
    
    def test_logger_creation(self):
        """Test logger initialization"""
        logger = Logger(enabled=True, level="DEBUG")
        assert logger.enabled == True
        assert logger.level == "DEBUG"
    
    def test_logger_disabled(self):
        """Test disabled logger doesn't write"""
        logger = Logger(enabled=False)
        # Should not raise error even when disabled
        logger.info("Test message")
        logger.debug("Debug message")
    
    def test_logger_methods(self):
        """Test logger methods"""
        logger = Logger(enabled=False)
        logger.debug("Debug")
        logger.info("Info")
        logger.warning("Warning")
        logger.error("Error")
    
    def test_global_logger(self):
        """Test global logger functions"""
        logger = Logger(enabled=True)
        set_logger(logger)
        
        global_logger = get_logger()
        assert global_logger.enabled == True

class TestValidation:
    """Test validation functions"""
    
    def test_validate_dashboard_url_valid(self):
        """Test valid dashboard URLs"""
        assert validate_dashboard_url("https://dataexplorer.azure.com/dashboards/abc-123") == True
        assert validate_dashboard_url("https://dataexplorer.azure.com/dashboards/test") == True
    
    def test_validate_dashboard_url_invalid(self):
        """Test invalid dashboard URLs"""
        assert validate_dashboard_url("http://example.com") == False
        assert validate_dashboard_url("https://example.com/dashboards/test") == False
        assert validate_dashboard_url("not a url") == False
    
    def test_validate_json_file_valid(self, temp_dashboard_file):
        """Test valid JSON file"""
        assert validate_json_file(str(temp_dashboard_file)) == True
    
    def test_validate_json_file_nonexistent(self):
        """Test nonexistent file"""
        assert validate_json_file("nonexistent.json") == False
    
    def test_validate_dashboard_json_valid(self, sample_dashboard_json):
        """Test valid dashboard JSON"""
        assert validate_dashboard_json(sample_dashboard_json) == True
    
    def test_validate_dashboard_json_missing_name(self):
        """Test dashboard JSON without name"""
        invalid = {"tiles": [{"id": "1", "type": "query"}]}
        assert validate_dashboard_json(invalid) == False
    
    def test_validate_dashboard_json_missing_tiles(self):
        """Test dashboard JSON without tiles"""
        invalid = {"name": "Test"}
        assert validate_dashboard_json(invalid) == False
    
    def test_validate_dashboard_json_invalid_tiles(self):
        """Test dashboard JSON with invalid tiles"""
        invalid = {"name": "Test", "tiles": [{"id": "1"}]}  # missing type
        assert validate_dashboard_json(invalid) == False

class TestFileOperations:
    """Test file operation functions"""
    
    def test_ensure_directory(self, tmp_path):
        """Test directory creation"""
        test_dir = tmp_path / "test" / "nested" / "dir"
        ensure_directory(str(test_dir))
        assert test_dir.exists()
    
    def test_read_json_file(self, temp_dashboard_file, sample_dashboard_json):
        """Test reading JSON file"""
        data = read_json_file(str(temp_dashboard_file))
        assert data["name"] == sample_dashboard_json["name"]
        assert len(data["tiles"]) == len(sample_dashboard_json["tiles"])
    
    def test_write_json_file(self, tmp_path, sample_dashboard_json):
        """Test writing JSON file"""
        output_file = tmp_path / "output.json"
        write_json_file(str(output_file), sample_dashboard_json)
        
        assert output_file.exists()
        with open(output_file) as f:
            data = json.load(f)
        assert data["name"] == sample_dashboard_json["name"]
    
    def test_write_json_creates_directory(self, tmp_path, sample_dashboard_json):
        """Test write creates parent directories"""
        output_file = tmp_path / "nested" / "path" / "output.json"
        write_json_file(str(output_file), sample_dashboard_json)
        
        assert output_file.exists()
        assert output_file.parent.exists()

class TestHelpers:
    """Test helper functions"""
    
    def test_format_error(self):
        """Test error formatting"""
        try:
            raise ValueError("Test error")
        except Exception as e:
            error_str = format_error(e)
            assert "ValueError" in error_str
            assert "Test error" in error_str
    
    def test_print_functions(self, capsys):
        """Test print helper functions"""
        print_success("Success")
        print_error("Error")
        print_info("Info")
        print_header("Header")
        
        captured = capsys.readouterr()
        assert "Success" in captured.out
        assert "Error" in captured.out
        assert "Info" in captured.out
        assert "Header" in captured.out
