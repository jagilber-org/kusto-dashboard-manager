"""Kusto Dashboard Manager Package"""
from .config import Config, get_config, set_config
from .utils import get_logger, set_logger, Logger
from .playwright_mcp_client import WorkingPyMCPClient as PlaywrightMCPClient
from .browser_manager import BrowserManager
from .dashboard_export import DashboardExporter
from .dashboard_import import DashboardImporter

__version__ = "1.0.0"
__all__ = [
    "Config",
    "get_config",
    "set_config",
    "Logger",
    "get_logger",
    "set_logger",
    "PlaywrightMCPClient",
    "BrowserManager",
    "DashboardExporter",
    "DashboardImporter"
]
