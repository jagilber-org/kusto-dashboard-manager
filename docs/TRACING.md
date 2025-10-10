# Tracing Configuration

The kusto-dashboard-manager now includes comprehensive tracing capabilities with file logging.

## Features

- **Console & File Logging**: Trace output goes to both console and timestamped log files
- **Global Enable/Disable**: Control tracing via environment variables or config
- **Configurable Log Level**: Set to DEBUG, INFO, WARNING, or ERROR
- **Automatic Context**: Function entry/exit, MCP calls, browser actions, parsing operations
- **Performance Tracking**: HTTP requests with timing, parsing operations with size metrics

## Configuration

### Environment Variables (.env)

Add to your `.env` file:

```properties
# Tracing Configuration
TRACE_ENABLED=true
TRACE_FILE_LOGGING=true
TRACE_LEVEL=DEBUG
TRACE_LOG_DIR=logs
```

### Config File (JSON)

Or configure via JSON config:

```json
{
  "tracing": {
    "enabled": true,
    "file_logging": true,
    "level": "DEBUG",
    "log_dir": "logs"
  }
}
```

## Log Files

When tracing is enabled with file logging:

- **Location**: `./logs/trace-{timestamp}.log`
- **Format**: `[timestamp] [level] [module] [file:line] message | context`
- **Encoding**: UTF-8 (supports Unicode/emoji in dashboard names)

Example:
```
[2025-01-09 10:30:15.123456] [INFO] [kusto-dashboard-tracer] [dashboard_export.py:125] Dashboard list retrieved | total_found=31
[2025-01-09 10:30:15.234567] [INFO] [kusto-dashboard-tracer] [dashboard_export.py:131] Filtered dashboards | original=31 | filtered=23 | creator=Jason Gilbertson
```

## Trace Functions

### Function Tracing

```python
from tracer import trace_func_entry, trace_func_exit

async def my_function(arg1, arg2):
    trace_func_entry("my_function", arg1=arg1, arg2=arg2)
    try:
        result = do_something()
        trace_func_exit("my_function", result=result)
        return result
    except Exception as e:
        trace_func_exit("my_function", error=str(e))
        raise
```

### MCP Tool Calls

```python
from tracer import trace_mcp_call

params = {"url": url}
try:
    result = await mcp_client.call_tool("browser_navigate", params)
    trace_mcp_call("browser_navigate", params, "success")
except Exception as e:
    trace_mcp_call("browser_navigate", params, error=str(e))
```

### Browser Actions

```python
from tracer import trace_browser_action

trace_browser_action("navigate", {"url": url})
trace_browser_action("snapshot")
trace_browser_action("close")
```

### Parsing Operations

```python
from tracer import trace_parse

trace_parse("snapshot_text", input_size=len(raw_text))
# ... do parsing ...
trace_parse("snapshot_text", output_count=len(dashboards), details=f"Found {len(dashboards)} dashboards")
```

### General Logging

```python
from tracer import trace_info, trace_error, trace_warning, trace_debug

trace_info("Starting bulk export", creator_filter=creator_filter)
trace_error("Failed to export", url=url, error=str(e))
trace_warning("Dashboard already exists", name=name)
trace_debug("Parsing row", row_number=i, text=row_text)
```

## Disable Tracing

Set in `.env`:
```properties
TRACE_ENABLED=false
```

Or programmatically:
```python
from tracer import disable_tracing
disable_tracing()
```

## Best Practices

1. **Enable for Debugging**: Turn on tracing when troubleshooting issues
2. **Review Log Files**: Check `./logs/trace-*.log` for detailed execution flow
3. **Performance Impact**: Tracing adds minimal overhead but can generate large log files
4. **Clean Old Logs**: Periodically remove old trace files from `./logs/`
5. **Sensitive Data**: Trace logs may contain URLs and dashboard names - protect accordingly

## Traced Components

- `dashboard_export.py`: All export operations, parsing, filtering
- `browser_manager.py`: Browser lifecycle, navigation, snapshots
- `playwright_mcp_client.py`: MCP protocol communication (future)
- `mcp_server.py`: MCP server tool invocations (future)

## Example Output

With tracing enabled, you'll see detailed logs like:

```
[2025-01-09 10:30:15] [DEBUG] >>> ENTER: export_all_dashboards(list_url=https://dataexplorer.azure.com/dashboards, creator_filter=Jason Gilbertson)
[2025-01-09 10:30:15] [INFO] Bulk export starting | creator_filter=Jason Gilbertson
[2025-01-09 10:30:15] [INFO] Browser Action | action=launch
[2025-01-09 10:30:16] [INFO] MCP Call | tool=browser_launch | params={'browser': 'edge', 'headless': False} | result=success
[2025-01-09 10:30:16] [DEBUG] >>> ENTER: _get_dashboard_list(list_url=https://dataexplorer.azure.com/dashboards)
[2025-01-09 10:30:16] [INFO] Browser Action | action=navigate | url=https://dataexplorer.azure.com/dashboards
[2025-01-09 10:30:16] [INFO] Waiting 8 seconds for dashboards to load
[2025-01-09 10:30:24] [INFO] Browser Action | action=snapshot
[2025-01-09 10:30:25] [INFO] MCP Call | tool=browser_snapshot | params={} | result=success, size: 8234
[2025-01-09 10:30:25] [DEBUG] Parse Operation | operation=snapshot_text | input_size=8234
[2025-01-09 10:30:25] [DEBUG] Parse Operation | operation=row_found | details=Row text: armprod about 1 hour ago 11/3/2020 Jason Gilbertson
[2025-01-09 10:30:25] [DEBUG] Parse Operation | operation=name_extracted | details=armprod
[2025-01-09 10:30:25] [DEBUG] Parse Operation | operation=url_extracted | details=https://dataexplorer.azure.com/dashboards/03e8f08f-8111-40f4-9f58-270678db9782
[2025-01-09 10:30:25] [DEBUG] Parse Operation | operation=creator_extracted | details=Jason Gilbertson
[2025-01-09 10:30:25] [INFO] Dashboard parsed | name=armprod | creator=Jason Gilbertson | url=https://dataexplorer.azure.com/dashboards/03e8f08f-8111-40f4-9f58-270678db9782
```
