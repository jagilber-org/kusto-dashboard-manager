#!/usr/bin/env node

/**
 * Click the correct ellipsis button and extract the full menu
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function testEllipsisMenu() {
  console.log('🎯 Testing ellipsis menu for dashboard export\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect to both MCPs
    console.log('Connecting to MCP servers...');
    playwrightClient = new Client(
      { name: 'ellipsis-test', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'ellipsis-test', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('✅ Connected to both MCPs\n');

    // Navigate to dashboards page
    console.log('Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('⏳ Waiting for page load...');
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Click the ellipsis button for armprod (ref=e204)
    console.log('Clicking Additional options button for armprod (ref=e204)...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: {
        element: 'Additional options',
        description: 'Click Additional options ellipsis button for armprod dashboard',
        ref: 'e204'
      }
    });
    console.log('✅ Clicked button\n');

    // Wait for menu to appear
    console.log('⏳ Waiting for menu to open...');
    await sleep(3000);

    // Get full snapshot with menu
    console.log('Getting full page snapshot with menu...');
    const menuSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = menuSnapshot.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    console.log(`✅ Snapshot retrieved (${snapshot.length} chars)\n`);

    // Search for menu/popover elements
    console.log('🔍 Searching for menu elements...\n');
    console.log('='.repeat(80));

    const lines = snapshot.split('\n');
    let foundMenu = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Look for menu, popover, or multiple menuitems together
      if (line.includes('menu [') ||
          line.includes('popover [') ||
          (line.includes('menuitem') && line.includes('Export')) ||
          (line.includes('menuitem') && line.includes('Download')) ||
          (line.includes('menuitem') && line.includes('Copy')) ||
          (line.includes('menuitem') && line.includes('Share')) ||
          (line.includes('menuitem') && line.includes('Delete'))) {

        if (!foundMenu) {
          console.log('\n📋 FOUND MENU STRUCTURE:');
          console.log('─'.repeat(80));
          foundMenu = true;
        }

        // Print context: 5 lines before, the line, and 30 lines after
        const startLine = Math.max(0, i - 5);
        const endLine = Math.min(lines.length, i + 35);

        for (let j = startLine; j < endLine; j++) {
          const contextLine = lines[j];

          // Highlight the matching line
          if (j === i) {
            console.log(`>>> ${contextLine}`);
          } else {
            console.log(`    ${contextLine}`);
          }

          // Stop at next major element
          if (j > i + 5 && contextLine.trim().startsWith('- ') &&
              !contextLine.includes('menuitem') &&
              !contextLine.includes('text:') &&
              !contextLine.includes('generic') &&
              contextLine.includes('[ref=')) {
            break;
          }
        }

        console.log('─'.repeat(80));
        console.log('');
      }
    }

    if (!foundMenu) {
      console.log('⚠️  No menu found in snapshot.');
      console.log('Let me search for any "Additional options" text:\n');

      for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes('Additional options')) {
          console.log(`Line ${i}: ${lines[i]}`);
        }
      }
    }

    console.log('='.repeat(80));

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  } finally {
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
  }
}

testEllipsisMenu()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
