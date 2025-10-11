#!/usr/bin/env node

/**
 * Export dashboard using the ellipsis menu on the dashboard LIST page
 * This should be faster - no need to open each dashboard individually
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

async function exportFromListPage() {
  console.log('🧪 Testing Export from Dashboard List Page (Ellipsis Menu)\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Step 1: Connect to both MCPs
    console.log('1️⃣  Connecting to MCP servers...');
    playwrightClient = new Client(
      { name: 'list-export', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'list-export', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('    ✅ Connected\n');

    // Step 2: Navigate to dashboards list page
    console.log('2️⃣  Navigating to dashboards list...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('    ✅ Navigated\n');

    // Step 3: Wait for page to load
    console.log('3️⃣  Waiting for page to load (8 seconds)...');
    await sleep(8000);
    console.log('    ✅ Ready\n');

    // Step 4: Take snapshot to see the dashboard list
    console.log('4️⃣  Taking snapshot of dashboard list...');
    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = snapshotResponse.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }
    console.log(`    ✅ Got snapshot (${snapshot.length} chars)\n`);

    // Step 5: Parse to get dashboard info
    console.log('5️⃣  Parsing dashboard list...');
    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const parseResult = JSON.parse(parseResponse.content[0].text);
    console.log(`    ✅ Found ${parseResult.total_found} dashboards\n`);

    if (parseResult.total_found === 0) {
      console.log('❌ No dashboards found');
      return;
    }

    // Step 6: Look for ellipsis/menu buttons in the snapshot
    console.log('6️⃣  Looking for ellipsis/menu buttons in list...\n');

    const lines = snapshot.split('\n');
    const dashboardLines = [];

    // Find lines related to dashboards
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Look for button, menuitem, or interactive elements near dashboard names
      if (line.includes('button') ||
          line.includes('menuitem') ||
          line.includes('...') ||
          line.includes('ellipsis') ||
          line.includes('more') ||
          line.includes('options') ||
          line.includes('action')) {

        // Check if this is near a dashboard name
        const contextStart = Math.max(0, i - 5);
        const contextEnd = Math.min(lines.length, i + 5);
        const context = lines.slice(contextStart, contextEnd).join('\n');

        // If it mentions our first dashboard name
        if (context.includes(parseResult.dashboards[0].name)) {
          console.log(`📌 Found potential menu button near "${parseResult.dashboards[0].name}":`);
          console.log('─'.repeat(60));
          for (let j = contextStart; j < contextEnd; j++) {
            if (j === i) {
              console.log(`>>> ${lines[j]}`); // Highlight the button line
            } else {
              console.log(`    ${lines[j]}`);
            }
          }
          console.log('─'.repeat(60));
          console.log('');
        }
      }
    }

    // Step 7: Show all rows to find the pattern
    console.log('7️⃣  Showing dashboard rows structure...\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Find row elements
      if (line.includes('- row') && line.includes(parseResult.dashboards[0].name.substring(0, 10))) {
        console.log(`Found row for ${parseResult.dashboards[0].name}:`);
        console.log('─'.repeat(60));

        // Print this row and next 20 lines
        for (let j = i; j < Math.min(i + 25, lines.length); j++) {
          console.log(lines[j]);

          // Stop if we hit another row
          if (j > i && lines[j].trim().startsWith('- row')) {
            break;
          }
        }
        console.log('─'.repeat(60));
        console.log('');
        break;
      }
    }

    // Step 8: Try to find and click the ellipsis/options button
    console.log('8️⃣  Attempting to click dashboard options menu...\n');

    const dashboard = parseResult.dashboards[0];
    console.log(`    Target: ${dashboard.name}`);

    // Try different descriptions for the button
    const buttonDescriptions = [
      `More options for ${dashboard.name}`,
      `Dashboard options for ${dashboard.name}`,
      `Actions menu for ${dashboard.name}`,
      `Ellipsis button for ${dashboard.name}`,
      'More actions button',
      'Dashboard actions',
      'Options menu'
    ];

    for (const desc of buttonDescriptions) {
      try {
        console.log(`    Trying: "${desc}"...`);

        const clickResponse = await playwrightClient.callTool({
          name: 'browser_click',
          arguments: {
            element: desc,
            description: `Click the ${desc} to see export options`
          }
        });

        console.log(`    ✅ Clicked! Response:`);
        console.log(`       ${JSON.stringify(clickResponse).substring(0, 200)}\n`);

        // Wait for menu to appear
        await sleep(2000);

        // Take snapshot of menu
        console.log('    📸 Taking snapshot of opened menu...');
        const menuSnapshot = await playwrightClient.callTool({
          name: 'browser_snapshot',
          arguments: {}
        });

        let menuSnap = menuSnapshot.content[0].text;
        if (menuSnap.includes('```yaml')) {
          menuSnap = menuSnap.split('```yaml\n')[1].split('\n```')[0];
        }

        console.log(`    ✅ Menu snapshot (${menuSnap.length} chars)\n`);

        // Look for export/save/download options
        console.log('    🔍 Menu options:');
        console.log('    ' + '─'.repeat(56));
        const menuLines = menuSnap.split('\n');
        for (const line of menuLines.slice(0, 100)) {
          if (line.toLowerCase().includes('export') ||
              line.toLowerCase().includes('save') ||
              line.toLowerCase().includes('download') ||
              line.toLowerCase().includes('share') ||
              line.toLowerCase().includes('copy') ||
              line.includes('menuitem')) {
            console.log(`    ${line}`);
          }
        }
        console.log('    ' + '─'.repeat(56));
        console.log('');

        // Success - we found it!
        break;

      } catch (error) {
        console.log(`    ⚠️  Failed: ${error.message.substring(0, 100)}`);
        continue;
      }
    }

    console.log('✅ Test complete!\n');
    console.log('💡 Next steps:');
    console.log('   - If menu opened, look for export/save option above');
    console.log('   - Click that option to get the dashboard JSON');
    console.log('   - This would avoid navigating to each dashboard\n');

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    if (error.stack) {
      console.error('Stack:', error.stack);
    }
  } finally {
    console.log('🧹 Cleaning up...');
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
    console.log('    ✅ Done\n');
  }
}

exportFromListPage()
  .then(() => {
    console.log('🎉 All done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Failed');
    process.exit(1);
  });
