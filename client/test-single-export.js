#!/usr/bin/env node

/**
 * Minimal test script to export ONE dashboard
 * Tests the export workflow without overwhelming VS Code
 */

const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const { writeFileSync, mkdirSync } = require('fs');
const { join } = require('path');

async function testSingleExport() {
  console.log('🧪 Single Dashboard Export Test\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // 1. Connect to Playwright MCP
    console.log('1️⃣ Connecting to Playwright...');
    playwrightClient = new Client({ name: 'test-client', version: '1.0.0' }, { capabilities: {} });
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);
    console.log('   ✅ Connected\n');

    // 2. Connect to Kusto MCP
    console.log('2️⃣ Connecting to Kusto Dashboard Manager...');
    kustoClient = new Client({ name: 'test-client', version: '1.0.0' }, { capabilities: {} });
    const serverPath = join(__dirname, '../src/mcp_server.py');
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [serverPath]
    });
    await kustoClient.connect(kustoTransport);
    console.log('   ✅ Connected\n');

    // 3. Get dashboard list snapshot
    console.log('3️⃣ Getting dashboard list...');
    await playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await new Promise(resolve => setTimeout(resolve, 8000));
    
    const snapshotResponse = await playwrightClient.callTool({
      name: 'mcp_playwright_browser_snapshot',
      arguments: {}
    });
    const snapshot = snapshotResponse.content[0].text.split('```yaml\n')[1].split('\n```')[0];
    console.log('   ✅ Got snapshot\n');

    // 4. Parse dashboards
    console.log('4️⃣ Parsing dashboards...');
    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: 'Jason Gilbertson'
      }
    });
    const result = JSON.parse(parseResponse.content[0].text);
    console.log(`   ✅ Found ${result.total_found} dashboards\n`);

    // 5. Export FIRST dashboard only
    const dashboard = result.dashboards[0];
    console.log(`5️⃣ Exporting: ${dashboard.name}`);
    console.log(`   URL: ${dashboard.url}\n`);

    // Navigate to dashboard
    await playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: { url: dashboard.url }
    });
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Extract dashboard ID and call API
    const dashboardId = dashboard.url.split('/').pop();
    const apiUrl = `https://dashboards.kusto.windows.net/dashboards/${dashboardId}`;
    
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

    // Parse response
    const resultText = evalResponse.content[0].text;
    let dashboardData;
    
    // Try different parsing methods
    try {
      dashboardData = JSON.parse(resultText);
      if (dashboardData.result) {
        dashboardData = JSON.parse(dashboardData.result);
      }
    } catch (e) {
      // Extract from markdown
      const jsonMatch = resultText.match(/```json\n([\s\S]+?)\n```/);
      if (jsonMatch) {
        dashboardData = JSON.parse(jsonMatch[1]);
      } else {
        const lines = resultText.split('\n');
        const jsonLine = lines.find(line => line.trim().startsWith('{'));
        dashboardData = JSON.parse(jsonLine.trim());
      }
    }

    // Save to file
    const outputDir = join(__dirname, '../output/dashboards');
    mkdirSync(outputDir, { recursive: true });
    
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('.')[0];
    const safeName = dashboard.name.replace(/[^a-z0-9-_]/gi, '_');
    const filename = `${safeName}-${timestamp}.json`;
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
    
    console.log(`   ✅ Exported successfully!`);
    console.log(`   📄 File: ${outputPath}`);
    console.log(`   📊 Size: ${JSON.stringify(enrichedData).length} bytes\n`);

    return outputPath;

  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    // Cleanup
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
  }
}

// Run test
testSingleExport()
  .then(path => {
    console.log('✅ Test completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });
