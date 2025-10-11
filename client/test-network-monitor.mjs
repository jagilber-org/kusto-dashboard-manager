#!/usr/bin/env node

/**
 * Monitor network requests during download
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

async function monitorDownload() {
  console.log('🌐 Monitoring network activity during download\n');

  let playwrightClient;
  let playwrightTransport;

  try {
    // Connect
    console.log('Connecting...');
    playwrightClient = new Client(
      { name: 'network-monitor', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);
    console.log('✅ Connected\n');

    // Navigate
    console.log('Navigating...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Click ellipsis
    console.log('Clicking Additional options...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: { element: 'Additional options', ref: 'e204' }
    });
    await sleep(2000);

    // Click Download
    console.log('Clicking Download dashboard to file...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: { element: 'Download dashboard to file', ref: 'e677' }
    });

    // Wait for network activity
    console.log('⏳ Waiting for network activity...');
    await sleep(4000);

    // Get network requests
    console.log('📊 Getting network requests...\n');
    const networkResponse = await playwrightClient.callTool({
      name: 'browser_network_requests',
      arguments: {}
    });

    const networkData = networkResponse.content[0].text;
    console.log('Network requests:');
    console.log('='.repeat(80));
    console.log(networkData);
    console.log('='.repeat(80));

    // Save to file
    writeFileSync(
      join(__dirname, '..', 'output', 'network-requests.txt'),
      networkData
    );
    console.log('\n✅ Saved to output/network-requests.txt');

    // Parse and look for dashboard-related requests
    console.log('\n🔍 Looking for dashboard-related requests...\n');

    if (networkData.includes('dashboard') || networkData.includes('03e8f08f-8111-40f4-9f58-270678db9782')) {
      const lines = networkData.split('\n');
      for (const line of lines) {
        if (line.toLowerCase().includes('dashboard') ||
            line.includes('03e8f08f-8111-40f4-9f58-270678db9782') ||
            line.includes('.json') ||
            line.toLowerCase().includes('download')) {
          console.log(`  ${line}`);
        }
      }
    } else {
      console.log('  No dashboard-related network requests found');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  } finally {
    if (playwrightTransport) await playwrightTransport.close();
  }
}

monitorDownload()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
