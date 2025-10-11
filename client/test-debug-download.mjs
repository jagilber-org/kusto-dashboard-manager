#!/usr/bin/env node

/**
 * Click download and take a screenshot to see what happens
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

async function debugDownload() {
  console.log('🔍 Debug: What happens after clicking Download?\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect
    console.log('Connecting...');
    playwrightClient = new Client(
      { name: 'debug-download', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'debug-download', version: '1.0.0' },
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

    // Take "before" screenshot
    console.log('Taking "before" screenshot...');
    const beforeScreenshot = await playwrightClient.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    const beforeData = beforeScreenshot.content[0].data || beforeScreenshot.content[0].text;
    if (beforeData) {
      writeFileSync(
        join(__dirname, '..', 'output', 'screenshot-before.png'),
        Buffer.from(beforeData, 'base64')
      );
      console.log('✅ Saved to output/screenshot-before.png\n');
    } else {
      console.log('⚠️  Screenshot data not available\n');
    }

    // Click ellipsis
    console.log('Clicking Additional options...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: {
        element: 'Additional options',
        ref: 'e204'
      }
    });
    await sleep(2000);

    // Take screenshot with menu open
    console.log('Taking screenshot with menu...');
    const menuScreenshot = await playwrightClient.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    const menuData = menuScreenshot.content[0].data || menuScreenshot.content[0].text;
    if (menuData) {
      writeFileSync(
        join(__dirname, '..', 'output', 'screenshot-menu.png'),
        Buffer.from(menuData, 'base64')
      );
      console.log('✅ Saved to output/screenshot-menu.png\n');
    }

    // Click Download
    console.log('Clicking Download dashboard to file...');
    await playwrightClient.callTool({
      name: 'browser_click',
      arguments: {
        element: 'Download dashboard to file',
        ref: 'e677'
      }
    });

    // Wait a bit
    await sleep(1000);

    // Take screenshot right after click
    console.log('Taking screenshot immediately after click...');
    const afterScreenshot1 = await playwrightClient.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    const after1Data = afterScreenshot1.content[0].data || afterScreenshot1.content[0].text;
    if (after1Data) {
      writeFileSync(
        join(__dirname, '..', 'output', 'screenshot-after1.png'),
        Buffer.from(after1Data, 'base64')
      );
      console.log('✅ Saved to output/screenshot-after1.png\n');
    }

    // Wait longer
    await sleep(3000);

    // Take screenshot after waiting
    console.log('Taking screenshot after 3 second wait...');
    const afterScreenshot2 = await playwrightClient.callTool({
      name: 'browser_take_screenshot',
      arguments: {}
    });
    const after2Data = afterScreenshot2.content[0].data || afterScreenshot2.content[0].text;
    if (after2Data) {
      writeFileSync(
        join(__dirname, '..', 'output', 'screenshot-after2.png'),
        Buffer.from(after2Data, 'base64')
      );
      console.log('✅ Saved to output/screenshot-after2.png\n');
    }

    // Get detailed snapshot
    console.log('Getting detailed accessibility snapshot...');
    const snapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapText = snapshot.content[0].text;
    if (snapText.includes('```yaml')) {
      snapText = snapText.split('```yaml\n')[1].split('\n```')[0];
    }

    writeFileSync(
      join(__dirname, '..', 'output', 'snapshot-after-download.yaml'),
      snapText
    );
    console.log(`✅ Saved snapshot (${snapText.length} chars) to output/snapshot-after-download.yaml\n`);

    // Look for dialogs, alerts, or JSON content
    console.log('🔍 Searching for dialog/content...\n');
    console.log('='.repeat(80));

    const lines = snapText.split('\n');
    let foundInteresting = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.includes('dialog') ||
          line.includes('alert') ||
          line.includes('modal') ||
          line.includes('textarea') ||
          line.includes('textbox') && line.length > 100 ||
          line.includes('"tiles"') ||
          line.includes('"$schema"')) {

        foundInteresting = true;

        const start = Math.max(0, i - 5);
        const end = Math.min(lines.length, i + 40);

        for (let j = start; j < end; j++) {
          if (j === i) {
            console.log(`>>> ${lines[j]}`);
          } else {
            console.log(`    ${lines[j]}`);
          }
        }

        console.log('─'.repeat(80));
        break;
      }
    }

    if (!foundInteresting) {
      console.log('⚠️  No dialog or JSON content found in snapshot');
      console.log('\nLet me check browser console for errors...');

      // Get console messages
      const consoleMessages = await playwrightClient.callTool({
        name: 'browser_console_messages',
        arguments: {}
      });

      console.log('\n📋 Console messages:');
      console.log(JSON.stringify(consoleMessages.content[0], null, 2));
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

debugDownload()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
