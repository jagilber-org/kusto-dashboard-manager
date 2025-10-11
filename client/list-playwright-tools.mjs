#!/usr/bin/env node

/**
 * List available tools from Playwright MCP
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

async function listTools() {
  console.log('🔍 Listing Playwright MCP tools\n');

  let client, transport;

  try {
    console.log('Connecting to Playwright MCP...');
    client = new Client(
      { name: 'tool-lister', version: '1.0.0' },
      { capabilities: {} }
    );
    transport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await client.connect(transport);
    console.log('✅ Connected\n');

    console.log('Listing tools...');
    const response = await client.listTools();

    console.log(`\nFound ${response.tools.length} tools:\n`);
    response.tools.forEach((tool, idx) => {
      console.log(`${idx + 1}. ${tool.name}`);
      if (tool.description) {
        console.log(`   ${tool.description}`);
      }
      console.log('');
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (transport) await transport.close();
  }
}

listTools()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Failed:', error);
    process.exit(1);
  });
