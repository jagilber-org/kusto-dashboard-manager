#!/usr/bin/env node

/**
 * Kusto Dashboard Manager - MCP Client
 *
 * Production client that orchestrates browser automation via Playwright MCP server.
 * Currently focused on testing Playwright MCP integration.
 * Future: Will add Kusto Dashboard Manager MCP for dashboard parsing.
 *
 * Usage:
 *   node dashboard-client.js [dashboard-url]
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'child_process';
import { readFileSync, existsSync, writeFileSync, mkdirSync, readdirSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Dashboard Client - Orchestrates MCP servers for dashboard operations
 */
class DashboardClient {
  constructor(configPath = null, debug = false, parseSnapshot = false, exportDashboards = false, jsonOutput = false) {
    this.playwrightClient = null;
    this.playwrightTransport = null;
    this.kustoClient = null;
    this.kustoTransport = null;
    this.configPath = configPath;
    this.debug = debug || process.env.DEBUG === '1';
    this.parseSnapshot = parseSnapshot;
    this.exportDashboards = exportDashboards;
    this.jsonOutput = jsonOutput;
  }

  log(emoji, message) {
    if (!this.jsonOutput) {
      console.log(`${emoji} ${message}`);
    }
  }

  debugLog(message) {
    if (this.debug && !this.jsonOutput) {
      console.log(`🔍 DEBUG: ${message}`);
    }
  }

  /**
   * Load MCP configuration from VS Code settings
   */
  loadConfig() {
    const defaultConfigPath = 'C:\\Users\\jagilber\\AppData\\Roaming\\Code - Insiders\\User\\mcp.json';
    const envPath = join(__dirname, '../.env');

    // Read .env if exists
    if (!this.configPath && existsSync(envPath)) {
      try {
        const envContent = readFileSync(envPath, 'utf8');
        const match = envContent.match(/MCP_CONFIG_PATH=(.+)/);
        if (match) {
          this.configPath = match[1].trim();
        }
      } catch (err) {
        this.debugLog(`Could not read .env: ${err.message}`);
      }
    }

    // Use default if not set
    if (!this.configPath) {
      this.configPath = defaultConfigPath;
    }

    // Try to load MCP config
    if (existsSync(this.configPath)) {
      try {
        const configContent = readFileSync(this.configPath, 'utf8');
        const config = JSON.parse(configContent);

        // Find Playwright server config
        const serversObj = config.mcpServers || config.servers || {};
        const playwrightKey = Object.keys(serversObj).find(k => k.toLowerCase() === 'playwright');

        if (playwrightKey) {
          this.playwrightConfig = serversObj[playwrightKey];
          this.debugLog(`Found Playwright config in ${this.configPath}`);
          return true;
        }
      } catch (err) {
        this.debugLog(`Could not load config: ${err.message}`);
      }
    }

    // Fallback: spawn npx @playwright/mcp
    this.debugLog('No config found, will spawn npx @playwright/mcp');
    return false;
  }

  /**
   * Connect to Playwright MCP server
   */
  async connectPlaywright() {
    this.log('🎭', 'Connecting to Playwright MCP server...');

    this.loadConfig();

    // Create client
    this.playwrightClient = new Client({
      name: 'kusto-dashboard-client',
      version: '1.0.0'
    }, {
      capabilities: {}
    });

    // Setup transport - let MCP SDK handle spawning
    if (this.playwrightConfig) {
      // Use configured server
      const { command, args = [], env = {} } = this.playwrightConfig;
      this.debugLog(`Spawning: ${command} ${args.join(' ')}`);

      this.playwrightTransport = new StdioClientTransport({
        command,
        args,
        env: { ...process.env, ...env }
      });
    } else {
      // Fallback to npx
      this.debugLog('Spawning: npx @playwright/mcp');
      this.playwrightTransport = new StdioClientTransport({
        command: 'npx',
        args: ['@playwright/mcp']
      });
    }

    await this.playwrightClient.connect(this.playwrightTransport);

    // List available tools
    const toolsList = await this.playwrightClient.listTools();
    this.debugLog(`Available tools: ${toolsList.tools.map(t => t.name).join(', ')}`);

    this.log('✅', 'Connected to Playwright MCP');
  }

  /**
   * Connect to Kusto Dashboard Manager MCP server
   */
  async connectKusto() {
    this.log('📊', 'Connecting to Kusto Dashboard Manager MCP server...');

    // Create client
    this.kustoClient = new Client({
      name: 'kusto-dashboard-client',
      version: '1.0.0'
    }, {
      capabilities: {}
    });

    // Setup transport - spawn Python MCP server
    const serverPath = join(__dirname, '../src/mcp_server.py');
    this.debugLog(`Spawning: python ${serverPath}`);

    this.kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [serverPath]
    });

    await this.kustoClient.connect(this.kustoTransport);
    this.log('✅', 'Connected to Kusto Dashboard Manager MCP');
  }  /**
   * Navigate to URL and take accessibility snapshot
   */
  async getPageSnapshot(url, waitSeconds = 8) {
    this.log('🌐', `Navigating to: ${url}`);

    // Log trace directory if configured and store for later
    if (this.playwrightConfig && this.playwrightConfig.args) {
      const outputDirArg = this.playwrightConfig.args.find(arg => arg.startsWith('--output-dir='));
      if (outputDirArg) {
        this.traceDir = outputDirArg.split('=')[1];
        this.log('📁', `Trace directory: ${this.traceDir}`);
      }
    }

    // Store timestamp for finding trace file later
    this.sessionTimestamp = Date.now();

    // Navigate
    await this.playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url }
    });

    // Wait for page load
    this.log('⏳', `Waiting ${waitSeconds} seconds for page load...`);
    await new Promise(resolve => setTimeout(resolve, waitSeconds * 1000));

    // Take snapshot
    this.log('📸', 'Taking accessibility snapshot...');
    const snapshotResponse = await this.playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    // Extract snapshot
    let snapshot = null;
    if (snapshotResponse.content && snapshotResponse.content.length > 0) {
      snapshot = snapshotResponse.content[0].text;
    }

    if (!snapshot) {
      throw new Error('Failed to get snapshot from Playwright');
    }

    this.log('✅', `Got snapshot (${snapshot.length} chars)`);
    return snapshot;
  }

  /**
   * Parse snapshot using Kusto Dashboard Manager MCP
   */
  async parseDashboards(snapshot, creatorFilter = 'Jason Gilbertson') {
    if (!this.parseSnapshot) {
      this.debugLog('Snapshot parsing disabled');
      return null;
    }

    this.log('🔍', 'Parsing dashboards from snapshot...');

    const parseResponse = await this.kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: creatorFilter
      }
    });

    // Extract result
    if (parseResponse.content && parseResponse.content.length > 0) {
      const resultText = parseResponse.content[0].text;
      const result = JSON.parse(resultText);
      return result;
    }

    return null;
  }

  /**
   * Export a single dashboard by navigating and extracting JSON via API
   *
   * METHOD: Direct Dashboard URL Navigation + API Call
   * - NOT using ellipsis menu on list page
   * - Navigating directly to individual dashboard URL
   * - Executing JavaScript to call Kusto API
   * - Extracting JSON response and saving to file
   */
  async exportDashboard(dashboard, outputDir) {
    this.log('📋', `Exporting: ${dashboard.name}`);

    try {
      // Extract dashboard ID from URL
      const dashboardId = dashboard.url.split('/').pop();
      const apiUrl = `https://dashboards.kusto.windows.net/dashboards/${dashboardId}`;

      // Navigate to the dashboard page
      await this.playwrightClient.callTool({
        name: 'browser_navigate',
        arguments: { url: dashboard.url }
      });

      // Wait for page to load
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Execute JavaScript to fetch dashboard JSON from API
      const script = `
        (async () => {
          try {
            console.log('[DASHBOARD-EXPORT] Fetching from API:', '${apiUrl}');
            const response = await fetch('${apiUrl}');
            console.log('[DASHBOARD-EXPORT] Response status:', response.status, response.statusText);

            if (!response.ok) {
              throw new Error(\`API request failed: \${response.status} \${response.statusText}\`);
            }

            const data = await response.json();
            console.log('[DASHBOARD-EXPORT] Got data for dashboard:', data.name || 'unknown');
            console.log('[DASHBOARD-EXPORT] Data size:', JSON.stringify(data).length, 'bytes');

            return JSON.stringify(data);
          } catch (error) {
            console.error('[DASHBOARD-EXPORT] ERROR:', error.message);
            return JSON.stringify({ error: error.message });
          }
        })()
      `;

      const evalResponse = await this.playwrightClient.callTool({
        name: 'browser_evaluate',
        arguments: { script: script }
      });

      if (!this.jsonOutput) {
        console.log(`   ✅ JavaScript executed`);
        console.log(`\n📥 STEP 4: Parse API response`);
      }

      // Extract result - Playwright returns markdown-formatted response
      let dashboardData = null;
      if (evalResponse.content && evalResponse.content.length > 0) {
        const resultText = evalResponse.content[0].text;

        if (!this.jsonOutput) {
          console.log(`   Response length: ${resultText.length} bytes`);
          console.log(`   First 300 chars of response:`);
          console.log(`   ${resultText.substring(0, 300)}`);
        }

        this.debugLog(`Raw eval response: ${resultText.substring(0, 500)}`);

        // Try to parse the response - could be JSON or markdown-wrapped
        try {
          if (!this.jsonOutput) {
            console.log(`   Attempting to parse as direct JSON...`);
          }
          // First try: parse as JSON directly
          const evalResult = JSON.parse(resultText);
          if (evalResult.result) {
            if (!this.jsonOutput) {
              console.log(`   ✅ Found 'result' field, parsing inner JSON...`);
            }
            dashboardData = JSON.parse(evalResult.result);
          } else if (evalResult.name || evalResult.dashboardId) {
            if (!this.jsonOutput) {
              console.log(`   ✅ Direct dashboard data found`);
            }
            dashboardData = evalResult;
          }
        } catch (e) {
          if (!this.jsonOutput) {
            console.log(`   ⚠️  Direct JSON parse failed: ${e.message}`);
            console.log(`   Trying markdown code block extraction...`);
          }
          // Second try: extract from markdown code block
          const jsonMatch = resultText.match(/```json\n([\s\S]+?)\n```/);
          if (jsonMatch) {
            if (!this.jsonOutput) {
              console.log(`   ✅ Found JSON in markdown code block`);
            }
            dashboardData = JSON.parse(jsonMatch[1]);
          } else {
            if (!this.jsonOutput) {
              console.log(`   Trying to find JSON line in text...`);
            }
            // Third try: look for JSON in plain text
            const lines = resultText.split('\n');
            const jsonLine = lines.find(line => line.trim().startsWith('{'));
            if (jsonLine) {
              if (!this.jsonOutput) {
                console.log(`   ✅ Found JSON line`);
              }
              dashboardData = JSON.parse(jsonLine.trim());
            } else {
              if (!this.jsonOutput) {
                console.log(`   ❌ Could not find JSON in any format`);
              }
            }
          }
        }
      }

      if (!dashboardData || dashboardData.error) {
        const errorMsg = dashboardData?.error || 'Failed to extract dashboard JSON';
        if (!this.jsonOutput) {
          console.log(`   ❌ FAILED: ${errorMsg}`);
        }
        throw new Error(errorMsg);
      }

      if (!this.jsonOutput) {
        console.log(`   ✅ Dashboard data parsed successfully`);
        console.log(`   Dashboard name: ${dashboardData.name || 'N/A'}`);
        console.log(`   Dashboard ID: ${dashboardData.id || dashboardData.dashboardId || 'N/A'}`);
        console.log(`\n💾 STEP 5: Save to file`);
      }

      // Enrich with metadata
      const enrichedData = {
        _metadata: {
          exportedAt: new Date().toISOString(),
          sourceUrl: dashboard.url,
          dashboardId: dashboardId,
          exporterVersion: '1.0.0',
          creator: dashboard.creator
        },
        ...dashboardData
      };

      // Generate output path
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('.')[0];
      const safeName = dashboard.name.replace(/[^a-z0-9-_]/gi, '_');
      const filename = `${safeName}-${timestamp}.json`;
      const outputPath = outputDir ? join(outputDir, filename) : join(process.cwd(), filename);

      if (!this.jsonOutput) {
        console.log(`   Filename: ${filename}`);
        console.log(`   Output path: ${outputPath}`);
        console.log(`   Data size: ${JSON.stringify(enrichedData).length} bytes`);
      }

      // Write to file
      writeFileSync(outputPath, JSON.stringify(enrichedData, null, 2), 'utf8');

      if (!this.jsonOutput) {
        console.log(`   ✅ File written successfully`);
        console.log(`\n✅ EXPORT COMPLETE: ${dashboard.name}`);
        console.log(`   Saved to: ${outputPath}`);
      }

      return {
        success: true,
        name: dashboard.name,
        url: dashboard.url,
        outputPath: outputPath,
        size: JSON.stringify(enrichedData).length
      };

    } catch (error) {
      this.debugLog(`Export failed for ${dashboard.name}: ${error.message}`);
      return {
        success: false,
        name: dashboard.name,
        url: dashboard.url,
        error: error.message
      };
    }
  }

  /**
   * Export all discovered dashboards
   */
  async exportAllDashboards(dashboards, outputDir = null) {
    if (!dashboards || !dashboards.dashboards || dashboards.dashboards.length === 0) {
      this.log('⚠️', 'No dashboards to export');
      return [];
    }

    // Determine output directory
    if (!outputDir) {
      outputDir = process.env.DASHBOARD_OUTPUT_DIR || join(__dirname, '../output/dashboards');
    }

    // Create output directory if it doesn't exist
    if (!existsSync(outputDir)) {
      mkdirSync(outputDir, { recursive: true });
      this.debugLog(`Created output directory: ${outputDir}`);
    }

    // TEST MODE: Only export first dashboard
    const TEST_LIMIT = 1;
    console.log(`\n⚠️  TEST MODE: Only exporting first ${TEST_LIMIT} dashboard for debugging\n`);

    this.log('📦', `Exporting ${TEST_LIMIT} of ${dashboards.dashboards.length} dashboards to: ${outputDir}`);

    const results = [];
    for (let i = 0; i < Math.min(TEST_LIMIT, dashboards.dashboards.length); i++) {
      const dashboard = dashboards.dashboards[i];
      try {
        this.log('⏳', `[${i + 1}/${TEST_LIMIT}] Exporting: ${dashboard.name}`);
        const result = await this.exportDashboard(dashboard, outputDir);
        if (result && result.success) {
          results.push({
            name: dashboard.name,
            url: dashboard.url,
            outputPath: result.outputPath,
            status: 'success'
          });
          this.log('✅', `Exported to: ${result.outputPath}`);
        } else {
          results.push({
            name: dashboard.name,
            url: dashboard.url,
            status: 'failed',
            error: result?.error || 'Unknown error'
          });
          this.log('❌', `Failed: ${dashboard.name}`);
        }
      } catch (error) {
        results.push({
          name: dashboard.name,
          url: dashboard.url,
          status: 'error',
          error: error.message
        });
        this.log('❌', `Error: ${dashboard.name} - ${error.message}`);
      }
    }

    return results;
  }

  /**
   * Close browser and disconnect
   */
  async cleanup() {
    if (this.playwrightClient) {
      try {
        // Close browser
        await this.playwrightClient.callTool({
          name: 'browser_close',
          arguments: {}
        });
      } catch (err) {
        this.debugLog(`Error closing browser: ${err.message}`);
      }

      // Disconnect transport
      if (this.playwrightTransport) {
        await this.playwrightTransport.close();
      }

      this.log('🔌', 'Disconnected from Playwright MCP');
    }

    if (this.kustoClient) {
      // Disconnect transport
      if (this.kustoTransport) {
        await this.kustoTransport.close();
      }

      this.log('🔌', 'Disconnected from Kusto Dashboard Manager MCP');
    }
  }

  /**
   * Main workflow - get dashboard page snapshot
   */
  async run(dashboardUrl = 'https://dataexplorer.azure.com/dashboards', creatorFilter = 'Jason Gilbertson') {
    // Suppress console output in JSON mode
    if (!this.jsonOutput) {
      console.log('🚀 Kusto Dashboard Manager - MCP Client\n');
    }

    try {
      // Connect to Playwright MCP
      await this.connectPlaywright();

      // Connect to Kusto MCP if parsing is enabled
      if (this.parseSnapshot) {
        await this.connectKusto();
      }

      if (!this.jsonOutput) {
        console.log('\n' + '='.repeat(60));
        console.log('📋 Getting Dashboard Page Snapshot');
        console.log('='.repeat(60) + '\n');
      }

      // Get snapshot
      const snapshot = await this.getPageSnapshot(dashboardUrl);

      // Save snapshot to file (skip in JSON mode)
      let snapshotFile = null;
      if (!this.jsonOutput) {
        console.log('\n' + '='.repeat(60));
        console.log('✅ Success');
        console.log('='.repeat(60));
        console.log(`Snapshot captured: ${snapshot.length} characters`);

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const outputDir = join(dirname(fileURLToPath(import.meta.url)), '../output');
        snapshotFile = join(outputDir, `snapshot-${timestamp}.yaml`);

        // Ensure output directory exists
        if (!existsSync(outputDir)) {
          mkdirSync(outputDir, { recursive: true});
        }

        writeFileSync(snapshotFile, snapshot, 'utf8');

        console.log(`\n📄 Snapshot saved to: ${snapshotFile}`);
        console.log('\nSnapshot preview (first 500 chars):');
        console.log('-'.repeat(60));
        console.log(snapshot.substring(0, 500));
        console.log('-'.repeat(60));
      }

      // Parse dashboards if enabled
      let dashboards = null;
      let exportResults = null;

      if (this.parseSnapshot) {
        console.log('\n' + '='.repeat(60));
        console.log('🔍 Parsing Dashboards');
        console.log('='.repeat(60));

        dashboards = await this.parseDashboards(snapshot, creatorFilter);

        if (dashboards) {
          // JSON output mode - output pure JSON and exit early
          if (this.jsonOutput) {
            // Close connections first to avoid stderr noise
            await this.cleanup();
            // Output pure JSON to stdout
            console.log(JSON.stringify(dashboards, null, 2));
            return { success: true, snapshot, dashboards };
          } else {
            console.log(`\n✅ Found ${dashboards.total_found} dashboards by ${creatorFilter}`);

            if (dashboards.dashboards && dashboards.dashboards.length > 0) {
              console.log('\nDashboards:');
              dashboards.dashboards.slice(0, 5).forEach((d, i) => {
                console.log(`  ${i + 1}. ${d.name}`);
                console.log(`     Creator: ${d.creator}`);
                console.log(`     URL: ${d.url}`);
              });

              if (dashboards.dashboards.length > 5) {
                console.log(`  ... and ${dashboards.dashboards.length - 5} more`);
              }
            }
          }

          // Export dashboards if requested
          if (this.exportDashboards && !this.jsonOutput) {
            console.log('\n' + '='.repeat(60));
            console.log('📦 Exporting Dashboards');
            console.log('='.repeat(60) + '\n');

            exportResults = await this.exportAllDashboards(dashboards);

            // Summary
            const successful = exportResults.filter(r => r.status === 'success').length;
            const failed = exportResults.length - successful;

            console.log('\n' + '='.repeat(60));
            console.log('📊 Export Summary');
            console.log('='.repeat(60));
            console.log(`✅ Successful: ${successful}`);
            if (failed > 0) {
              console.log(`❌ Failed: ${failed}`);
            }
          }
        } else {
          if (!this.jsonOutput) {
            console.log('\n⚠️ No dashboards found');
          }
        }
      }

      // Display quick access links (skip in JSON mode)
      if (!this.jsonOutput) {
        console.log('\n' + '='.repeat(60));
        console.log('📎 Quick Access Links');
        console.log('='.repeat(60));
        console.log(`\n📄 YAML Snapshot (Ctrl+Click to open):`);
        console.log(`   ${snapshotFile}`);

      if (this.traceDir) {
        const traceDir = this.traceDir.replace(/\//g, '\\');
        const tracesSubdir = join(traceDir, 'traces');

        console.log(`\n📁 Traces Directory (Ctrl+Click to open):`);
        console.log(`   ${tracesSubdir}`);

        // Find the most recent trace file
        try {
          const traceFiles = readdirSync(tracesSubdir)
            .filter(f => f.endsWith('.trace'))
            .sort()
            .reverse();

          if (traceFiles.length > 0) {
            const latestTrace = join(tracesSubdir, traceFiles[0]);
            console.log(`\n🔍 View Latest Trace (copy and run):`);
            console.log(`   npx playwright show-trace "${latestTrace}"`);
          }
        } catch (err) {
          console.log(`\n🔍 View Traces:`);
          console.log(`   npx playwright show-trace "${tracesSubdir}\\trace-*.trace"`);
        }
      }
      } // End of quick access links section

      // Show next steps (only if not in JSON mode)
      if (!this.jsonOutput) {
        if (!this.parseSnapshot) {
          console.log('\n💡 Tip: Use --parse flag to extract dashboard information');
          console.log('💡 Tip: Use --json flag to output as JSON');
        } else if (!this.exportDashboards) {
          console.log('\n💡 Tip: Use --export flag to save dashboards as JSON files');
        }
      }

      return { success: true, snapshot, dashboards, exportResults };
    } catch (error) {
      console.error('❌ Error:', error.message);
      if (this.debug) {
        console.error(error.stack);
      }
      return false;
    } finally {
      await this.cleanup();
    }
  }
}

