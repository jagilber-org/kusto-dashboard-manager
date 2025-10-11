#!/usr/bin/env node
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'child_process';

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  console.log('🔍 Checking for additional dashboards after scrolling\n');

  // Connect to Playwright MCP
  console.log('Connecting to Playwright MCP...');
  const playwrightTransport = new StdioClientTransport({
    command: 'npx',
    args: ['-y', '@playwright/mcp@latest']
  });
  const playwrightClient = new Client({
    name: 'dashboard-scroll-test',
    version: '1.0.0'
  }, { capabilities: {} });
  await playwrightClient.connect(playwrightTransport);

  // Connect to Kusto Dashboard Manager MCP
  console.log('Connecting to Kusto Dashboard Manager MCP...');
  const kustoTransport = new StdioClientTransport({
    command: 'python',
    args: ['../src/mcp_server.py']
  });
  const kustoClient = new Client({
    name: 'dashboard-scroll-test',
    version: '1.0.0'
  }, { capabilities: {} });
  await kustoClient.connect(kustoTransport);

  console.log('✅ Connected\n');

  try {
    // Navigate to dashboards page
    console.log('Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Get initial count
    console.log('📊 Getting initial dashboard count...');
    const initialSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = initialSnapshot.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    const initialParse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const initialResult = JSON.parse(initialParse.content[0].text);
    const initialCount = initialResult.dashboards.length;
    console.log(`   Initial count: ${initialCount} dashboards\n`);

    // Scroll down multiple times to load more
    console.log('⬇️  Scrolling down to load more dashboards...');

    for (let i = 1; i <= 5; i++) {
      console.log(`   Scroll ${i}/5...`);
      await playwrightClient.callTool({
        name: 'browser_evaluate',
        arguments: {
          expression: 'window.scrollTo(0, document.body.scrollHeight)'
        }
      });
      await sleep(2000);
    }

    console.log('✅ Scrolling complete\n');

    // Get updated count
    console.log('📊 Getting updated dashboard count...');
    const afterSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let afterSnapshotText = afterSnapshot.content[0].text;
    if (afterSnapshotText.includes('```yaml')) {
      afterSnapshotText = afterSnapshotText.split('```yaml\n')[1].split('\n```')[0];
    }

    const afterParse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: afterSnapshotText,
        creatorFilter: 'Jason Gilbertson'
      }
    });

    const afterResult = JSON.parse(afterParse.content[0].text);
    const afterCount = afterResult.dashboards.length;
    console.log(`   After scrolling: ${afterCount} dashboards\n`);

    // Show results
    console.log('='.repeat(60));
    if (afterCount > initialCount) {
      console.log(`\n✅ Found ${afterCount - initialCount} additional dashboards after scrolling!`);
      console.log(`   Total: ${afterCount} dashboards\n`);

      // Show the new ones
      const newDashboards = afterResult.dashboards.slice(initialCount);
      console.log('New dashboards found:');
      newDashboards.forEach((d, i) => {
        console.log(`  ${initialCount + i + 1}. ${d.name}`);
      });
    } else {
      console.log(`\n✅ No additional dashboards found after scrolling.`);
      console.log(`   Total remains: ${afterCount} dashboards`);
    }
    console.log('\n' + '='.repeat(60));

  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await playwrightClient.close();
    await kustoClient.close();
  }
}

main().catch(console.error);
