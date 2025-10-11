#!/usr/bin/env node

/**
 * Get details about the browser_evaluate tool
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

async function getToolInfo() {
  let client, transport;

  try {
    console.log('Connecting to Playwright MCP...\n');
    client = new Client(
      { name: 'tool-info', version: '1.0.0' },
      { capabilities: {} }
    );
    transport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await client.connect(transport);
    console.log('✅ Connected\n');

    const response = await client.listTools();
    const evalTool = response.tools.find(t => t.name === 'browser_evaluate');

    console.log('browser_evaluate tool details:\n');
    console.log(JSON.stringify(evalTool, null, 2));

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (transport) await transport.close();
  }
}

getToolInfo()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Failed:', error);
    process.exit(1);
  });
