#!/usr/bin/env node

/**
 * Find the CORRECT Additional options button for a specific dashboard row
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

async function findDashboardButton() {
  console.log('🔍 Finding the correct Additional options button for armprod\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect
    console.log('Connecting...');
    playwrightClient = new Client(
      { name: 'find-btn', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'find-btn', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('✅ Connected\n');

    // Navigate
    console.log('Navigating...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Get snapshot
    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = snapshotResponse.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    // Parse dashboards
    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const parseResult = JSON.parse(parseResponse.content[0].text);
    const dashboard = parseResult.dashboards[0];
    console.log(`Target dashboard: ${dashboard.name}\n`);

    // Parse snapshot line by line
    const lines = snapshot.split('\n');

    console.log('Looking for the armprod row and its Additional options button...\n');
    console.log('='.repeat(70));

    let inArmprodRow = false;
    let rowStartLine = -1;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Find the start of armprod row
      if (line.includes('- row') && line.includes('armprod')) {
        inArmprodRow = true;
        rowStartLine = i;
        console.log(`\nFound armprod row at line ${i}:`);
        console.log('─'.repeat(70));
      }

      // If we're in the armprod row section
      if (inArmprodRow) {
        console.log(line);

        // Look for Additional options button within this row
        if (line.includes('Additional options') && line.includes('[ref=')) {
          const match = line.match(/\[ref=([^\]]+)\]/);
          if (match) {
            const ref = match[1];
            console.log('');
            console.log('🎯 FOUND IT! ');
            console.log(`   Line ${i}: ${line.trim()}`);
            console.log(`   Ref: ${ref}`);
            console.log('');

            // Try clicking this specific button
            console.log(`Attempting to click button with ref=${ref}...`);
            try {
              const clickResponse = await playwrightClient.callTool({
                name: 'browser_click',
                arguments: {
                  element: 'Additional options',
                  description: 'Click Additional options button for armprod dashboard',
                  ref: ref
                }
              });

              console.log('✅ Click successful!\n');

              // Wait and get menu
              await sleep(2000);

              const menuSnapshot = await playwrightClient.callTool({
                name: 'browser_snapshot',
                arguments: {}
              });

              let menuSnap = menuSnapshot.content[0].text;
              if (menuSnap.includes('```yaml')) {
                menuSnap = menuSnap.split('```yaml\n')[1].split('\n```')[0];
              }

              console.log('📋 Menu Contents:');
              console.log('─'.repeat(70));

              // Look for menu or popover
              const menuLines = menuSnap.split('\n');
              for (let j = 0; j < menuLines.length; j++) {
                const menuLine = menuLines[j];

                if (menuLine.includes('menu [') ||
                    menuLine.includes('popover') ||
                    menuLine.includes('menuitem')) {

                  // Print this and next 20 lines
                  for (let k = j; k < Math.min(j + 25, menuLines.length); k++) {
                    console.log(menuLines[k]);

                    // Stop at end of menu
                    if (k > j && menuLines[k].trim().startsWith('- ') &&
                        !menuLines[k].includes('menuitem') &&
                        !menuLines[k].includes('text:')) {
                      break;
                    }
                  }
                  break;
                }
              }

              console.log('─'.repeat(70));

            } catch (error) {
              console.log(`❌ Click failed: ${error.message}`);
            }

            break;
          }
        }

        // Stop when we hit the next row
        if (i > rowStartLine + 2 && line.trim().startsWith('- row')) {
          console.log('');
          console.log('(End of armprod row section)');
          inArmprodRow = false;
          break;
        }
      }
    }

    console.log('='.repeat(70));
    console.log('');

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
  }
}

findDashboardButton()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
