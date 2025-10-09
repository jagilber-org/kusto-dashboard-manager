"""
Tests for kusto_dashboard_manager.py CLI
"""
import pytest
import sys
import asyncio
from unittest.mock import Mock, patch, MagicMock, AsyncMock
from io import StringIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))
from kusto_dashboard_manager import (
    export_command,
    import_command, 
    validate_command,
    config_command,
    version_command,
    create_parser,
    main,
    VERSION
)
from config import Config
from utils import Logger

class TestArgumentParsing:
    """Test argparse configuration and argument parsing"""
    
    def test_create_parser_basic(self):
        """Test parser creation"""
        parser = create_parser()
        assert parser is not None
        # Parser prog can be kusto_dashboard_manager.py, __main__.py, or contain pytest
        assert any(x in parser.prog for x in ["kusto_dashboard_manager.py", "__main__.py", "pytest"])
    
    def test_parser_no_args_shows_help(self):
        """Test that no arguments shows help"""
        parser = create_parser()
        args = parser.parse_args([])
        assert args.command is None
    
    def test_parser_export_args(self):
        """Test export command arguments"""
        parser = create_parser()
        args = parser.parse_args(["export", "https://example.com/dashboard"])
        assert args.command == "export"
        assert args.url == "https://example.com/dashboard"
        assert args.output is None
    
    def test_parser_export_with_output(self):
        """Test export with output file"""
        parser = create_parser()
        args = parser.parse_args(["export", "https://example.com", "-o", "output.json"])
        assert args.output == "output.json"
    
    def test_parser_import_args(self):
        """Test import command arguments"""
        parser = create_parser()
        args = parser.parse_args(["import", "dashboard.json"])
        assert args.command == "import"
        assert args.file == "dashboard.json"
        assert args.no_verify is False
    
    def test_parser_import_no_verify(self):
        """Test import with --no-verify flag"""
        parser = create_parser()
        args = parser.parse_args(["import", "dashboard.json", "--no-verify"])
        assert args.no_verify is True
    
    def test_parser_validate_args(self):
        """Test validate command arguments"""
        parser = create_parser()
        args = parser.parse_args(["validate", "dashboard.json"])
        assert args.command == "validate"
        assert args.file == "dashboard.json"
    
    def test_parser_config_no_args(self):
        """Test config command without arguments"""
        parser = create_parser()
        args = parser.parse_args(["config"])
        assert args.command == "config"
        assert args.get is None
        assert args.set is None
    
    def test_parser_config_get(self):
        """Test config --get argument"""
        parser = create_parser()
        args = parser.parse_args(["config", "--get", "browser.headless"])
        assert args.get == "browser.headless"
    
    def test_parser_config_set(self):
        """Test config --set argument"""
        parser = create_parser()
        args = parser.parse_args(["config", "--set", "browser.headless=false"])
        assert args.set == "browser.headless=false"
    
    def test_parser_version(self):
        """Test version command"""
        parser = create_parser()
        args = parser.parse_args(["version"])
        assert args.command == "version"
    
    def test_parser_verbose_flag(self):
        """Test global --verbose flag"""
        parser = create_parser()
        args = parser.parse_args(["--verbose", "version"])
        assert args.verbose is True
    
    def test_parser_config_file_flag(self):
        """Test global --config-file flag"""
        parser = create_parser()
        args = parser.parse_args(["--config-file", "custom.json", "version"])
        assert args.config_file == "custom.json"

class TestExportCommand:
    """Test export command execution"""
    
    @pytest.mark.asyncio
    async def test_export_success(self, mock_mcp_client, sample_config, capsys):
        """Test successful export"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            # Mock successful export
            mock_exporter = AsyncMock()
            mock_exporter.export_dashboard = AsyncMock(return_value=True)
            
            with patch("kusto_dashboard_manager.DashboardExporter") as mock_exporter_class:
                mock_exporter_class.return_value = mock_exporter
                
                args = Mock(url="https://example.com/dashboard", output="output.json")
                result = await export_command(args)
                
                assert result == 0
                mock_exporter.export_dashboard.assert_called_once_with(
                    "https://example.com/dashboard", 
                    "output.json"
                )
    
    @pytest.mark.asyncio
    async def test_export_failure(self, mock_mcp_client, sample_config, capsys):
        """Test export failure handling"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            # Mock export failure
            mock_exporter = AsyncMock()
            mock_exporter.export_dashboard = AsyncMock(side_effect=Exception("Export error"))
            
            with patch("kusto_dashboard_manager.DashboardExporter") as mock_exporter_class:
                mock_exporter_class.return_value = mock_exporter
                
                args = Mock(url="https://example.com/dashboard", output="output.json")
                result = await export_command(args)
                
                assert result == 1
                captured = capsys.readouterr()
                assert "Export failed: Export error" in captured.out

