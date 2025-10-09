#!/usr/bin/env python3
"""Kusto Dashboard Manager CLI"""
import argparse
import asyncio
import sys
import os
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import Config, get_config, set_config
from utils import get_logger, set_logger, Logger, validate_json_file, print_success, print_error, print_info, print_header
from playwright_mcp_client import PlaywrightMCPClient
from dashboard_export import DashboardExporter
from dashboard_import import DashboardImporter

VERSION = "1.0.0"

async def export_command(args):
    """Export dashboard to JSON"""
    print_header("Export Dashboard")
    
    config = get_config()
    mcp_client = PlaywrightMCPClient()
    
    try:
        await mcp_client.connect()
        exporter = DashboardExporter(mcp_client, config)
        result = await exporter.export_dashboard(args.url, args.output)
        return 0
    except Exception as e:
        print_error(f"Export failed: {e}")
        return 1

async def import_command(args):
    """Import dashboard from JSON"""
    print_header("Import Dashboard")
    
    config = get_config()
    mcp_client = PlaywrightMCPClient()
    
    try:
        await mcp_client.connect()
        importer = DashboardImporter(mcp_client, config)
        await importer.import_dashboard(args.file, verify=not args.no_verify)
        return 0
    except Exception as e:
        print_error(f"Import failed: {e}")
        return 1

def validate_command(args):
    """Validate dashboard JSON file"""
    print_header("Validate Dashboard")
    
    try:
        if validate_json_file(args.file):
            print_success(f"Valid dashboard: {args.file}")
            return 0
        else:
            print_error(f"Invalid dashboard: {args.file}")
            return 1
    except Exception as e:
        print_error(f"Validation failed: {e}")
        return 1

def config_command(args):
    """Show or modify configuration"""
    config = get_config()
    
    if args.get:
        value = config.get(args.get)
        print(f"{args.get} = {value}")
        return 0
    elif args.set:
        key, value = args.set.split("=", 1)
        config.set(key, value)
        print_success(f"Set {key} = {value}")
        return 0
    else:
        print_header("Configuration")
        print(config.to_json(indent=2))
        return 0

def version_command(args):
    """Show version information"""
    print(f"Kusto Dashboard Manager v{VERSION}")
    return 0

def create_parser():
    """Create argument parser"""
    parser = argparse.ArgumentParser(
        description="Kusto Dashboard Manager - Export and import Azure Data Explorer dashboards",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    parser.add_argument("--config-file", "-c", help="Configuration file path")
    
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Export command
    export_parser = subparsers.add_parser("export", help="Export dashboard to JSON")
    export_parser.add_argument("url", help="Dashboard URL")
    export_parser.add_argument("-o", "--output", help="Output file path")
    
    # Import command
    import_parser = subparsers.add_parser("import", help="Import dashboard from JSON")
    import_parser.add_argument("file", help="Dashboard JSON file")
    import_parser.add_argument("--no-verify", action="store_true", help="Skip verification")
    
    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate dashboard JSON")
    validate_parser.add_argument("file", help="Dashboard JSON file")
    
    # Config command
    config_parser = subparsers.add_parser("config", help="Show or modify configuration")
    config_group = config_parser.add_mutually_exclusive_group()
    config_group.add_argument("--get", help="Get configuration value")
    config_group.add_argument("--set", help="Set configuration value (KEY=VALUE)")
    
    # Version command
    version_parser = subparsers.add_parser("version", help="Show version")
    
    return parser

def main():
    """Main entry point"""
    parser = create_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Load configuration
    if args.config_file:
        config = Config.from_file(args.config_file)
    else:
        config = Config.from_env()
    
    set_config(config)
    
    # Setup logging
    if args.verbose:
        logger = Logger(enabled=True, level="DEBUG")
        set_logger(logger)
    
    # Execute command
    commands = {
        "export": export_command,
        "import": import_command,
        "validate": validate_command,
        "config": config_command,
        "version": version_command
    }
    
    handler = commands.get(args.command)
    if not handler:
        print_error(f"Unknown command: {args.command}")
        return 1
    
    # Run async commands with asyncio
    if asyncio.iscoroutinefunction(handler):
        return asyncio.run(handler(args))
    else:
        return handler(args)

if __name__ == "__main__":
    sys.exit(main())
