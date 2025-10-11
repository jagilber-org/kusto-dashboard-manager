#!/usr/bin/env node

/**
 * Complete export workflow for all dashboards
 * Clicks ellipsis → Download → Wait for file → Copy to output folder
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function exportAllDashboards() {
  console.log('📥 Exporting all dashboards from list page\n');

  let playwrightClient, kustoClient;
  let playwrightTransport, kustoTransport;

  try {
    // Connect to both MCPs
    console.log('Connecting to MCP servers...');
    playwrightClient = new Client(
      { name: 'export-all', version: '1.0.0' },
      { capabilities: {} }
    );
    playwrightTransport = new StdioClientTransport({
      command: 'npx',
      args: ['-y', '@playwright/mcp@latest']
    });
    await playwrightClient.connect(playwrightTransport);

    kustoClient = new Client(
      { name: 'export-all', version: '1.0.0' },
      { capabilities: {} }
    );
    kustoTransport = new StdioClientTransport({
      command: 'python',
      args: [join(__dirname, '..', 'src', 'mcp_server.py')]
    });
    await kustoClient.connect(kustoTransport);
    console.log('✅ Connected\n');

    // Create output directory
    const outputDir = join(__dirname, '..', 'output', 'dashboards');
    if (!existsSync(outputDir)) {
      mkdirSync(outputDir, { recursive: true });
    }

    // Navigate to dashboards page
    console.log('Navigating to dashboards page...');
    await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
    });
    await sleep(8000);
    console.log('✅ Page loaded\n');

    // Get initial snapshot and parse dashboards
    console.log('Getting dashboard list...');
    const initialSnapshot = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });

    let snapshot = initialSnapshot.content[0].text;
    if (snapshot.includes('```yaml')) {
      snapshot = snapshot.split('```yaml\n')[1].split('\n```')[0];
    }

    const parseResponse = await kustoClient.callTool({
      name: 'parse_dashboards_from_snapshot',
      arguments: {
        snapshot_yaml: snapshot,
        creatorFilter: null  // Get all dashboards (including those with '--' as creator)
      }
    });

    const parseResult = JSON.parse(parseResponse.content[0].text);
    let dashboards = parseResult.dashboards;

    // Filter to only Jason Gilbertson or '--' (old dashboards without creator)
    dashboards = dashboards.filter(d =>
      d.creator === 'Jason Gilbertson' || d.creator === '--'
    );

    console.log(`✅ Found ${dashboards.length} dashboards (Jason Gilbertson + '--' creators)`);
    console.log(`\nFirst dashboard structure:`, JSON.stringify(dashboards[0], null, 2));
    console.log('');

    // TEST MODE: Only process first 3 dashboards
    const TEST_MODE = false;
    const testLimit = TEST_MODE ? 3 : dashboards.length;

    if (TEST_MODE) {
      console.log(`⚠️  TEST MODE: Processing only first ${testLimit} dashboards\n`);
    }

    console.log('='.repeat(80));

    // NOTE: Downloads go to browser's Downloads folder with dashboard ID as filename
    // We'll track them and move them after download completes

    // Export each dashboard
    const exported = [];
    const failed = [];

    for (let i = 0; i < testLimit; i++) {
      const dashboard = dashboards[i];

      // Extract ID from URL
      const idMatch = dashboard.url.match(/dashboards\/([a-f0-9-]+)/);
      const dashboardId = idMatch ? idMatch[1] : null;

      console.log(`\n[${i + 1}/${dashboards.length}] ${dashboard.name}`);
      console.log(`  ID: ${dashboardId}`);
      console.log(`  URL: ${dashboard.url}`);

      try {
        // Get fresh snapshot to find the button for this dashboard
        const currentSnapshot = await playwrightClient.callTool({
          name: 'browser_snapshot',
          arguments: {}
        });

        let snapText = currentSnapshot.content[0].text;
        if (snapText.includes('```yaml')) {
          snapText = snapText.split('```yaml\n')[1].split('\n```')[0];
        }

        // Find the "Additional options" button for this dashboard row
        const lines = snapText.split('\n');
        let buttonRef = null;
        let inDashboardRow = false;
        let rowStartLine = -1;

        for (let j = 0; j < lines.length; j++) {
          const line = lines[j];

          // Find row containing this dashboard - be more specific
          if (line.includes('- row') && line.includes(`"${dashboard.name} `)) {
            inDashboardRow = true;
            rowStartLine = j;
            console.log(`  Found row at line ${j}`);
          }

          // Find Additional options button within this row (must be a button, not menuitem)
          if (inDashboardRow && line.includes('- button "Additional options"') && line.includes('[ref=')) {
            const match = line.match(/\[ref=([^\]]+)\]/);
            if (match) {
              buttonRef = match[1];
              console.log(`  Found button ref at line ${j}: ${buttonRef}`);
              break;
            }
          }

          // Stop at next row
          if (inDashboardRow && j > rowStartLine + 1 && line.trim().startsWith('- row')) {
            break;
          }
        }

        if (!buttonRef) {
          console.log(`  ⚠️  Could not find button ref, skipping...`);
          failed.push({ dashboard: dashboard.name, reason: 'Button not found', id: dashboardId });
          continue;
        }

        if (!dashboardId) {
          console.log(`  ⚠️  Could not extract dashboard ID from URL, skipping...`);
          failed.push({ dashboard: dashboard.name, reason: 'No dashboard ID', id: null });
          continue;
        }

        console.log(`  Found button ref: ${buttonRef}`);

        // Click Additional options
        await playwrightClient.callTool({
          name: 'browser_click',
          arguments: {
            element: 'Additional options',
            ref: buttonRef
          }
        });
        await sleep(1500);

        // Get menu snapshot to find Download button ref
        const menuSnapshot = await playwrightClient.callTool({
          name: 'browser_snapshot',
          arguments: {}
        });

        let menuSnap = menuSnapshot.content[0].text;
        if (menuSnap.includes('```yaml')) {
          menuSnap = menuSnap.split('```yaml\n')[1].split('\n```')[0];
        }

        // Find "Download dashboard to file" ref
        const menuLines = menuSnap.split('\n');
        let downloadRef = null;

        for (const menuLine of menuLines) {
          if (menuLine.includes('Download dashboard to file') && menuLine.includes('[ref=')) {
            const match = menuLine.match(/\[ref=([^\]]+)\]/);
            if (match) {
              downloadRef = match[1];
              break;
            }
          }
        }

        if (!downloadRef) {
          console.log(`  ⚠️  Could not find download button, skipping...`);
          failed.push({ dashboard: dashboard.name, reason: 'Download button not found', id: dashboardId });

          // Click elsewhere to close menu
          await playwrightClient.callTool({
            name: 'browser_click',
            arguments: { element: 'Filter dashboards', description: 'Close menu' }
          });
          await sleep(1000);
          continue;
        }

        console.log(`  Clicking download (ref: ${downloadRef})...`);

        // Click Download
        await playwrightClient.callTool({
          name: 'browser_click',
          arguments: {
            element: 'Download dashboard to file',
            ref: downloadRef
          }
        });

        console.log(`  ✅ Download triggered!`);
        console.log(`  📁 File downloading...`);
        console.log(`     Expected filename: ${dashboardId}`);

        // Wait for download to complete
        console.log(`  ⏳ Waiting for download to complete...`);
        await sleep(4000);

        // Try to find and copy the file while browser is still open
        console.log(`  🔍 Looking for downloaded file...`);

        const { spawn } = await import('child_process');

        // Convert dashboard name to filename-safe format (replace spaces with dashes)
        const safeFileName = dashboard.name.replace(/\s+/g, '-');
        const targetFile = join(outputDir, `${safeFileName}.json`);

        // PowerShell script to find and copy the file from Chrome's download locations
        const findAndCopyScript = `
          $dashboardId = "${dashboardId}"
          $targetFile = "${targetFile.replace(/\\/g, '\\\\')}"
          $userName = $env:USERNAME

          # Playwright MCP stores downloads in temp folder
          $playwrightOutputPath = "$env:LOCALAPPDATA\\Temp\\playwright-mcp-output"

          $found = $false

          if (Test-Path $playwrightOutputPath) {
            # Find the most recent dashboard-undefined.json file
            $files = Get-ChildItem -Path $playwrightOutputPath -Recurse -Filter "dashboard-undefined.json" -File -ErrorAction SilentlyContinue |
              Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-15) } |
              Sort-Object LastWriteTime -Descending

            if ($files) {
              $file = $files | Select-Object -First 1

              # Read the JSON to verify it's the right dashboard
              $jsonContent = Get-Content $file.FullName -Raw
              $json = $jsonContent | ConvertFrom-Json

              if ($json.id -eq $dashboardId) {
                Write-Host "    ✅ Found correct dashboard!"
                Write-Host "       File: $($file.FullName)"
                Write-Host "       Title: $($json.title)"
                Write-Host "       Size: $($file.Length) bytes"

                # Pretty-print JSON with proper formatting
                $prettyJson = $json | ConvertTo-Json -Depth 100
                $prettyJson | Set-Content -Path $targetFile -Encoding UTF8

                Write-Host "       ✅ Copied to: $targetFile"
                $found = $true
              } else {
                Write-Host "    ⚠️  Found file but ID mismatch: $($json.id)"
              }
            }
          }

          if (-not $found) {
            Write-Host "    ⚠️  File not found in any download location"
          }
        `.trim();

        await new Promise((resolve) => {
          const ps = spawn('pwsh.exe', ['-NoProfile', '-Command', findAndCopyScript], {
            stdio: 'inherit'
          });
          ps.on('close', resolve);
        });

        exported.push({
          name: dashboard.name,
          id: dashboardId,
          filename: dashboardId,
          targetFile: targetFile
        });

        // Wait before next dashboard
        await sleep(1000);

      } catch (error) {
        console.log(`  ❌ Error: ${error.message}`);
        failed.push({ dashboard: dashboard.name, reason: error.message, id: dashboardId });
      }
    }

    // Summary
    console.log('\n' + '='.repeat(80));
    console.log('\n📊 EXPORT SUMMARY');
    console.log(`✅ Exported: ${exported.length}`);
    console.log(`❌ Failed: ${failed.length}`);

    if (exported.length > 0) {
      console.log('\n✅ Successfully exported:');
      for (const item of exported) {
        console.log(`  - ${item.name} → ${item.filename}`);
      }
    }

    if (failed.length > 0) {
      console.log('\n❌ Failed exports:');
      for (const item of failed) {
        console.log(`  - ${item.dashboard}: ${item.reason}`);
      }
    }

    console.log('\n📁 Files downloaded to browser Downloads folder');
    console.log('   (They have dashboard ID as filename, no .json extension)');

    // Post-process: Move files from Downloads to output/dashboards/
    if (exported.length > 0) {
      console.log('\n� Post-processing: Moving files from Downloads...\n');

      const { spawn } = await import('child_process');

      for (const item of exported) {
        const downloadedFile = `C:\\Users\\jagilber\\Downloads\\${item.id}`;
        const targetFile = join(outputDir, `${item.name}.json`);

        console.log(`  Moving ${item.id} → ${item.name}.json`);

        // Use PowerShell to move and rename
        const psScript = `
          $source = "${downloadedFile}"
          $target = "${targetFile.replace(/\\/g, '\\\\')}"

          if (Test-Path $source) {
            Move-Item -Path $source -Destination $target -Force
            Write-Host "    ✅ Moved successfully"
          } else {
            Write-Host "    ⚠️  File not found in Downloads (may have been auto-deleted)"

            # Try to find it with wildcards (in case of partial match)
            $found = Get-ChildItem "C:\\Users\\jagilber\\Downloads" -Filter "*${item.id}*" -ErrorAction SilentlyContinue
            if ($found) {
              Move-Item -Path $found.FullName -Destination $target -Force
              Write-Host "    ✅ Found and moved: $($found.Name)"
            }
          }
        `.trim();

        await new Promise((resolve) => {
          const ps = spawn('pwsh.exe', ['-NoProfile', '-Command', psScript], {
            stdio: 'inherit'
          });
          ps.on('close', resolve);
        });
      }

      console.log('\n✅ Post-processing complete!');
      console.log(`📁 Files saved to: ${outputDir}`);
    }

  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    console.error(error.stack);
  } finally {
    if (playwrightTransport) await playwrightTransport.close();
    if (kustoTransport) await kustoTransport.close();
  }
}

exportAllDashboards()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