class TestImportCommand:
    """Test import command execution"""
    
    @pytest.mark.asyncio
    async def test_import_success(self, mock_mcp_client, sample_config):
        """Test successful import"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            # Mock successful import
            mock_importer = AsyncMock()
            mock_importer.import_dashboard = AsyncMock(return_value=True)
            
            with patch("kusto_dashboard_manager.DashboardImporter") as mock_importer_class:
                mock_importer_class.return_value = mock_importer
                
                args = Mock(file="dashboard.json", no_verify=False)
                result = await import_command(args)
                
                assert result == 0
                mock_importer.import_dashboard.assert_called_once_with(
                    "dashboard.json",
                    verify=True
                )
    
    @pytest.mark.asyncio
    async def test_import_no_verify(self, mock_mcp_client, sample_config):
        """Test import with --no-verify flag"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            mock_importer = AsyncMock()
            mock_importer.import_dashboard = AsyncMock(return_value=True)
            
            with patch("kusto_dashboard_manager.DashboardImporter") as mock_importer_class:
                mock_importer_class.return_value = mock_importer
                
                args = Mock(file="dashboard.json", no_verify=True)
                result = await import_command(args)
                
                assert result == 0
                mock_importer.import_dashboard.assert_called_once_with(
                    "dashboard.json",
                    verify=False
                )
    
    @pytest.mark.asyncio
    async def test_import_failure(self, mock_mcp_client, sample_config, capsys):
        """Test import failure handling"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            # Mock import failure
            mock_importer = AsyncMock()
            mock_importer.import_dashboard = AsyncMock(side_effect=ValueError("Invalid file"))
            
            with patch("kusto_dashboard_manager.DashboardImporter") as mock_importer_class:
                mock_importer_class.return_value = mock_importer
                
                args = Mock(file="dashboard.json", no_verify=False)
                result = await import_command(args)
                
                assert result == 1
                captured = capsys.readouterr()
                assert "Import failed: Invalid file" in captured.out

class TestValidateCommand:
    """Test validate command execution"""
    
    def test_validate_success(self, temp_dashboard_file, capsys):
        """Test validation of valid file"""
        args = Mock(file=str(temp_dashboard_file))
        result = validate_command(args)
        
        assert result == 0
        captured = capsys.readouterr()
        assert "Valid dashboard" in captured.out
    
    def test_validate_invalid_file(self, tmp_path, capsys):
        """Test validation of invalid file"""
        invalid_file = tmp_path / "invalid.json"
        invalid_file.write_text("{invalid json")
        
        args = Mock(file=str(invalid_file))
        result = validate_command(args)
        
        assert result == 1
        captured = capsys.readouterr()
        assert "Invalid dashboard" in captured.out or "Validation failed" in captured.out
    
    def test_validate_nonexistent_file(self, capsys):
        """Test validation of nonexistent file"""
        args = Mock(file="nonexistent.json")
        result = validate_command(args)
        
        assert result == 1
        captured = capsys.readouterr()
        # Error message could be "Validation failed" or "Invalid dashboard"
        assert "Validation failed" in captured.out or "Invalid dashboard" in captured.out

class TestConfigCommand:
    """Test config command execution"""
    
    def test_config_show_all(self, sample_config, capsys):
        """Test showing all configuration"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config:
            config = Config(sample_config)
            mock_get_config.return_value = config
            
            args = Mock(get=None, set=None)
            result = config_command(args)
            
            assert result == 0
            captured = capsys.readouterr()
            # Output should contain JSON representation
            assert "{" in captured.out
    
    def test_config_get_value(self, sample_config, capsys):
        """Test getting specific config value"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config:
            config = Config(sample_config)
            mock_get_config.return_value = config
            
            args = Mock(get="browser.headless", set=None)
            result = config_command(args)
            
            assert result == 0
            captured = capsys.readouterr()
            assert "browser.headless" in captured.out
            assert "True" in captured.out
    
    def test_config_set_value(self, sample_config, capsys):
        """Test setting config value"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config:
            config = Config(sample_config)
            mock_get_config.return_value = config
            
            args = Mock(get=None, set="browser.headless=false")
            result = config_command(args)
            
            assert result == 0
            assert config.get("browser.headless") == "false"
            captured = capsys.readouterr()
            assert "Set browser.headless = false" in captured.out

class TestVersionCommand:
    """Test version command execution"""
    
    def test_version_output(self, capsys):
        """Test version command output"""
        args = Mock()
        result = version_command(args)
        
        assert result == 0
        captured = capsys.readouterr()
        assert VERSION in captured.out
        assert "Kusto Dashboard Manager" in captured.out

