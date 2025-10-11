#!/usr/bin/env node

/**
 * Debug script - Check what snapshot we're getting
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function debugSnapshot() {
  console.log('🔍 Debug: Checking snapshot content\n');

  let playwrightClient, playwrightTransport;

  try {
    // Connect to Playwright MCP
    console.log('Connecting to Playwright MCP...');
    playwrightClient = new Client(
      { name: 'debug-test', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);
    console.log('✅ Connected\n');

    // Navigate to dashboards page
    console.log('Navigating to: https://dataexplorer.azure.com/dashboards');
    await playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('✅ Navigated\n');

    // Try different wait times
    for (const waitTime of [5, 10, 15]) {
      console.log(`\n${'='.repeat(60)}`);
      console.log(`Waiting ${waitTime} seconds...`);
      await sleep(waitTime * 1000);

      console.log('Taking snapshot...');
      const snapshotResponse = await playwrightClient.callTool({
        name: 'mcp_playwright_browser_snapshot',
        arguments: {}
      });

      const responseText = snapshotResponse.content[0].text;
      console.log(`Response length: ${responseText.length} chars`);
      console.log(`First 500 chars:`);
      console.log(responseText.substring(0, 500));
      console.log(`\nLast 200 chars:`);
      console.log(responseText.substring(Math.max(0, responseText.length - 200)));

      // Save to file for inspection
      const filename = `snapshot-wait-${waitTime}s.txt`;
      const outputPath = join(__dirname, '..', 'output', filename);
      writeFileSync(outputPath, responseText, 'utf8');
      console.log(`\n💾 Saved to: ${filename}`);
    }

    // Also try taking a screenshot
    console.log(`\n${'='.repeat(60)}`);
    console.log('Taking screenshot for visual inspection...');
    const screenshotResponse = await playwrightClient.callTool({
      name: 'mcp_playwright_browser_take_screenshot',
      arguments: {}
    });
    console.log('✅ Screenshot taken');
    console.log('Response:', JSON.stringify(screenshotResponse, null, 2).substring(0, 500));

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
  } finally {
    if (playwrightTransport) await playwrightTransport.close();
  }
}

debugSnapshot()
  .then(() => {
    console.log('\n✅ Debug complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Failed:', error);
    process.exit(1);
  });
