# Traces Directory

This directory stores Playwright MCP trace files and session state.

## ⚠️ Privacy Notice

**Files in this directory are excluded from git** because they contain:
- Browser session data
- Authentication state
- Full page screenshots
- Network request/response data
- User interactions and navigation history

## Contents

Typical files:
- `trace-YYYY-MM-DD-HHMMSS.zip` - Playwright trace archives
- `session-YYYY-MM-DD-HHMMSS.json` - Session state snapshots

## Trace Files

Trace files are created when Playwright MCP is run with `--save-trace` flag:
- Full interaction history
- Screenshots at each step
- Network activity
- Console logs
- Page DOM snapshots

## Viewing Traces

```bash
# Extract and view a trace file
npx playwright show-trace traces/trace-2025-10-09-123456.zip
```

Opens an interactive trace viewer with timeline and details.

## Security

- **Never commit** trace files - they contain complete session data
- Traces may contain passwords if typed into forms
- Screenshots may show sensitive dashboard data
- Keep traces local only
