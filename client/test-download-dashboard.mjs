#!/usr/bin/env node

/**
 * Complete workflow: Click ellipsis → Download dashboard to file
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFileSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function downloadDashboard() {
  console.log('📥 Testing dashboard download workflow\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect to both MCPs
    console.log('Connecting to MCP servers...');
    playwrightClient = new Client(
      { name: 'download-test', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'download-test', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('✅ Connected\n');

    // Navigate to dashboards page
    console.log('Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Step 1: Click the ellipsis button (ref=e204 for armprod)
    console.log('Step 1: Clicking Additional options button...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: {
        element: 'Additional options',
        description: 'Click Additional options ellipsis button',
        ref: 'e204'
      }
    });
    console.log('✅ Ellipsis clicked\n');

    // Wait for menu
    await sleep(2000);

    // Step 2: Click "Download dashboard to file"
    console.log('Step 2: Clicking "Download dashboard to file"...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: {
        element: 'Download dashboard to file',
        description: 'Click to download the dashboard JSON',
        ref: 'e677'
      }
    });
    console.log('✅ Download clicked\n');

    // Wait for download/dialog
    console.log('⏳ Waiting for download or dialog...');
    await sleep(3000);

    // Get snapshot to see what happened
    const afterSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = afterSnapshot.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    console.log(`Snapshot: ${snapshot.length} chars\n`);

    // Look for any dialogs, textareas, or download indicators
    console.log('🔍 Looking for download result...\n');
    console.log('='.repeat(80));

    const lines = snapshot.split('\n');
    let foundDialog = false;
    let foundDownload = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Look for dialog, textarea with JSON, or download-related elements
      if (line.includes('dialog [') ||
          line.includes('textbox') && line.includes('{') ||
          line.includes('Download') ||
          line.includes('Save') ||
          line.includes('JSON')) {

        foundDialog = true;

        // Print context
        const startLine = Math.max(0, i - 3);
        const endLine = Math.min(lines.length, i + 30);

        for (let j = startLine; j < endLine; j++) {
          if (j === i) {
            console.log(`>>> ${lines[j]}`);
          } else {
            console.log(`    ${lines[j]}`);
          }

          // Stop at next major element
          if (j > i + 5 && lines[j].trim().startsWith('- ') &&
              lines[j].includes('[ref=') &&
              !lines[j].includes('textbox') &&
              !lines[j].includes('button') &&
              !lines[j].includes('text:')) {
            break;
          }
        }

        console.log('─'.repeat(80));
      }
    }

    if (!foundDialog) {
      console.log('⚠️  No dialog found. The file may have been downloaded directly.');
      console.log('Check your Downloads folder for a JSON file.');
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

downloadDashboard()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
