# Dashboard API Authentication Challenge

**Date:** October 9, 2025  
**Issue:** Direct API calls fail with 401 Unauthorized  
**Status:** ⚠️ BLOCKED - Authentication Required

## Problem Summary

We discovered the correct dashboard API endpoint:
```
https://dashboards.kusto.windows.net/dashboards/{dashboard-id}
```

However, direct `fetch()` calls from the browser context fail with **401 Unauthorized**:

```javascript
// Test code executed in browser via browser_evaluate
const response = await fetch('https://dashboards.kusto.windows.net/dashboards/03e8f08f-8111-40f4-9f58-270678db9782');
// Result: 401 Unauthorized
```

## Root Cause Analysis

### Why It Works During Page Load
The Performance API shows this same endpoint **successfully** loads during page initialization:
- Request: `https://dashboards.kusto.windows.net/dashboards/03e8f08f-8111-40f4-9f58-270678db9782`
- Type: `fetch`
- Duration: `447.7ms`
- Result: **SUCCESS** (data loaded into dashboard)

### Why Our fetch() Fails

**Cross-Origin Authentication Issue:**
1. **Page Origin:** `https://dataexplorer.azure.com`
2. **API Origin:** `https://dashboards.kusto.windows.net`
3. **Problem:** Cross-origin requests require special authentication headers

The application likely uses one of these auth mechanisms:
- Azure AD Bearer tokens in `Authorization` header
- Special API keys or session tokens
- Cookie-based auth with specific domain configuration
- Custom authentication headers

## Attempted Solutions

### ❌ Option 1: Direct fetch() from Browser Context
```javascript
// FAILED with 401
const response = await fetch('https://dashboards.kusto.windows.net/dashboards/03e8f08f-8111-40f4-9f58-270678db9782');
```

**Problem:** No authentication headers included

### ❓ Option 2: Extract Auth Headers
Need to find how the application authenticates its API calls.

**Possible approaches:**
1. Monitor network requests during page load to capture auth headers
2. Search JavaScript bundle for token generation code
3. Check localStorage/sessionStorage for auth tokens
4. Inspect cookies sent to `dashboards.kusto.windows.net`

## Investigation Steps

### Step 1: Check for Stored Tokens

<function_calls>
<invoke name="mcp_playwright_browser_evaluate">
<parameter name="function">() => {
  const results = {
    localStorage: {},
    sessionStorage: {},
    cookies: document.cookie
  };
  
  // Check localStorage for tokens
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (key && (key.includes('token') || key.includes('auth') || key.includes('azure') || key.includes('kusto'))) {
      const value = localStorage.getItem(key);
      // Only show first 50 chars for security
      results.localStorage[key] = value ? value.substring(0, 50) + '...' : null;
    }
  }
  
  // Check sessionStorage for tokens
  for (let i = 0; i < sessionStorage.length; i++) {
    const key = sessionStorage.key(i);
    if (key && (key.includes('token') || key.includes('auth') || key.includes('azure') || key.includes('kusto'))) {
      const value = sessionStorage.getItem(key);
      // Only show first 50 chars for security
      results.sessionStorage[key] = value ? value.substring(0, 50) + '...' : null;
    }
  }
  
  return results;
}