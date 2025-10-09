# Playwright MCP - Getting Started

## ✅ Verification Complete

Playwright MCP server is installed and ready! (Version check passed)

## 🎯 How to Use Playwright MCP

### Important: MCP Tools Work Through Copilot Chat

Playwright MCP tools are **MCP (Model Context Protocol) tools**, which means:
- ❌ They **cannot** be called directly from this chat
- ✅ They **must** be called through **Copilot Chat** (Ctrl+Alt+I)

### Why?

MCP tools are extensions that Copilot Chat loads and executes. This chat session (with me) is focused on helping you set up and understand the workflow, but **Copilot Chat** is the one that actually runs the browser automation.

---

## 🚀 Your Next Steps

### Step 1: Open Copilot Chat

Click the **chat icon** in VS Code sidebar or press **Ctrl+Alt+I**

### Step 2: Verify MCP Tools Are Loaded

In Copilot Chat, ask:
```
What MCP servers are available? List the Playwright tools.
```

You should see tools like:
- `browser_navigate`
- `browser_snapshot`
- `browser_click`
- `browser_evaluate`
- etc.

### Step 3: Run Your First Navigation

**Copy this into Copilot Chat** (not here):

```
Using the Playwright MCP browser_navigate tool, navigate to:
https://dataexplorer.azure.com/dashboards

Wait for the page to load completely.
```

### Step 4: Capture the Snapshot

Once navigation succeeds, **copy this into Copilot Chat**:

```
Using browser_snapshot, capture the accessibility tree of the current page.
Save the complete YAML output to:
c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboards-list.yaml
```

---

## 📋 Copy/Paste Prompts Ready

All prompts are ready in:
- `docs/QUICK_START_WORKFLOW.md` - Phase-by-phase guide
- `TRACING_ENABLED.md` - Complete setup reference

---

## 🤝 How We Work Together

**Me (This Chat):**
- ✅ Set up configuration
- ✅ Create scripts and documentation
- ✅ Analyze results after you run workflows
- ✅ Help debug and improve code

**Copilot Chat:**
- ✅ Execute MCP tools (browser automation)
- ✅ Call Playwright MCP server
- ✅ Navigate, snapshot, click, evaluate
- ✅ Generate code based on exploration

**You:**
- ✅ Copy prompts from docs to Copilot Chat
- ✅ Review outputs (YAML, JSON, traces)
- ✅ Report back results
- ✅ Guide the exploration

---

## 📝 Workflow Example

1. **You ask me:** "What prompt should I use to capture dashboards?"
2. **I provide:** Detailed prompt with exact parameters
3. **You paste** that prompt into **Copilot Chat**
4. **Copilot Chat** executes using Playwright MCP
5. **You share** the output file with me
6. **I analyze** and provide next steps

---

## 🎬 Ready to Start!

Go ahead and:
1. Open **Copilot Chat** (Ctrl+Alt+I)
2. Paste the navigation prompt from Step 3 above
3. Come back here and tell me what happened!

I'll be here to help analyze results and provide next prompts! 🚀

---

## Quick Reference Commands

### In Copilot Chat (for browser automation):
```
Navigate to <URL>
Capture snapshot and save to <path>
Click element with text "<text>"
Evaluate JavaScript: <code>
```

### In This Chat (for analysis/coding):
```
Analyze the YAML at docs/snapshots/dashboards-list.yaml
Implement the parser based on this structure
Debug why the extraction isn't working
Create a script to process these files
```

Let's do this! Open Copilot Chat and run that first navigation! 🎯
