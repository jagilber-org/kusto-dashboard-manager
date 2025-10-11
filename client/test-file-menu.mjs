#!/usr/bin/env node

/**
 * Export dashboard by exploring File menu
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { writeFileSync, mkdirSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function exportViaFileMenu() {
  console.log('🧪 Exploring File Menu for Export\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect to both MCPs
    console.log('1️⃣  Connecting to MCP servers...');
    playwrightClient = new Client(
      { name: 'file-menu', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'file-menu', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('    ✅ Connected\n');

    // Navigate and get dashboard
    console.log('2️⃣  Getting dashboard...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);

    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = snapshotResponse.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const parseResult = JSON.parse(parseResponse.content[0].text);
    const dashboard = parseResult.dashboards[0];
    console.log(`    ✅ Found: ${dashboard.name}\n`);

    // Navigate to dashboard
    console.log('3️⃣  Opening dashboard...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: dashboard.url }
    });
    await sleep(5000);
    console.log('    ✅ Loaded\n');

    // Click File menu
    console.log('4️⃣  Clicking File menu...');
    try {
      await playwrightClient.callTool({
        name: 'browser_click',
        arguments: {
          element: 'File menu item',
          description: 'Click File menu to see export options'
        }
      });
      console.log('    ✅ Clicked File\n');

      await sleep(1000);

      // Get snapshot of File menu
      const fileMenuSnap = await playwrightClient.callTool({
        name: 'browser_snapshot',
        arguments: {}
      });

      let fileMenu = fileMenuSnap.content[0].text;
      if (fileMenu.includes('```yaml')) {
        fileMenu = fileMenu.split('```yaml\n')[1].split('\n```')[0];
      }

      console.log('📋 File Menu Contents:');
      console.log('─'.repeat(60));
      const menuLines = fileMenu.split('\n');
      let inFileMenu = false;
      for (let i = 0; i < menuLines.length; i++) {
        const line = menuLines[i];
        if (line.includes('menuitem') && (line.includes('File') || inFileMenu)) {
          inFileMenu = true;
          console.log(line);
          // Print next 20 lines to see menu items
          for (let j = i + 1; j < Math.min(i + 30, menuLines.length); j++) {
            console.log(menuLines[j]);
            if (menuLines[j].includes('menuitem') && !menuLines[j].includes('File')) {
              break; // End of File menu
            }
          }
          break;
        }
      }
      console.log('─'.repeat(60));
      console.log('');

    } catch (error) {
      console.log(`    ⚠️  Error clicking File: ${error.message}\n`);
    }

    // Also try looking at the page source/DOM directly
    console.log('5️⃣  Trying to extract dashboard JSON from page...');
    const extractScript = `async () => {
      // The dashboard data might be in window object or data attributes
      const possibleKeys = ['dashboard', 'dashboardData', '__INITIAL_STATE__',
                           'data', 'config', 'dashboardState'];

      const found = {};
      for (const key of possibleKeys) {
        if (window[key]) {
          found[key] = typeof window[key];
        }
      }

      // Also check for data in DOM
      const dataElements = document.querySelectorAll('[data-dashboard], [data-definition]');

      return JSON.stringify({
        windowKeys: found,
        dataElementsCount: dataElements.length,
        documentTitle: document.title,
        url: window.location.href
      });
    }`;

    try {
      const extractResponse = await playwrightClient.callTool({
        name: 'browser_evaluate',
        arguments: { function: extractScript }
      });

      const extractResult = extractResponse.content[0].text;
      console.log('    Window object inspection:');
      if (extractResult.includes('### Result')) {
        const resultText = extractResult.split('\n').slice(1).join('\n').trim();
        console.log('   ', resultText);
      } else {
        console.log('   ', extractResult.substring(0, 500));
      }
      console.log('');

    } catch (error) {
      console.log(`    ⚠️  Error: ${error.message}\n`);
    }

    console.log('✅ Exploration complete!\n');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    console.log('🧹 Cleaning up...');
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
    console.log('    ✅ Done\n');
  }
}

exportViaFileMenu()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
