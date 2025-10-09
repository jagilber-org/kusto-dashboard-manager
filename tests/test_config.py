"""Unit tests for config module"""
import pytest
import os
import json
from config import Config, get_config, set_config

class TestConfig:
    """Test Config class"""
    
    def test_default_config(self):
        """Test default configuration values"""
        config = Config()
        assert config.get("environment") == "production"
        assert config.get("browser.type") == "edge"
        assert config.get("browser.headless") == False
        assert config.get("browser.timeout") == 30000
    
    def test_custom_config(self, sample_config):
        """Test custom configuration"""
        config = Config(sample_config)
        assert config.get("environment") == "test"
        assert config.get("browser.type") == "chrome"
        assert config.get("browser.headless") == True
    
    def test_get_with_dot_notation(self, sample_config):
        """Test get with dot notation"""
        config = Config(sample_config)
        assert config.get("browser.type") == "chrome"
        assert config.get("dashboard.base_url") == "https://dataexplorer.azure.com/dashboards"
        assert config.get("logging.enabled") == False
    
    def test_get_nonexistent_key(self):
        """Test get with nonexistent key returns default"""
        config = Config()
        assert config.get("nonexistent.key") is None
        assert config.get("nonexistent.key", "default") == "default"
    
    def test_set_with_dot_notation(self):
        """Test set with dot notation"""
        config = Config()
        config.set("browser.type", "firefox")
        assert config.get("browser.type") == "firefox"
        
        config.set("new.nested.key", "value")
        assert config.get("new.nested.key") == "value"
    
    def test_validate_valid_config(self, sample_config):
        """Test validation with valid config"""
        config = Config(sample_config)
        assert config.validate() == True
    
    def test_validate_invalid_browser(self):
        """Test validation with invalid browser type"""
        config = Config()
        config.set("browser.type", "invalid")
        with pytest.raises(ValueError, match="Invalid browser type"):
            config.validate()
    
    def test_validate_invalid_timeout(self):
        """Test validation with invalid timeout"""
        config = Config()
        config.set("browser.type", "edge")  # Set valid browser first
        config.set("browser.timeout", 500)
        with pytest.raises(ValueError, match="must be at least 1000"):
            config.validate()
    
    def test_validate_invalid_environment(self):
        """Test validation with invalid environment"""
        config = Config()
        config.set("browser.type", "edge")  # Set valid browser first
        config.set("browser.timeout", 5000)  # Set valid timeout
        config.set("environment", "invalid")
        with pytest.raises(ValueError, match="Invalid environment"):
            config.validate()
    
    def test_to_dict(self, sample_config):
        """Test to_dict conversion"""
        config = Config(sample_config)
        config_dict = config.to_dict()
        assert isinstance(config_dict, dict)
        assert config_dict["environment"] == "test"
        assert config_dict["browser"]["type"] == "chrome"
    
    def test_to_json(self, sample_config):
        """Test to_json conversion"""
        config = Config(sample_config)
        config_json = config.to_json()
        assert isinstance(config_json, str)
        parsed = json.loads(config_json)
        assert parsed["environment"] == "test"
    
    def test_from_file(self, temp_config_file):
        """Test loading from file"""
        config = Config.from_file(str(temp_config_file))
        assert config.get("environment") == "test"
        assert config.get("browser.type") == "chrome"
    
    def test_from_env(self, monkeypatch):
        """Test loading from environment variables"""
        monkeypatch.setenv("KDM_ENVIRONMENT", "staging")
        monkeypatch.setenv("KDM_BROWSER", "firefox")
        monkeypatch.setenv("KDM_HEADLESS", "true")
        monkeypatch.setenv("KDM_TIMEOUT", "15000")
        
        config = Config.from_env()
        assert config.get("environment") == "staging"
        assert config.get("browser.type") == "firefox"
        assert config.get("browser.headless") == True
        assert config.get("browser.timeout") == 15000

class TestGlobalConfig:
    """Test global config functions"""
    
    def test_get_set_config(self):
        """Test global config getter/setter"""
        config = Config()
        config.set("test.key", "test_value")
        set_config(config)
        
        global_config = get_config()
        assert global_config.get("test.key") == "test_value"
