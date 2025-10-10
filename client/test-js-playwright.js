#!/usr/bin/env node

/**
 * Test JavaScript MCP Client against Playwright MCP Server
 * Tests connectivity, tool discovery, and basic browser automation
 * 
 * Configuration:
 * - Uses MCP_CONFIG_PATH from .env (defaults to VS Code Insiders global mcp.json)
 * - Falls back to spawning npx @playwright/mcp if config not found
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

class PlaywrightMCPTest {
  constructor(configPath = null, debug = false) {
    this.client = null;
    this.transport = null;
    this.serverProcess = null;
    this.configPath = configPath;
    this.serverConfig = null;
    this.debug = debug || process.env.DEBUG === '1';
    this.results = {
      passed: [],
      failed: [],
      skipped: []
    };
  }

  log(emoji, message) {
    console.log(`${emoji} ${message}`);
  }

  debugLog(message) {
    if (this.debug) {
      console.log(`🔍 DEBUG: ${message}`);
    }
  }

  loadConfig() {
    // Try to load from .env or use default
    const defaultConfigPath = 'C:\\Users\\jagilber\\AppData\\Roaming\\Code - Insiders\\User\\mcp.json';
    const envPath = join(__dirname, '../../.env');
    
    // Read .env if exists
    if (!this.configPath && existsSync(envPath)) {
      try {
        const envContent = readFileSync(envPath, 'utf8');
        const match = envContent.match(/MCP_CONFIG_PATH=(.+)/);
        if (match) {
          this.configPath = match[1].trim();
          this.log('�', `Config path from .env: ${this.configPath}`);
        }
      } catch (err) {
        this.log('⚠️', `Could not read .env: ${err.message}`);
      }
    }

    // Use default if not set
    if (!this.configPath) {
      this.configPath = defaultConfigPath;
      this.log('📁', `Using default config path: ${this.configPath}`);
    }

    // Try to load MCP config
    if (existsSync(this.configPath)) {
      try {
        const configContent = readFileSync(this.configPath, 'utf8');
        const config = JSON.parse(configContent);
        
        // Find Playwright server config (check both mcpServers and servers, case-insensitive)
        const serversObj = config.mcpServers || config.servers || {};
        const playwrightKey = Object.keys(serversObj).find(k => k.toLowerCase() === 'playwright');
        
        if (playwrightKey) {
          this.serverConfig = serversObj[playwrightKey];
          this.log('✅', `Loaded Playwright config from: ${this.configPath}`);
          this.log('📋', `Command: ${this.serverConfig.command} ${this.serverConfig.args?.join(' ') || ''}`);
          return true;
        } else {
          this.log('⚠️', 'No "playwright" or "Playwright" server found in config');
        }
      } catch (err) {
        this.log('⚠️', `Could not parse config: ${err.message}`);
      }
    } else {
      this.log('⚠️', `Config file not found: ${this.configPath}`);
    }

    // Fallback to default npx command
    this.log('📋', 'Using fallback: npx @playwright/mcp --headless');
    return false;
  }

  async connect() {
    try {
      this.log('🔌', 'Connecting to Playwright MCP server...');
      
      // Load configuration
      this.loadConfig();
      
      // Determine command and args
      const isWindows = process.platform === 'win32';
      let command, args;
      
      if (this.serverConfig) {
        // Use config from mcp.json
        command = this.serverConfig.command;
        args = this.serverConfig.args || [];
        
        // Windows npx wrapper
        if (isWindows && command === 'npx') {
          command = 'cmd';
          args = ['/c', 'npx', ...args];
        }
      } else {
        // Fallback to default
        command = isWindows ? 'cmd' : 'npx';
        args = isWindows 
          ? ['/c', 'npx', '--yes', '@playwright/mcp', '--headless']
          : ['--yes', '@playwright/mcp', '--headless'];
      }
      
      this.log('🚀', `Spawning: ${command} ${args.join(' ')}`);
      
      // Create transport - let the SDK handle spawning
      this.debugLog('Creating StdioClientTransport with command/args...');
      try {
        this.transport = new StdioClientTransport({
          command: command,
          args: args
        });
        this.debugLog('Transport created successfully');
      } catch (transportError) {
        this.debugLog(`Transport creation failed: ${transportError.message}`);
        throw transportError;
      }

      this.debugLog('Creating Client...');
      this.client = new Client(
        { name: 'js-playwright-test-client', version: '1.0.0' },
        { capabilities: {} }
      );
      this.debugLog('Client created');

      // Connect to the server
      this.debugLog('Connecting client to transport...');
      try {
        await this.client.connect(this.transport);
        this.debugLog('Client.connect() completed successfully');
      } catch (connectError) {
        this.debugLog(`Connect error: ${connectError.message}`);
        if (this.debug) {
          this.debugLog(`Stack trace: ${connectError.stack}`);
        }
        throw connectError;
      }
      
      this.log('✅', 'Connected to Playwright MCP server successfully');
      this.results.passed.push('Connection');
      return true;
    } catch (error) {
      this.log('❌', `Failed to connect: ${error.message}`);
      this.results.failed.push({ test: 'Connection', error: error.message });
      return false;
    }
  }

  async listTools() {
    try {
      this.log('📋', 'Listing available tools...');
      
      this.debugLog('Sending tools/list request...');
      const response = await this.client.listTools();
      this.debugLog(`Received response with ${response.tools?.length || 0} tools`);

      this.log('✅', `Found ${response.tools.length} tools:`);
      response.tools.forEach((tool, index) => {
        console.log(`  ${index + 1}. ${tool.name}`);
        if (tool.description) {
          console.log(`     ${tool.description.substring(0, 80)}${tool.description.length > 80 ? '...' : ''}`);
        }
      });

      this.results.passed.push(`Tool Discovery (${response.tools.length} tools)`);
      return response.tools;
    } catch (error) {
      this.log('❌', `Failed to list tools: ${error.message}`);
      this.results.failed.push({ test: 'Tool Discovery', error: error.message });
      return [];
    }
  }

  async testNavigate() {
    try {
      this.log('🌐', 'Testing browser navigation...');
      
      this.debugLog('Calling mcp_playwright_browser_navigate with url: https://example.com');
      const response = await this.client.callTool({
        name: 'mcp_playwright_browser_navigate',
        arguments: { url: 'https://example.com' }
      });
      this.debugLog(`Navigate response: ${JSON.stringify(response).substring(0, 100)}...`);

      if (response.content && response.content.length > 0) {
        this.log('✅', 'Navigation successful');
        this.results.passed.push('Browser Navigation');
        return true;
      } else {
        throw new Error('No response content');
      }
    } catch (error) {
      this.log('❌', `Navigation failed: ${error.message}`);
      this.results.failed.push({ test: 'Browser Navigation', error: error.message });
      return false;
    }
  }

  async testSnapshot() {
    try {
      this.log('📸', 'Testing page snapshot...');
      
      const response = await this.client.callTool({
        name: 'mcp_playwright_browser_snapshot',
        arguments: {}
      });

      if (response.content && response.content.length > 0) {
        const snapshotText = response.content[0].text || '';
        this.log('✅', `Snapshot captured (${snapshotText.length} chars)`);
        this.results.passed.push('Page Snapshot');
        return true;
      } else {
        throw new Error('No snapshot content');
      }
    } catch (error) {
      this.log('❌', `Snapshot failed: ${error.message}`);
      this.results.failed.push({ test: 'Page Snapshot', error: error.message });
      return false;
    }
  }

  async testScreenshot() {
    try {
      this.log('📷', 'Testing screenshot capture...');
      
      const response = await this.client.callTool({
        name: 'mcp_playwright_browser_take_screenshot',
        arguments: {}
      });

      if (response.content && response.content.length > 0) {
        this.log('✅', 'Screenshot captured');
        this.results.passed.push('Screenshot');
        return true;
      } else {
        throw new Error('No screenshot content');
      }
    } catch (error) {
      this.log('❌', `Screenshot failed: ${error.message}`);
      this.results.failed.push({ test: 'Screenshot', error: error.message });
      return false;
    }
  }

  async testClick() {
    try {
      this.log('🖱️', 'Testing click interaction...');
      
      // First navigate to a known page
      await this.testNavigate();
      
      const response = await this.client.callTool({
        name: 'mcp_playwright_browser_click',
        arguments: { selector: 'h1' }
      });

      if (response.content && response.content.length > 0) {
        this.log('✅', 'Click action successful');
        this.results.passed.push('Click Interaction');
        return true;
      } else {
        throw new Error('No click response');
      }
    } catch (error) {
      this.log('❌', `Click failed: ${error.message}`);
      this.results.failed.push({ test: 'Click Interaction', error: error.message });
      return false;
    }
  }

  async disconnect() {
    try {
      if (this.client) {
        await this.client.close();
      }
      if (this.serverProcess) {
        this.serverProcess.kill();
        // Wait for process to exit
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
      this.log('🔌', 'Disconnected from Playwright MCP server');
    } catch (error) {
      this.log('⚠️', `Error during disconnect: ${error.message}`);
    }
  }

  printSummary() {
    console.log('\n' + '='.repeat(60));
    console.log('📊 TEST SUMMARY - JavaScript Client vs Playwright MCP');
    console.log('='.repeat(60));
    
    console.log(`\n✅ PASSED (${this.results.passed.length}):`);
    this.results.passed.forEach(test => console.log(`   - ${test}`));
    
    if (this.results.failed.length > 0) {
      console.log(`\n❌ FAILED (${this.results.failed.length}):`);
      this.results.failed.forEach(({ test, error }) => {
        console.log(`   - ${test}`);
        console.log(`     Error: ${error}`);
      });
    }
    
    if (this.results.skipped.length > 0) {
      console.log(`\n⏭️  SKIPPED (${this.results.skipped.length}):`);
      this.results.skipped.forEach(test => console.log(`   - ${test}`));
    }
    
    const total = this.results.passed.length + this.results.failed.length + this.results.skipped.length;
    const passRate = total > 0 ? ((this.results.passed.length / total) * 100).toFixed(1) : 0;
    
    console.log(`\n📈 Pass Rate: ${passRate}% (${this.results.passed.length}/${total})`);
    console.log('='.repeat(60) + '\n');
    
    return this.results.failed.length === 0;
  }

  async runTests() {
    console.log('🧪 Starting JavaScript Client → Playwright MCP Tests\n');

    // Test 1: Connect
    const connected = await this.connect();
    if (!connected) {
      await this.disconnect();
      this.printSummary();
      return false;
    }

    // Test 2: List tools
    const tools = await this.listTools();
    if (tools.length === 0) {
      await this.disconnect();
      this.printSummary();
      return false;
    }

    // Test 3: Navigate
    await this.testNavigate();

    // Test 4: Snapshot
    await this.testSnapshot();

    // Test 5: Screenshot
    await this.testScreenshot();

    // Test 6: Click (may fail if page changed)
    await this.testClick();

    // Cleanup
    await this.disconnect();

    // Print summary
    return this.printSummary();
  }
}

// Run tests if executed directly
// Note: Use path comparison that works on Windows
const isMainModule = process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'));
if (isMainModule || process.argv[1]?.includes('test-js-playwright.js')) {
  // Check for --debug flag
  const debug = process.argv.includes('--debug') || process.argv.includes('-d');
  const tester = new PlaywrightMCPTest(null, debug);
  
  if (debug) {
    console.log('🐛 Debug mode enabled');
  }
  
  tester.runTests()
    .then(success => process.exit(success ? 0 : 1))
    .catch(error => {
      console.error('💥 Test execution failed:', error);
      process.exit(1);
    });
}

export default PlaywrightMCPTest;
