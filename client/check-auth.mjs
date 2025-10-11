#!/usr/bin/env node

/**
 * Check authentication status and allow manual login
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function checkAuth() {
  console.log('🔐 Checking Azure Data Explorer Authentication\n');

  let client, transport;

  try {
    console.log('Connecting to Playwright MCP...');
    client = new Client(
      { name: 'auth-check', version: '1.0.0' },
      { capabilities: {} }
    );
    transport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await client.connect(transport);
    console.log('✅ Connected\n');

    // Navigate to dashboards
    console.log('Navigating to https://dataexplorer.azure.com/dashboards');
    await client.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('✅ Navigated\n');

    // Take a screenshot immediately
    console.log('Taking screenshot #1 (after navigation)...');
    await sleep(2000);
    const screenshot1 = await client.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    console.log('✅ Screenshot saved by Playwright\n');

    // Wait longer and check again
    console.log('⏳ Waiting 30 seconds for login/page load...');
    console.log('   (If you see a login prompt, please log in now)\n');

    for (let i = 30; i > 0; i -= 5) {
      console.log(`   ${i} seconds remaining...`);
      await sleep(5000);
    }

    console.log('\nTaking screenshot #2 (after wait)...');
    const screenshot2 = await client.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    console.log('✅ Screenshot saved\n');

    // Try to get page content/snapshot
    console.log('Getting accessibility snapshot...');
    const snapshot = await client.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    const snapshotText = snapshot.content[0].text;
    let snapshotYaml;
    if (snapshotText.includes('```yaml')) {
      snapshotYaml = snapshotText.split('```yaml\n')[1].split('\n```')[0];
    } else {
      snapshotYaml = snapshotText;
    }

    console.log(`✅ Snapshot: ${snapshotYaml.length} chars\n`);

    // Check for common authentication indicators
    const hasLoginButton = snapshotYaml.toLowerCase().includes('sign in') ||
                          snapshotYaml.toLowerCase().includes('log in');
    const hasDashboards = snapshotYaml.includes('row') && snapshotYaml.includes('rowheader');

    console.log('📊 Authentication Status:');
    console.log(`   Login button detected: ${hasLoginButton ? '❌ YES (not logged in)' : '✅ NO'}`);
    console.log(`   Dashboards detected: ${hasDashboards ? '✅ YES' : '❌ NO'}`);
    console.log('');

    if (hasDashboards) {
      console.log('✅ SUCCESS! You appear to be authenticated.');
      console.log('   The export script should work now.\n');
    } else {
      console.log('⚠️  No dashboards detected.');
      console.log('   You may need to:');
      console.log('   1. Log in to Azure Data Explorer manually');
      console.log('   2. Run this script again');
      console.log('   3. Or use a browser profile that\'s already logged in\n');
    }

    // Show first 1000 chars of snapshot
    console.log('Snapshot preview (first 1000 chars):');
    console.log('─'.repeat(60));
    console.log(snapshotYaml.substring(0, 1000));
    console.log('─'.repeat(60));

  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    console.log('\nClosing browser (waiting 5 seconds for you to see it)...');
    await sleep(5000);
    if (transport) await transport.close();
    console.log('✅ Done\n');
  }
}

checkAuth()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Failed:', error);
    process.exit(1);
  });
