#!/usr/bin/env node
/**
 * Minimal test script to export ONE dashboard
 * Run standalone: node test-export-one.js
 */

const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const { writeFileSync, mkdirSync } = require('fs');
const { join } = require('path');

async function testExportOne() {
  console.log('🚀 Testing single dashboard export...\n');

  let playwrightClient = null;
  let kustoClient = null;

  try {
    // Connect to Playwright MCP
    console.log('📌 Connecting to Playwright MCP...');
    playwrightClient = new Client({ name: 'test-export', version: '1.0.0' }, { capabilities: {} });
    const playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);
    console.log('✅ Playwright MCP connected\n');

    // Connect to Kusto MCP
    console.log('📌 Connecting to Kusto MCP...');
    kustoClient = new Client({ name: 'test-export', version: '1.0.0' }, { capabilities: {} });
    const kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '../src/mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('✅ Kusto MCP connected\n');

    // Navigate to dashboards page
    console.log('📌 Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    console.log('✅ Navigated\n');

    // Wait
    console.log('⏳ Waiting 8 seconds...');
    await new Promise(resolve => setTimeout(resolve, 8000));

    // Get snapshot
    console.log('📌 Taking snapshot...');
    const snapshotResponse = await playwrightClient.callTool({
      name: 'mcp_playwright_browser_snapshot',
      arguments: {}
    });
    const snapshot = snapshotResponse.content[0].text.split('```yaml\n')[1].split('\n```')[0];
    console.log(`✅ Got snapshot: ${snapshot.length} chars\n`);

    // Parse dashboards
    console.log('📌 Parsing dashboards...');
    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: { snapshot_yaml: snapshot, creatorFilter: 'Jason Gilbertson' }
    });
    const dashboards = JSON.parse(parseResponse.content[0].text);
    console.log(`✅ Found ${dashboards.total_found} dashboards\n`);

    // Export first dashboard
    const dashboard = dashboards.dashboards[0];
    console.log(`📌 Exporting: ${dashboard.name}`);
    console.log(`   URL: ${dashboard.url}\n`);

    // Navigate to dashboard
    console.log('📌 Navigating to dashboard...');
    await playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: { url: dashboard.url }
    });
    await new Promise(resolve => setTimeout(resolve, 3000));
    console.log('✅ Navigated\n');

    // Call API
    const dashboardId = dashboard.url.split('/').pop();
    const apiUrl = `https://dashboards.kusto.windows.net/dashboards/${dashboardId}`;
    console.log(`📌 Calling API: ${apiUrl}`);

    const script = `
      (async () => {
        const response = await fetch('${apiUrl}');
        if (!response.ok) throw new Error('API failed: ' + response.status);
        const data = await response.json();
        return JSON.stringify(data);
      })()
    `;

    const evalResponse = await playwrightClient.callTool({
      name: 'mcp_playwright_browser_evaluate',
      arguments: { script: script }
    });

    console.log('📌 Eval response:');
    console.log(JSON.stringify(evalResponse, null, 2));

    // Parse result
    const resultText = evalResponse.content[0].text;
    let dashboardData = null;

    // Try direct JSON parse
    try {
      dashboardData = JSON.parse(resultText);
    } catch (e) {
      // Try extracting from markdown
      const jsonMatch = resultText.match(/```json\n([\s\S]+?)\n```/);
      if (jsonMatch) {
        dashboardData = JSON.parse(jsonMatch[1]);
      } else {
        const lines = resultText.split('\n');
        const jsonLine = lines.find(line => line.trim().startsWith('{'));
        if (jsonLine) {
          dashboardData = JSON.parse(jsonLine.trim());
        }
      }
    }

    if (!dashboardData) {
      throw new Error('Failed to parse dashboard data from response');
    }

    // Save to file
    const outputDir = join(__dirname, '../output/dashboards');
    mkdirSync(outputDir, { recursive: true });
    const filename = `${dashboard.name.replace(/[^a-z0-9-_]/gi, '_')}-test.json`;
    const outputPath = join(outputDir, filename);

    const enrichedData = {
      _metadata: {
        exportedAt: new Date().toISOString(),
        sourceUrl: dashboard.url,
        dashboardId: dashboardId,
        creator: dashboard.creator
      },
      ...dashboardData
    };

    writeFileSync(outputPath, JSON.stringify(enrichedData, null, 2), 'utf8');
    console.log(`\n✅ SUCCESS! Exported to: ${outputPath}`);
    console.log(`   Size: ${JSON.stringify(enrichedData).length} bytes`);

  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    if (playwrightClient) await playwrightClient.close();
    if (kustoClient) await kustoClient.close();
  }
}

testExportOne();
