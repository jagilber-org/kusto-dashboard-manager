"""Tracing Module with File Logging"""

import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

# Global flags
TRACE_ENABLED = False
TRACE_FILE_ENABLED = False
TRACE_LEVEL = logging.DEBUG

# Logger instance
_tracer_logger: Optional[logging.Logger] = None
_file_handler: Optional[logging.FileHandler] = None


def enable_tracing(file_logging=True, level=logging.DEBUG, log_dir="logs"):
    """Enable tracing with optional file logging"""
    global TRACE_ENABLED, TRACE_FILE_ENABLED, TRACE_LEVEL, _tracer_logger, _file_handler

    TRACE_ENABLED = True
    TRACE_FILE_ENABLED = file_logging
    TRACE_LEVEL = level

    if _tracer_logger is None:
        _tracer_logger = logging.getLogger("kusto-dashboard-tracer")
        _tracer_logger.setLevel(level)
        _tracer_logger.propagate = False

        # DON'T add console handler - MCP servers must keep stdout clean for JSON-RPC
        # Only log to file when tracing is enabled

    if file_logging and _file_handler is None:
        # Create logs directory
        log_path = Path(__file__).parent.parent / log_dir
        log_path.mkdir(exist_ok=True)

        # Create log file with timestamp
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        log_file = log_path / f"trace-{timestamp}.log"

        _file_handler = logging.FileHandler(log_file, mode="a", encoding="utf-8")
        _file_handler.setLevel(level)
        file_formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] [%(name)s] [%(filename)s:%(lineno)d] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        _file_handler.setFormatter(file_formatter)
        _tracer_logger.addHandler(_file_handler)

        _tracer_logger.info(f"Tracing started - log file: {log_file}")


def disable_tracing():
    """Disable tracing"""
    global TRACE_ENABLED, TRACE_FILE_ENABLED, _file_handler

    TRACE_ENABLED = False
    TRACE_FILE_ENABLED = False

    if _file_handler and _tracer_logger:
        _tracer_logger.removeHandler(_file_handler)
        _file_handler.close()
        _file_handler = None


def trace(message: str, level=logging.DEBUG, context: dict = None):
    """Log a trace message"""
    if not TRACE_ENABLED or _tracer_logger is None:
        return

    if context:
        context_str = " | ".join([f"{k}={v}" for k, v in context.items()])
        message = f"{message} | {context_str}"

    _tracer_logger.log(level, message)


def trace_func_entry(func_name: str, **kwargs):
    """Trace function entry with arguments"""
    if not TRACE_ENABLED:
        return

    args_str = ", ".join([f"{k}={repr(v)[:100]}" for k, v in kwargs.items()])
    trace(f">>> ENTER: {func_name}({args_str})", logging.DEBUG)


def trace_func_exit(func_name: str, result=None, error=None):
    """Trace function exit with result or error"""
    if not TRACE_ENABLED:
        return

    if error:
        trace(f"<<< EXIT: {func_name} | ERROR: {error}", logging.ERROR)
    else:
        result_str = repr(result)[:200] if result is not None else "None"
        trace(f"<<< EXIT: {func_name} | Result: {result_str}", logging.DEBUG)


def trace_http(method: str, url: str, status: int = None, elapsed_ms: float = None):
    """Trace HTTP requests"""
    if not TRACE_ENABLED:
        return

    context = {"method": method, "url": url}
    if status:
        context["status"] = status
    if elapsed_ms:
        context["elapsed_ms"] = f"{elapsed_ms:.2f}"

    trace("HTTP Request", logging.INFO, context)


def trace_mcp_call(
    tool_name: str, params: dict = None, result: str = None, error: str = None
):
    """Trace MCP tool calls"""
    if not TRACE_ENABLED:
        return

    context = {"tool": tool_name}
    if params:
        context["params"] = str(params)[:200]

    if error:
        trace(f"MCP Call FAILED", logging.ERROR, {**context, "error": error})
    else:
        result_str = str(result)[:200] if result else "success"
        trace(f"MCP Call", logging.INFO, {**context, "result": result_str})


def trace_browser_action(action: str, details: dict = None):
    """Trace browser automation actions"""
    if not TRACE_ENABLED:
        return

    context = {"action": action}
    if details:
        context.update(details)

    trace("Browser Action", logging.INFO, context)


def trace_parse(
    operation: str,
    input_size: int = None,
    output_count: int = None,
    details: str = None,
):
    """Trace parsing operations"""
    if not TRACE_ENABLED:
        return

    context = {"operation": operation}
    if input_size is not None:
        context["input_size"] = input_size
    if output_count is not None:
        context["output_count"] = output_count
    if details:
        context["details"] = details

    trace("Parse Operation", logging.DEBUG, context)


# Convenience functions
def trace_debug(msg: str, **ctx):
    trace(msg, logging.DEBUG, ctx)


def trace_info(msg: str, **ctx):
    trace(msg, logging.INFO, ctx)


def trace_warning(msg: str, **ctx):
    trace(msg, logging.WARNING, ctx)


def trace_error(msg: str, **ctx):
    trace(msg, logging.ERROR, ctx)


def get_tracer():
    """Get the tracer logger instance"""
    return _tracer_logger
