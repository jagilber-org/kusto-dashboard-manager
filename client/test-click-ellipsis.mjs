#!/usr/bin/env node

/**
 * Click the "Additional options" button using the ref from snapshot
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

async function clickAdditionalOptions() {
  console.log('🧪 Clicking Additional Options Button\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect
    console.log('1️⃣  Connecting...');
    playwrightClient = new Client(
      { name: 'click-opts', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'click-opts', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('    ✅ Connected\n');

    // Navigate
    console.log('2️⃣  Navigating to dashboards...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('    ✅ Ready\n');

    // Get snapshot to find the ref
    console.log('3️⃣  Getting current page snapshot...');
    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = snapshotResponse.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    // Parse to get first dashboard
    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const parseResult = JSON.parse(parseResponse.content[0].text);
    const dashboard = parseResult.dashboards[0];
    console.log(`    Target: ${dashboard.name}`);

    // Find the Additional options button ref
    const lines = snapshot.split('\n');
    let optionsRef = null;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('Additional options') && lines[i].includes('[ref=')) {
        const match = lines[i].match(/\[ref=([^\]]+)\]/);
        if (match) {
          optionsRef = match[1];
          console.log(`    Found button ref: ${optionsRef}\n`);
          break;
        }
      }
    }

    if (!optionsRef) {
      console.log('    ❌ Could not find Additional options button ref\n');
      return;
    }

    // Click using ref
    console.log('4️⃣  Clicking Additional options button...');
    try {
      const clickResponse = await playwrightClient.callTool({
        name: 'browser_click',
        arguments: {
          element: 'Additional options button',
          description: 'Click the Additional options button to see export menu',
          ref: optionsRef
        }
      });

      console.log('    ✅ Clicked!\n');

      // Wait for menu
      await sleep(2000);

      // Get menu snapshot
      console.log('5️⃣  Taking snapshot of menu...');
      const menuSnapshot = await playwrightClient.callTool({
        name: 'browser_snapshot',
        arguments: {}
      });

      let menuSnap = menuSnapshot.content[0].text;
      if (menuSnap.includes('```yaml')) {
        menuSnap = menuSnap.split('```yaml\n')[1].split('\n```')[0];
      }

      console.log(`    ✅ Got menu (${menuSnap.length} chars)\n`);

      // Show menu options
      console.log('📋 Menu Options:');
      console.log('─'.repeat(60));
      const menuLines = menuSnap.split('\n');

      let foundMenu = false;
      for (let i = 0; i < menuLines.length; i++) {
        const line = menuLines[i];

        // Look for menu or dialog elements
        if (line.includes('menu ') ||
            line.includes('dialog') ||
            line.includes('popup')) {
          foundMenu = true;
          console.log('>>> MENU START <<<');

          // Print next 30 lines
          for (let j = i; j < Math.min(i + 30, menuLines.length); j++) {
            console.log(menuLines[j]);
          }
          console.log('>>> MENU END <<<');
          break;
        }

        // Also look for menu items
        if (line.toLowerCase().includes('export') ||
            line.toLowerCase().includes('save') ||
            line.toLowerCase().includes('download') ||
            line.toLowerCase().includes('copy') ||
            line.toLowerCase().includes('share') ||
            (line.includes('menuitem') && !foundMenu)) {
          console.log(line);
        }
      }

      if (!foundMenu) {
        console.log('⚠️  No menu found in snapshot - menu might not have opened');
        console.log('    Showing lines with relevant keywords instead:');
        console.log('');

        for (const line of menuLines.slice(0, 200)) {
          if (line.toLowerCase().includes('export') ||
              line.toLowerCase().includes('save') ||
              line.toLowerCase().includes('download') ||
              line.toLowerCase().includes('copy') ||
              line.toLowerCase().includes('share') ||
              line.toLowerCase().includes('duplicate') ||
              line.toLowerCase().includes('delete') ||
              line.toLowerCase().includes('edit')) {
            console.log(`    ${line}`);
          }
        }
      }

      console.log('─'.repeat(60));
      console.log('');

    } catch (error) {
      console.log(`    ❌ Click failed: ${error.message}\n`);
      console.error(error);
    }

    console.log('✅ Test complete!\n');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    console.log('🧹 Cleaning up...');
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
    console.log('    ✅ Done\n');
  }
}

clickAdditionalOptions()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