// CLI entry point - always run when executed directly
const isMainModule = process.argv[1] && (
  process.argv[1].endsWith('dashboard-client.js') ||
  process.argv[1].endsWith('dashboard-client')
);

if (isMainModule) {
  const debug = process.argv.includes('--debug') || process.env.DEBUG === '1';
  const parseSnapshot = process.argv.includes('--parse');
  const exportDashboards = process.argv.includes('--export');
  const jsonOutput = process.argv.includes('--json');

  // Validate flags
  if (jsonOutput && !parseSnapshot) {
    console.error('❌ Error: --json requires --parse flag');
    process.exit(1);
  }

  if (exportDashboards && !parseSnapshot) {
    console.error('❌ Error: --export requires --parse flag');
    process.exit(1);
  }

  // Get URL and creator filter from non-flag arguments
  const args = process.argv.slice(2).filter(arg => !arg.startsWith('--'));
  const dashboardUrl = args[0] || 'https://dataexplorer.azure.com/dashboards';
  const creatorFilter = args[1] || 'Jason Gilbertson';

  const client = new DashboardClient(null, debug, parseSnapshot, exportDashboards, jsonOutput);
  client.run(dashboardUrl, creatorFilter)
    .then(result => process.exit(result.success ? 0 : 1))
    .catch(error => {
      console.error('💥 Fatal error:', error);
      if (debug) {
        console.error(error.stack);
      }
      process.exit(1);
    });
}export default DashboardClient;