class TestMainFunction:
    """Test main() entry point"""
    
    def test_main_no_args(self, capsys):
        """Test main with no arguments shows help"""
        with patch("sys.argv", ["kusto_dashboard_manager.py"]):
            result = main()
            
            assert result == 1
            captured = capsys.readouterr()
            assert "usage:" in captured.out or "Kusto Dashboard Manager" in captured.out
    
    def test_main_version_command(self, capsys):
        """Test main with version command"""
        with patch("sys.argv", ["kusto_dashboard_manager.py", "version"]):
            with patch("kusto_dashboard_manager.Config.from_env") as mock_from_env:
                mock_from_env.return_value = Config({})
                result = main()
                
                assert result == 0
                captured = capsys.readouterr()
                assert VERSION in captured.out
    
    def test_main_with_config_file(self, tmp_path):
        """Test main with --config-file flag"""
        config_file = tmp_path / "config.json"
        config_file.write_text('''{"browser": {"headless": true}}''')
        
        with patch("sys.argv", ["kusto_dashboard_manager.py", "--config-file", str(config_file), "version"]):
            with patch("kusto_dashboard_manager.Config.from_file") as mock_from_file, \
                 patch("kusto_dashboard_manager.set_config") as mock_set_config:
                
                mock_config = Config({})
                mock_from_file.return_value = mock_config
                
                result = main()
                
                mock_from_file.assert_called_once_with(str(config_file))
                mock_set_config.assert_called_once_with(mock_config)
    
    def test_main_with_verbose_flag(self):
        """Test main with --verbose flag"""
        with patch("sys.argv", ["kusto_dashboard_manager.py", "--verbose", "version"]):
            with patch("kusto_dashboard_manager.Config.from_env") as mock_from_env, \
                 patch("kusto_dashboard_manager.set_logger") as mock_set_logger:
                
                mock_from_env.return_value = Config({})
                
                result = main()
                
                # Verify logger was set with DEBUG level
                assert mock_set_logger.called
                logger_arg = mock_set_logger.call_args[0][0]
                assert isinstance(logger_arg, Logger)
                assert logger_arg.enabled is True
                assert logger_arg.level == "DEBUG"
    
    def test_main_unknown_command(self, capsys):
        """Test main with unknown command"""
        # This should be caught by argparse, but test the handler logic
        with patch("sys.argv", ["kusto_dashboard_manager.py", "unknown"]):
            with patch("kusto_dashboard_manager.Config.from_env") as mock_from_env:
                mock_from_env.return_value = Config({})
                
                # argparse will exit on unknown command, so catch SystemExit
                with pytest.raises(SystemExit):
                    main()
    
    def test_main_async_command_execution(self, mock_mcp_client, sample_config):
        """Test main executes async commands properly"""
        with patch("sys.argv", ["kusto_dashboard_manager.py", "import", "dashboard.json"]):
            with patch("kusto_dashboard_manager.Config.from_env") as mock_from_env, \
                 patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class, \
                 patch("kusto_dashboard_manager.DashboardImporter") as mock_importer_class:
                
                mock_from_env.return_value = Config(sample_config)
                mock_client_class.return_value = mock_mcp_client
                
                mock_importer = AsyncMock()
                mock_importer.import_dashboard = AsyncMock(return_value=True)
                mock_importer_class.return_value = mock_importer
                
                result = main()
                
                # Should return 0 for success
                assert result == 0
    
    def test_main_sync_command_execution(self, sample_config, capsys):
        """Test main executes sync commands properly"""
        with patch("sys.argv", ["kusto_dashboard_manager.py", "config"]):
            with patch("kusto_dashboard_manager.Config.from_env") as mock_from_env, \
                 patch("kusto_dashboard_manager.get_config") as mock_get_config:
                
                config = Config(sample_config)
                mock_from_env.return_value = config
                mock_get_config.return_value = config
                
                result = main()
                
                assert result == 0
                captured = capsys.readouterr()
                assert "{" in captured.out

class TestCLIIntegration:
    """Integration tests for CLI workflow"""
    
    def test_export_import_workflow(self, mock_mcp_client, sample_config, tmp_path):
        """Test export followed by import workflow"""
        export_file = tmp_path / "exported.json"
        
        # Mock export
        with patch("kusto_dashboard_manager.get_config") as mock_get_config, \
             patch("kusto_dashboard_manager.PlaywrightMCPClient") as mock_client_class:
            
            mock_get_config.return_value = Config(sample_config)
            mock_client_class.return_value = mock_mcp_client
            
            mock_exporter = AsyncMock()
            mock_exporter.export_dashboard = AsyncMock(return_value=True)
            
            with patch("kusto_dashboard_manager.DashboardExporter") as mock_exporter_class:
                mock_exporter_class.return_value = mock_exporter
                
                args = Mock(url="https://example.com", output=str(export_file))
                result = asyncio.run(export_command(args))
                assert result == 0
    
    def test_validate_after_export(self, temp_dashboard_file):
        """Test validate command on exported file"""
        args = Mock(file=str(temp_dashboard_file))
        result = validate_command(args)
        assert result == 0
    
    def test_config_persistence_across_commands(self, sample_config):
        """Test config changes persist across commands"""
        with patch("kusto_dashboard_manager.get_config") as mock_get_config:
            config = Config(sample_config)
            mock_get_config.return_value = config
            
            # Set a value
            set_args = Mock(get=None, set="test.key=test_value")
            result = config_command(set_args)
            assert result == 0
            
            # Get the value
            get_args = Mock(get="test.key", set=None)
            result = config_command(get_args)
            assert result == 0
            assert config.get("test.key") == "test_value"
