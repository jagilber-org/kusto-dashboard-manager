#!/usr/bin/env node

/**
 * Simple dashboard export test - ES Module version
 * Tests exporting ONE dashboard to verify the workflow
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

async function testExport() {
  console.log('🧪 Testing Dashboard Export\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Step 1: Connect to Playwright MCP
    console.log('1️⃣  Connecting to Playwright MCP...');
    playwrightClient = new Client(
      { name: 'export-test', version: '1.0.0' },
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
      { name: 'export-test', version: '1.0.0' },
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

    // Step 5: Take snapshot
    console.log('5️⃣  Taking accessibility snapshot...');
    const snapshotResponse = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    // Extract YAML from markdown response
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

    // Step 7: Export FIRST dashboard
    const dashboard = parseResult.dashboards[0];
    console.log(`7️⃣  Exporting: ${dashboard.name}`);
    console.log(`    Creator: ${dashboard.creator}`);
    console.log(`    URL: ${dashboard.url}\n`);

    // Navigate to dashboard
    console.log('    → Navigating to dashboard...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: dashboard.url }
    });
    await sleep(3000);
    console.log('    ✅ Loaded\n');

    // Call Kusto API to get dashboard JSON
    const dashboardId = dashboard.url.split('/').pop();
    const apiUrl = `https://dashboards.kusto.windows.net/dashboards/${dashboardId}`;
    console.log(`    → Calling API: ${apiUrl}`);

    const jsFunction = `async () => {
      try {
        console.log('[EXPORT] Calling API...');
        const response = await fetch('${apiUrl}');
        console.log('[EXPORT] Response status:', response.status);

        if (!response.ok) {
          throw new Error(\`API failed: \${response.status} \${response.statusText}\`);
        }

        const data = await response.json();
        console.log('[EXPORT] Got data for:', data.name || 'unknown');
        return JSON.stringify(data);
      } catch (error) {
        console.error('[EXPORT] Error:', error.message);
        throw error;
      }
    }`;

    const evalResponse = await playwrightClient.callTool({
      name: 'browser_evaluate',
      arguments: { function: jsFunction }
    });

    console.log('    ✅ API called\n');

    // Step 8: Parse response
    console.log('8️⃣  Parsing response...');
    const resultText = evalResponse.content[0].text;
    let dashboardData = null;

    console.log(`    Response preview: ${resultText.substring(0, 200)}...`);

    // Try multiple parsing strategies
    try {
      // Strategy 1: Direct JSON parse
      dashboardData = JSON.parse(resultText);
      console.log('    ✅ Parsed as direct JSON');

      // If it has a 'result' field, that's the actual data
      if (dashboardData.result) {
        dashboardData = JSON.parse(dashboardData.result);
        console.log('    ✅ Extracted from result field');
      }
    } catch (e) {
      console.log(`    ⚠️  Direct parse failed: ${e.message}`);

      // Strategy 2: Extract from markdown "### Result" section
      if (resultText.includes('### Result')) {
        console.log('    Trying markdown result extraction...');
        const resultLines = resultText.split('\n').slice(1); // Skip "### Result" header
        const jsonText = resultLines.join('\n').trim();
        try {
          dashboardData = JSON.parse(jsonText);
          console.log('    ✅ Parsed from markdown result section');
        } catch (e2) {
          console.log(`    ⚠️  Markdown result parse failed: ${e2.message}`);
        }
      }

      // Strategy 3: Extract from markdown code block
      if (!dashboardData) {
        const jsonMatch = resultText.match(/```json\n([\s\S]+?)\n```/);
        if (jsonMatch) {
          dashboardData = JSON.parse(jsonMatch[1]);
          console.log('    ✅ Extracted from markdown code block');
        }
      }

      // Strategy 4: Find JSON line
      if (!dashboardData) {
        const lines = resultText.split('\n');
        const jsonLine = lines.find(line => line.trim().startsWith('{'));
        if (jsonLine) {
          // Try to find all JSON lines (might span multiple lines)
          const jsonStartIdx = lines.findIndex(line => line.trim().startsWith('{'));
          const jsonLines = lines.slice(jsonStartIdx);
          dashboardData = JSON.parse(jsonLines.join('\n'));
          console.log('    ✅ Found and parsed JSON from lines');
        }
      }
    }

    if (!dashboardData) {
      console.log('❌ Failed to parse dashboard data');
      console.log('Response text:', resultText.substring(0, 500));
      throw new Error('Could not parse dashboard data');
    }
    console.log('    ✅ Dashboard data parsed\n');

    // Step 9: Save to file
    console.log('9️⃣  Saving to file...');
    const outputDir = join(__dirname, '..', 'output', 'dashboards');
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
        creator: dashboard.creator,
        exportMethod: 'API'
      },
      ...dashboardData
    };

    writeFileSync(outputPath, JSON.stringify(enrichedData, null, 2), 'utf8');

    console.log(`    ✅ Saved successfully!`);
    console.log(`    📄 File: ${filename}`);
    console.log(`    📁 Path: ${outputPath}`);
    console.log(`    📊 Size: ${JSON.stringify(enrichedData).length} bytes\n`);

    console.log('✅ EXPORT TEST COMPLETED SUCCESSFULLY!\n');
    return outputPath;

  } catch (error) {
    console.error('\n❌ Export test failed:', error.message);
    if (error.stack) {
      console.error('Stack:', error.stack);
    }
    throw error;
  } finally {
    // Cleanup
    console.log('🧹 Cleaning up...');
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
    console.log('    ✅ Done\n');
  }
}

// Run the test
testExport()
  .then(() => {
    console.log('🎉 All done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Test failed');
    process.exit(1);
  });
