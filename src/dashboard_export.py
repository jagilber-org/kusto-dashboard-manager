"""Dashboard Export Module"""

import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from browser_manager import BrowserManager
from tracer import (
    trace_browser_action,
    trace_error,
    trace_func_entry,
    trace_func_exit,
    trace_info,
    trace_parse,
)
from utils import (
    ensure_directory,
    get_logger,
    print_error,
    print_info,
    print_success,
    validate_dashboard_url,
    write_json_file,
)


class DashboardExporter:
    def __init__(self, mcp_client, config):
        self.mcp_client = mcp_client
        self.config = config
        self.browser = BrowserManager(mcp_client, config)
        self.logger = get_logger()

    def _get_dashboard_id(self, url):
        return url.split("/")[-1].split("?")[0]

    def _get_output_path(self, output_path, dashboard_name):
        if output_path:
            return output_path
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        safe_name = dashboard_name.replace(" ", "-").replace("/", "-")
        filename = f"{safe_name}-{timestamp}.json"
        exports_dir = self.config.get("exports_directory", "exports")
        ensure_directory(exports_dir)
        return str(Path(exports_dir) / filename)

    async def _extract_dashboard_json(self):
        """
        Extract dashboard JSON from the Kusto Dashboard API.

        The dashboard data is NOT embedded in HTML/JavaScript - it's fetched via API.
        We make a fetch() call from the browser context to leverage existing authentication.

        API Pattern: https://dashboards.kusto.windows.net/dashboards/{dashboard-id}
        """
        dashboard_id = self._get_dashboard_id(self.browser.current_url)
        if not dashboard_id:
            raise Exception("Could not extract dashboard ID from URL")

        api_url = f"https://dashboards.kusto.windows.net/dashboards/{dashboard_id}"
        self.logger.info(f"Fetching dashboard JSON from API: {api_url}")

        # Use fetch() in browser context to leverage existing authentication
        script = f"""
        (async () => {{
            const response = await fetch('{api_url}');
            if (!response.ok) {{
                throw new Error(`API request failed: ${{response.status}} ${{response.statusText}}`);
            }}
            const data = await response.json();
            return data;
        }})()
        """

        try:
            result = await self.browser.execute_script(script)
            if not result or not isinstance(result, dict):
                raise Exception(f"API returned invalid data type: {type(result)}")

            # Validate essential fields
            if "name" not in result and "tiles" not in result:
                raise Exception("API response missing required fields (name or tiles)")

            self.logger.info("Successfully extracted dashboard JSON via API")
            return result

        except Exception as e:
            self.logger.error(f"Failed to extract dashboard JSON from API: {e}")
            raise Exception(f"Failed to extract dashboard JSON from API: {e}")

    def _enrich_dashboard_data(self, dashboard_data, url):
        return {
            "_metadata": {
                "exportedAt": datetime.utcnow().isoformat(),
                "sourceUrl": url,
                "dashboardId": self._get_dashboard_id(url),
                "exporterVersion": "1.0.0",
            },
            **dashboard_data,
        }

    async def export_dashboard(self, url, output_path=None):
        trace_func_entry("export_dashboard", url=url, output_path=output_path)

        if not validate_dashboard_url(url):
            trace_error("Invalid dashboard URL", url=url)
            raise ValueError(f"Invalid dashboard URL: {url}")

        self.logger.info(f"Exporting dashboard: {url}")
        print_info(f"Exporting from {url}")

        try:
            trace_browser_action("launch")
            await self.browser.launch()
            trace_browser_action("navigate", {"url": url})
            await self.browser.navigate(url)
            await asyncio.sleep(3)  # Wait for page load

            trace_info("Extracting dashboard JSON")
            dashboard_data = await self._extract_dashboard_json()
            enriched_data = self._enrich_dashboard_data(dashboard_data, url)

            dashboard_name = enriched_data.get("name", "dashboard")
            final_path = self._get_output_path(output_path, dashboard_name)

            trace_info("Writing dashboard JSON", path=final_path)
            write_json_file(final_path, enriched_data, indent=2)

            self.logger.info(f"Exported to {final_path}")
            print_success(f"Exported to: {final_path}")
            trace_func_exit("export_dashboard", result=final_path)
            return final_path
        except Exception as e:
            trace_func_exit("export_dashboard", error=str(e))
            raise
        finally:
            trace_browser_action("close")
            await self.browser.close()

    async def _get_dashboard_list(self, list_url):
        """
        Navigate to dashboards list page and extract dashboard information.
        Returns list of dashboard objects with url, name, and creator.
        """
        trace_func_entry("_get_dashboard_list", list_url=list_url)
        self.logger.info(f"Loading dashboard list from: {list_url}")

        trace_browser_action("navigate", {"url": list_url})
        await self.browser.navigate(list_url)

        # Wait for page to load
        trace_info("Waiting 8 seconds for dashboards to load")
        await asyncio.sleep(8)  # Give time for dashboards to load

        # Take accessibility snapshot to parse dashboard list
        trace_browser_action("snapshot")
        print_info("Taking snapshot of dashboard list...")
        snapshot_result = await self.browser.snapshot()
        print_info(
            f"Snapshot result type: {type(snapshot_result)}, has content: {bool(snapshot_result)}"
        )

        # Save snapshot to file for debugging
        snapshot_file = "dashboard_list_snapshot.json"
        with open(snapshot_file, "w", encoding="utf-8") as f:
            json.dump(
                snapshot_result if snapshot_result else {"error": "No result"},
                f,
                indent=2,
            )
        trace_info("Snapshot saved", file=snapshot_file)
        self.logger.info(f"Snapshot saved to {snapshot_file}")
        print_info(f"Snapshot saved to {snapshot_file}")

        if not snapshot_result:
            trace_error("Failed to capture page snapshot")
            print_error("Snapshot returned empty/None")
            raise Exception("Failed to capture page snapshot - no result returned")

        # The snapshot comes as a dict with a "raw" field containing text with embedded YAML
        # We need to parse the raw text to extract dashboard URLs and creators
        if isinstance(snapshot_result, dict) and "raw" in snapshot_result:
            raw_text = snapshot_result["raw"]
            trace_info("Got raw snapshot text", length=len(raw_text))
            self.logger.info(f"Got raw snapshot text, length: {len(raw_text)}")
        else:
            trace_error(
                "Unexpected snapshot format", format_type=type(snapshot_result).__name__
            )
            self.logger.error(
                f"Unexpected snapshot format: {snapshot_result.keys() if isinstance(snapshot_result, dict) else type(snapshot_result)}"
            )
            raise Exception("Snapshot format not recognized")

        # Parse the raw text for dashboard URLs and creators
        dashboards = []
        trace_parse("snapshot_text", input_size=len(raw_text))
        self._parse_raw_snapshot_text(raw_text, dashboards)
        trace_parse(
            "snapshot_text",
            output_count=len(dashboards),
            details=f"Found {len(dashboards)} dashboards",
        )

        self.logger.info(f"Found {len(dashboards)} dashboards in list")
        trace_func_exit("_get_dashboard_list", result=f"{len(dashboards)} dashboards")
        return dashboards

    def _parse_raw_snapshot_text(self, raw_text: str, dashboards: list):
        """
        Parse raw accessibility snapshot text to extract dashboard information.

        ⚠️ IMPORTANT: This is NOT standard YAML! It's a custom format from Playwright's
        accessibility snapshot API. Uses regex pattern matching, not YAML parsing.

        Expected format from @playwright/mcp browser_snapshot tool:

        - row "Dashboard Name time_description MM/DD/YYYY Creator Name" [ref=
          - /url: /dashboards/{guid}
          - rowheader "Dashboard Name"

        Example:
        - row "armprod about 1 hour ago 10/10/2025 Jason Gilbertson" [ref=
          - /url: /dashboards/12345678-1234-1234-1234-123456789abc
          - rowheader "armprod"

        Parsing logic:
        1. Find row line with pattern: `row "text" [ref=`
        2. Extract row_text containing: name + time + date + creator
        3. Look ahead max 10 lines for:
           - /url: /dashboards/{guid} -> extracts dashboard URL
           - rowheader "name" -> extracts clean dashboard name
        4. Extract creator by finding date pattern (MM/DD/YYYY) in row_text
           and taking all text after it
        5. Build dashboard dict with: url, name, creator

        Format details:
        - Row text format: "{name} {relative_time} {MM/DD/YYYY} {creator_full_name}"
        - URL format: /url: /dashboards/{8-4-4-4-12 hex GUID}
        - Rowheader format: rowheader "{clean_dashboard_name}"
        """
        import re

        trace_func_entry("_parse_raw_snapshot_text", text_length=len(raw_text))

        # Split into lines for easier parsing
        lines = raw_text.split("\n")
        trace_info("Parsing snapshot lines", line_count=len(lines))

        i = 0
        while i < len(lines):
            line = lines[i]

            # Look for row entries
            row_match = re.match(r'\s*-\s*row\s+"([^"]+)"\s+\[ref=', line)
            if row_match:
                row_text = row_match.group(
                    1
                )  # e.g., "armprod about 1 hour ago 11/3/2020 Jason Gilbertson"
                trace_parse("row_found", details=f"Row text: {row_text[:100]}")

                # Look ahead for the URL (should be within next 10 lines)
                url = None
                name = None
                for j in range(i + 1, min(i + 10, len(lines))):
                    # Look for rowheader to get clean name
                    name_match = re.search(r'rowheader\s+"([^"]+)"', lines[j])
                    if name_match and not name:
                        name = name_match.group(1)
                        trace_parse("name_extracted", details=name)

                    # Look for URL
                    url_match = re.search(r"/url:\s+/dashboards/([a-f0-9-]+)", lines[j])
                    if url_match:
                        dashboard_id = url_match.group(1)
                        url = (
                            f"https://dataexplorer.azure.com/dashboards/{dashboard_id}"
                        )
                        trace_parse("url_extracted", details=url)
                        # Don't break - continue looking for rowheader

                    # Break if we have both
                    if url and name:
                        break

                if url and name:
                    # Extract creator from row_text
                    # Format: "name time_ago date creator"
                    # The creator is everything after the date (MM/DD/YYYY)
                    parts = row_text.split()
                    creator = ""
                    for k, part in enumerate(parts):
                        if re.match(r"\d{1,2}/\d{1,2}/\d{4}", part):
                            # Found date, creator is everything after
                            creator = " ".join(parts[k + 1 :])
                            trace_parse("creator_extracted", details=creator)
                            break

                    if not creator:
                        creator = "--"
                        trace_parse("creator_missing", details="Using default '--'")

                    dashboards.append(
                        {"url": url, "name": name, "creator": creator.strip()}
                    )
                    trace_info("Dashboard parsed", name=name, creator=creator, url=url)
                    self.logger.debug(f"Found dashboard: {name} by {creator}")

            i += 1

        self.logger.info(f"Parsed {len(dashboards)} dashboards from snapshot")
        trace_func_exit(
            "_parse_raw_snapshot_text", result=f"{len(dashboards)} dashboards"
        )

    def _parse_dashboard_nodes(self, node, dashboards, current_dashboard=None):
        """
        Recursively parse accessibility tree to find dashboard entries.
        Looks for patterns like:
        - Links with dashboard URLs
        - Text nodes with creator names
        - Dashboard titles
        """
        if isinstance(node, dict):
            role = node.get("role", "")
            name = node.get("name", "")

            # Look for dashboard links
            if role == "link" and "dashboards/" in name:
                # Extract URL from name or attributes
                url = None
                if name.startswith("https://"):
                    url = name
                elif "/dashboards/" in name:
                    url = f"https://dataexplorer.azure.com{name}"

                if url:
                    current_dashboard = {"url": url, "name": "", "creator": ""}
                    dashboards.append(current_dashboard)

            # Look for text nodes that might contain creator info
            if (
                role == "text"
                and current_dashboard
                and not current_dashboard.get("creator")
            ):
                # Check if this text looks like a creator name
                if any(
                    indicator in name.lower()
                    for indicator in ["by ", "created by", "@"]
                ):
                    current_dashboard["creator"] = (
                        name.replace("by ", "").replace("created by ", "").strip()
                    )

            # Process children
            children = node.get("children", [])
            for child in children:
                self._parse_dashboard_nodes(child, dashboards, current_dashboard)

        elif isinstance(node, list):
            for item in node:
                self._parse_dashboard_nodes(item, dashboards, current_dashboard)

    async def export_all_dashboards(
        self, list_url="https://dataexplorer.azure.com/dashboards", creator_filter=None
    ):
        """
        Export all dashboards from the list page, optionally filtered by creator.

        Args:
            list_url: URL of the dashboards list page
            creator_filter: Optional creator name to filter (e.g., "Jason Gilbertson")

        Returns:
            Dictionary with export results
        """
        trace_func_entry(
            "export_all_dashboards", list_url=list_url, creator_filter=creator_filter
        )

        if creator_filter is None:
            creator_filter = self.config.data.get("DASHBOARD_CREATOR_NAME", "")

        trace_info("Bulk export starting", creator_filter=creator_filter)
        self.logger.info(f"Starting bulk export for creator: {creator_filter}")
        print_info(f"Starting bulk export for creator: {creator_filter}")

        results = {
            "total_found": 0,
            "filtered": 0,
            "exported": 0,
            "failed": 0,
            "dashboards": [],
        }

        try:
            trace_browser_action("launch")
            await self.browser.launch()

            # Get dashboard list
            dashboards = await self._get_dashboard_list(list_url)
            results["total_found"] = len(dashboards)
            trace_info("Dashboard list retrieved", total_found=len(dashboards))

            # Filter by creator if specified
            if creator_filter:
                original_count = len(dashboards)
                dashboards = [
                    d
                    for d in dashboards
                    if creator_filter.lower() in d.get("creator", "").lower()
                ]
                trace_info(
                    "Filtered dashboards",
                    original=original_count,
                    filtered=len(dashboards),
                    creator=creator_filter,
                )
                self.logger.info(
                    f"Filtered to {len(dashboards)} dashboards by creator: {creator_filter}"
                )

            results["filtered"] = len(dashboards)
            print_info(f"Found {results['filtered']} dashboards to export")

            # Export each dashboard
            for i, dashboard in enumerate(dashboards, 1):
                url = dashboard["url"]
                trace_info(
                    f"Exporting dashboard {i}/{results['filtered']}",
                    url=url,
                    name=dashboard.get("name"),
                )
                print_info(f"[{i}/{results['filtered']}] Exporting: {url}")

                try:
                    trace_browser_action("navigate", {"url": url})
                    await self.browser.navigate(url)
                    await asyncio.sleep(3)

                    trace_info("Extracting dashboard data")
                    dashboard_data = await self._extract_dashboard_json()
                    enriched_data = self._enrich_dashboard_data(dashboard_data, url)

                    dashboard_name = enriched_data.get("name", f"dashboard-{i}")
                    output_path = self._get_output_path(None, dashboard_name)

                    trace_info("Writing dashboard file", path=output_path)
                    write_json_file(output_path, enriched_data, indent=2)

                    results["exported"] += 1
                    results["dashboards"].append(
                        {"url": url, "output_path": output_path, "status": "success"}
                    )
                    trace_info("Dashboard exported successfully", path=output_path)
                    print_success(f"  -> Exported to: {output_path}")

                except Exception as e:
                    trace_error("Dashboard export failed", url=url, error=str(e))
                    self.logger.error(f"Failed to export {url}: {e}")
                    results["failed"] += 1
                    results["dashboards"].append(
                        {"url": url, "status": "failed", "error": str(e)}
                    )
                    print_error(f"  -> Failed: {e}")

            # Summary
            trace_info(
                "Bulk export complete",
                exported=results["exported"],
                failed=results["failed"],
            )
            print_success(f"\nBulk export complete:")
            print_info(f"  Total found: {results['total_found']}")
            print_info(f"  Filtered (yours): {results['filtered']}")
            print_success(f"  Exported: {results['exported']}")
            if results["failed"] > 0:
                print_error(f"  Failed: {results['failed']}")

            trace_func_exit(
                "export_all_dashboards",
                result=f"{results['exported']} exported, {results['failed']} failed",
            )
            return results

        except Exception as e:
            trace_func_exit("export_all_dashboards", error=str(e))
            raise
        finally:
            trace_browser_action("close")
            await self.browser.close()
