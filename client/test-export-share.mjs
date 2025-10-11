#!/usr/bin/env node

/**
 * Export dashboard using the Share button's export functionality
 * This uses the UI elements instead of direct API calls
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

async function exportViaShareButton() {
  console.log('🧪 Testing Dashboard Export via Share Button\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Step 1: Connect to Playwright MCP
    console.log('1️⃣  Connecting to Playwright MCP...');
    playwrightClient = new Client(
      { name: 'export-share', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);
    console.log('    ✅ Connected\n');

    // Step 2: Connect to Kusto MCP
    console.log('2️⃣  Connecting to Kusto Dashboard Manager MCP...');
    kustoClient = new Client(
      { name: 'export-share', version: '1.0.0' },
      { capabilities: {} }
    );
    const serverPath = join(__dirname, '..', 'src', 'mcp_server.py');
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [serverPath]
    });
    await kustoClient.connect(kustoTransport);
    console.log('    ✅ Connected\n');

    // Step 3: Navigate to dashboards page
    console.log('3️⃣  Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('    ✅ Navigated\n');

    // Step 4: Wait for page to load
    console.log('4️⃣  Waiting for page to load (8 seconds)...');
    await sleep(8000);
    console.log('    ✅ Ready\n');

    // Step 5: Take snapshot to get dashboard list
    console.log('5️⃣  Getting dashboard list...');
    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    const responseText = snapshotResponse.content[0].text;
    let snapshot;
    if (responseText.includes('```yaml')) {
      snapshot = responseText.split('```yaml\n')[1].split('\n```')[0];
    } else {
      snapshot = responseText;
    }
    console.log(`    ✅ Got snapshot (${snapshot.length} chars)\n`);

    // Step 6: Parse dashboards
    console.log('6️⃣  Parsing dashboards...');
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
      console.log('❌ No dashboards found. Cannot test export.');
      return;
    }

    // Step 7: Navigate to FIRST dashboard
    const dashboard = parseResult.dashboards[0];
    console.log(`7️⃣  Opening: ${dashboard.name}`);
    console.log(`    Creator: ${dashboard.creator}`);
    console.log(`    URL: ${dashboard.url}\n`);

    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: dashboard.url }
    });

    console.log('    ⏳ Waiting 5 seconds for dashboard to load...');
    await sleep(5000);
    console.log('    ✅ Dashboard loaded\n');

    // Step 8: Take snapshot to see what's on the page
    console.log('8️⃣  Taking snapshot to find Share button...');
    const dashboardSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    const dashSnapshotText = dashboardSnapshot.content[0].text;
    let dashSnapshot;
    if (dashSnapshotText.includes('```yaml')) {
      dashSnapshot = dashSnapshotText.split('```yaml\n')[1].split('\n```')[0];
    } else {
      dashSnapshot = dashSnapshotText;
    }

    console.log(`    ✅ Got snapshot (${dashSnapshot.length} chars)\n`);

    // Look for Share button
    const hasShareButton = dashSnapshot.toLowerCase().includes('share');
    console.log(`    Share button detected: ${hasShareButton ? '✅ YES' : '❌ NO'}\n`);

    // Show relevant parts of snapshot
    console.log('📋 Snapshot preview (looking for buttons/menus):');
    console.log('─'.repeat(60));
    const lines = dashSnapshot.split('\n').slice(0, 50);
    lines.forEach(line => {
      if (line.toLowerCase().includes('button') ||
          line.toLowerCase().includes('share') ||
          line.toLowerCase().includes('export') ||
          line.toLowerCase().includes('menu')) {
        console.log(line);
      }
    });
    console.log('─'.repeat(60));
    console.log('');

    // Step 9: Try to click Share button
    console.log('9️⃣  Attempting to click Share button...');
    try {
      const clickResponse = await playwrightClient.callTool({
        name: 'browser_click',
        arguments: {
          element: 'Share button',
          description: 'Click the Share button to open export options'
        }
      });
      console.log('    ✅ Clicked Share button\n');

      // Wait for menu to appear
      console.log('    ⏳ Waiting for share menu...');
      await sleep(2000);

      // Take another snapshot to see the menu
      console.log('    📸 Taking snapshot of share menu...');
      const menuSnapshot = await playwrightClient.callTool({
        name: 'browser_snapshot',
        arguments: {}
      });

      const menuSnapshotText = menuSnapshot.content[0].text;
      let menuSnap;
      if (menuSnapshotText.includes('```yaml')) {
        menuSnap = menuSnapshotText.split('```yaml\n')[1].split('\n```')[0];
      } else {
        menuSnap = menuSnapshotText;
      }

      console.log(`    ✅ Menu snapshot (${menuSnap.length} chars)\n`);

      console.log('📋 Share menu options:');
      console.log('─'.repeat(60));
      const menuLines = menuSnap.split('\n').slice(0, 100);
      menuLines.forEach(line => {
        if (line.toLowerCase().includes('export') ||
            line.toLowerCase().includes('save') ||
            line.toLowerCase().includes('download') ||
            line.toLowerCase().includes('json') ||
            line.toLowerCase().includes('link') ||
            line.trim().startsWith('- ')) {
          console.log(line);
        }
      });
      console.log('─'.repeat(60));
      console.log('');

      // Look for export/save option
      const hasExport = menuSnap.toLowerCase().includes('export');
      const hasSave = menuSnap.toLowerCase().includes('save');
      const hasDownload = menuSnap.toLowerCase().includes('download');

      console.log('🔍 Export options detected:');
      console.log(`    Export: ${hasExport ? '✅ YES' : '❌ NO'}`);
      console.log(`    Save: ${hasSave ? '✅ YES' : '❌ NO'}`);
      console.log(`    Download: ${hasDownload ? '✅ YES' : '❌ NO'}`);
      console.log('');

    } catch (error) {
      console.log(`    ⚠️  Failed to click Share button: ${error.message}\n`);
      console.log('    The Share button might have a different label or location.');
      console.log('    Check the snapshot above for the correct element name.\n');
    }

    console.log('✅ Test complete! Review the output above to see what UI elements are available.\n');

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    if (error.stack) {
      console.error('Stack:', error.stack);
    }
    throw error;
  } finally {
    console.log('🧹 Cleaning up...');
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
    console.log('    ✅ Done\n');
  }
}

exportViaShareButton()
  .then(() => {
    console.log('🎉 All done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Test failed');
    process.exit(1);
  });
