"""Configuration Module"""
import json
import os
from typing import Dict, Any, Optional

class Config:
    DEFAULT_CONFIG = {
        "environment": "production",
        "browser": {"type": "edge", "headless": False, "timeout": 30000},
        "dashboard": {
            "base_url": "https://dataexplorer.azure.com/dashboards",
            "selectors": {"dashboard_canvas": ".dashboard-canvas"}
        },
        "logging": {"enabled": False, "level": "INFO"},
        "exports_directory": "exports"
    }
    
    def __init__(self, config=None):
        self.config = self._merge_configs(self.DEFAULT_CONFIG.copy(), config or {})
    
    def _merge_configs(self, base, override):
        result = base.copy()
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_configs(result[key], value)
            else:
                result[key] = value
        return result
    
    def get(self, key, default=None):
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value
    
    def set(self, key, value):
        keys = key.split('.')
        config = self.config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
    
    def validate(self):
        valid_browsers = ['edge', 'chrome', 'firefox', 'webkit']
        browser_type = self.get('browser.type')
        if browser_type not in valid_browsers:
            raise ValueError(f"Invalid browser type: {browser_type}. Must be one of {valid_browsers}")
        
        timeout = self.get('browser.timeout')
        if timeout < 1000:
            raise ValueError(f"Timeout must be at least 1000ms, got {timeout}")
        
        valid_environments = ['development', 'staging', 'production', 'test']
        environment = self.get('environment')
        if environment and environment not in valid_environments:
            raise ValueError(f"Invalid environment: {environment}. Must be one of {valid_environments}")
        
        return True
    def to_dict(self):
        return self.config.copy()
    
    def to_json(self, indent=2):
        return json.dumps(self.config, indent=indent)
    
    @classmethod
    def from_file(cls, file_path):
        with open(file_path, 'r') as f:
            return cls(json.load(f))
    
    @classmethod
    def from_env(cls):
        config = {}
        if 'KDM_ENVIRONMENT' in os.environ:
            config['environment'] = os.environ['KDM_ENVIRONMENT']
        browser = {}
        if 'KDM_BROWSER' in os.environ:
            browser['type'] = os.environ['KDM_BROWSER']
        if 'KDM_HEADLESS' in os.environ:
            browser['headless'] = os.environ['KDM_HEADLESS'].lower() in ('true', '1', 'yes')
        if 'KDM_TIMEOUT' in os.environ:
            try:
                browser['timeout'] = int(os.environ['KDM_TIMEOUT'])
            except:
                pass
        if browser:
            config['browser'] = browser
        return cls(config)

_global_config = None

def get_config():
    global _global_config
    if _global_config is None:
        _global_config = Config()
    return _global_config

def set_config(config):
    global _global_config
    _global_config = config
