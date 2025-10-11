#!/usr/bin/env node

/**
 * MCP Orchestrator Client
 * Demonstrates how to call multiple MCP servers from a single client
 * This mimics what VS Code Copilot does when orchestrating between servers
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

class MCPOrchestrator {
  constructor() {
    this.playwrightClient = null;
    this.playwrightTransport = null;
    this.kustoClient = null;
    this.kustoTransport = null;
  }

  log(emoji, message) {
    console.log(`${emoji} ${message}`);
  }

  async connectPlaywright() {
    this.log('🎭', 'Connecting to Playwright MCP server...');

    this.playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['@playwright/mcp@latest']
    });

    this.playwrightClient = new Client(
      { name: 'orchestrator-playwright', version: '1.0.0' },
      { capabilities: {} }
    );

    await this.playwrightClient.connect(this.playwrightTransport);
    this.log('✅', 'Connected to Playwright MCP');
  }

  async connectKusto() {
    this.log('📊', 'Connecting to Kusto Dashboard Manager MCP server...');

    const cwd = join(__dirname, '..');

    this.kustoTransport = new StdioClientTransport({
      command: 'python',
      args: ['-m', 'src.mcp_server'],
      cwd: cwd
    });

    this.kustoClient = new Client(
      { name: 'orchestrator-kusto', version: '1.0.0' },
      { capabilities: {} }
    );

    await this.kustoClient.connect(this.kustoTransport);
    this.log('✅', 'Connected to Kusto Dashboard Manager MCP');
  }

  async getDashboardList(creatorFilter = null) {
    this.log('🌐', 'Step 1: Navigate to dashboards page (Playwright)...');

    await this.playwrightClient.callTool({
      name: 'mcp_playwright_browser_navigate',
      arguments: {
        url: 'https://dataexplorer.azure.com/dashboards'
      }
    });

    this.log('⏳', 'Step 2: Wait for page to load...');
    await new Promise(resolve => setTimeout(resolve, 8000));

    this.log('📸', 'Step 3: Take accessibility snapshot (Playwright)...');
    const snapshotResponse = await this.playwrightClient.callTool({
      name: 'mcp_playwright_browser_snapshot',
      arguments: {}
    });

    // Extract snapshot YAML from response
    let snapshotYaml = null;
    if (snapshotResponse.content && snapshotResponse.content.length > 0) {
      // The text field contains the snapshot YAML directly
      snapshotYaml = snapshotResponse.content[0].text;
    }

    if (!snapshotYaml) {
      throw new Error('Failed to get snapshot YAML from Playwright');
    }

    this.log('✅', `Got snapshot (${snapshotYaml.length} chars)`);

    this.log('🔍', 'Step 4: Parse dashboards (Kusto)...');
    const parseResponse = await this.kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshotYaml,
        creatorFilter: creatorFilter
      }
    });

    // Extract result
    if (parseResponse.content && parseResponse.content.length > 0) {
      const resultText = parseResponse.content[0].text;
      const result = JSON.parse(resultText);
      return result;
    }

    throw new Error('Failed to parse dashboards');
  }

  async cleanup() {
    if (this.playwrightClient) {
      await this.playwrightClient.close();
      this.log('🔌', 'Disconnected from Playwright MCP');
    }

    if (this.kustoClient) {
      await this.kustoClient.close();
      this.log('🔌', 'Disconnected from Kusto Dashboard Manager MCP');
    }
  }

  async run() {
    console.log('🚀 MCP Orchestrator - Demonstrating Multi-Server Coordination\n');

    try {
      // Connect to both servers
      await this.connectPlaywright();
      await this.connectKusto();

      console.log('\n' + '='.repeat(60));
      console.log('📋 Getting Dashboard List');
      console.log('='.repeat(60) + '\n');

      // Get dashboards (orchestrating between both servers)
      const result = await this.getDashboardList('Jason Gilbertson');

      console.log('\n' + '='.repeat(60));
      console.log('✅ Results');
      console.log('='.repeat(60));
      console.log(`Found: ${result.total_found} dashboards`);
      console.log(`Dashboards:`);
      result.dashboards.forEach((d, i) => {
        console.log(`  ${i + 1}. ${d.name}`);
        console.log(`     Creator: ${d.creator}`);
        console.log(`     URL: ${d.url}`);
      });

      return true;
    } catch (error) {
      console.error('❌ Error:', error.message);
      return false;
    } finally {
      await this.cleanup();
    }
  }
}

// Run if executed directly
const orchestrator = new MCPOrchestrator();
orchestrator.run()
  .then(success => process.exit(success ? 0 : 1))
  .catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  });

export default MCPOrchestrator;
