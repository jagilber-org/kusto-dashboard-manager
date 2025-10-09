"""
Dashboard List Parser - Extract dashboard metadata from Playwright MCP YAML snapshots

CRITICAL SAFETY REQUIREMENT:
All parsing functions MUST filter by creator to ensure only user-created dashboards
are exported/imported. Never process dashboards created by other users.
"""

import re
import yaml
from typing import List, Dict, Optional
from dataclasses import dataclass
from pathlib import Path
from utils import get_logger


@dataclass
class DashboardMetadata:
    """Represents a single dashboard's metadata from the list view"""
    name: str
    url: str
    dashboard_id: str
    created_by: str
    created_date: str
    last_accessed: str
    
    def __post_init__(self):
        """Validation after initialization"""
        if not self.dashboard_id:
            raise ValueError(f"Dashboard '{self.name}' missing dashboard_id")
        if not self.created_by:
            raise ValueError(f"Dashboard '{self.name}' missing created_by field")
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'name': self.name,
            'url': self.url,
            'dashboard_id': self.dashboard_id,
            'created_by': self.created_by,
            'created_date': self.created_date,
            'last_accessed': self.last_accessed
        }


class DashboardListParser:
    """Parse Playwright MCP accessibility tree YAML snapshots for dashboard list"""
    
    # YAML structure pattern from Azure Data Explorer dashboards page:
    # - row "dashboard_name ... creator_name" [ref=eXXX]:
    #   - rowheader "dashboard_name" [ref=eXXX]:
    #     - link "dashboard_name" [ref=eXXX] [cursor=pointer]:
    #       - /url: /dashboards/{UUID}
    #   - gridcell "last_accessed" [ref=eXXX]
    #   - gridcell "created_date" [ref=eXXX]
    #   - gridcell "creator_name" [ref=eXXX]
    
    URL_PATTERN = re.compile(r'/dashboards/([a-f0-9\-]{36})')
    
    def __init__(self, required_creator: str):
        """
        Initialize parser with mandatory creator filtering
        
        Args:
            required_creator: REQUIRED creator name to filter dashboards
                             (e.g., "Jason Gilbertson")
        
        Raises:
            ValueError: If required_creator is empty or None
        """
        if not required_creator or not required_creator.strip():
            raise ValueError(
                "CRITICAL: required_creator must be specified. "
                "Never parse dashboards without creator filtering to prevent "
                "exporting/importing other users' dashboards."
            )
        self.required_creator = required_creator.strip()
        self.logger = get_logger()
    
    def parse_snapshot_yaml(self, yaml_content: str) -> List[DashboardMetadata]:
        """
        Parse YAML accessibility tree snapshot and extract dashboard list
        
        CRITICAL: Only returns dashboards created by self.required_creator
        
        Args:
            yaml_content: Raw YAML string from browser_snapshot
        
        Returns:
            List of DashboardMetadata for dashboards created by required_creator
        
        Raises:
            ValueError: If YAML is invalid or grid structure not found
        """
        try:
            data = yaml.safe_load(yaml_content)
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML content: {e}")
        
        dashboards = []
        
        # Navigate to the grid element containing dashboard rows
        grid = self._find_grid(data)
        if not grid:
            raise ValueError("Could not find grid element in YAML snapshot")
        
        # Find all row elements (skip header row)
        rows = self._find_dashboard_rows(grid)
        
        self.logger.info(f"Found {len(rows)} total dashboard rows in snapshot")
        
        for row_data in rows:
            try:
                dashboard = self._parse_row(row_data)
                if dashboard and dashboard.created_by == self.required_creator:
                    dashboards.append(dashboard)
                    self.logger.debug(f"  ✓ Included: {dashboard.name}")
                elif dashboard:
                    # Log skipped dashboards (but don't include them)
                    self.logger.debug(f"  ✗ Skipped: {dashboard.name} (creator: {dashboard.created_by})")
            except Exception as e:
                # Log but continue processing other rows
                self.logger.warning(f"  Failed to parse row: {e}")
                continue
        
        self.logger.info(f"Filtered to {len(dashboards)} dashboards created by '{self.required_creator}'")
        return dashboards
    
    def _find_grid(self, data: any) -> Optional[dict]:
        """Recursively find the 'grid' element in the YAML tree"""
        if isinstance(data, dict):
            # Check if any key contains 'grid'
            for key, value in data.items():
                if 'grid' in str(key):
                    return value
                result = self._find_grid(value)
                if result:
                    return result
        elif isinstance(data, list):
            for item in data:
                result = self._find_grid(item)
                if result:
                    return result
        return None
    
    def _find_dashboard_rows(self, grid: any) -> List[List]:
        """
        Extract dashboard row elements from grid
        
        Skips header row which contains columnheader elements
        Returns only data rows with dashboard information
        """
        rows = []
        
        def extract_rows(node: any):
            if isinstance(node, dict):
                # Look for row entries
                for key, value in node.items():
                    if 'row' in str(key) and isinstance(value, list):
                        # Check if this row has a rowheader (data row vs header row)
                        has_rowheader = any(
                            isinstance(child, dict) and any('rowheader' in str(k) for k in child.keys())
                            for child in value
                        )
                        if has_rowheader:
                            rows.append(value)
                    else:
                        extract_rows(value)
            
            elif isinstance(node, list):
                for item in node:
                    extract_rows(item)
        
        extract_rows(grid)
        return rows
    
    def _parse_row(self, row_data: List[dict]) -> Optional[DashboardMetadata]:
        """
        Parse a single dashboard row to extract metadata
        
        Expected structure:
        - rowheader "name": contains link with /url: /dashboards/{id}
        - gridcell: last_accessed
        - gridcell: created_date  
        - gridcell: created_by
        - gridcell: actions (buttons)
        """
        name = None
        url = None
        dashboard_id = None
        last_accessed = None
        created_date = None
        created_by = None
        
        gridcell_values = []
        
        for element in row_data:
            if not isinstance(element, dict):
                continue
            
            # Extract name and URL from rowheader > link
            for key, value in element.items():
                if 'rowheader' in str(key):
                    link_data = self._find_link(value)
                    if link_data:
                        name = link_data.get('name')
                        url = link_data.get('url')
                        if url:
                            match = self.URL_PATTERN.search(url)
                            if match:
                                dashboard_id = match.group(1)
                
                # Extract gridcell values (dates and creator)
                elif 'gridcell' in str(key):
                    cell_value = self._extract_text(value)
                    if cell_value and not any(btn in cell_value for btn in ['favorites', 'Edit', 'options']):
                        gridcell_values.append(cell_value)
        
        # Assign gridcell values based on position
        # Expected order: last_accessed, created_date, created_by
        if len(gridcell_values) >= 3:
            last_accessed = gridcell_values[0]
            created_date = gridcell_values[1]
            created_by = gridcell_values[2]
        
        # Validate required fields
        if not all([name, url, dashboard_id, created_by]):
            return None
        
        return DashboardMetadata(
            name=name,
            url=url,
            dashboard_id=dashboard_id,
            created_by=created_by,
            created_date=created_date or 'Unknown',
            last_accessed=last_accessed or 'Unknown'
        )
    
    def _find_link(self, node: any) -> Optional[Dict[str, str]]:
        """Extract link name and URL from node tree"""
        if isinstance(node, dict):
            # Check for link in keys
            for key, value in node.items():
                if 'link' in str(key):
                    # Extract name from key pattern: link "dashboard_name" [ref=eXXX]
                    if '"' in str(key):
                        name = str(key).split('"')[1]
                    else:
                        name = None
                    
                    # Extract URL from value
                    url = None
                    if isinstance(value, list):
                        for child in value:
                            if isinstance(child, dict):
                                for child_key, child_value in child.items():
                                    if '/url' in str(child_key):
                                        url = child_value
                                        break
                    
                    if name and url:
                        return {'name': name, 'url': url}
                
                # Recurse
                result = self._find_link(value)
                if result:
                    return result
        
        elif isinstance(node, list):
            for item in node:
                result = self._find_link(item)
                if result:
                    return result
        
        return None
    
    def _extract_text(self, node: any) -> Optional[str]:
        """Extract text content from a gridcell node"""
        if isinstance(node, str):
            return node.strip()
        
        elif isinstance(node, list):
            # Collect all text from list
            texts = []
            for item in node:
                if isinstance(item, str):
                    texts.append(item.strip())
                elif isinstance(item, dict):
                    # Look for text in dict keys (e.g., gridcell "10 months ago")
                    for key in item.keys():
                        if '"' in str(key):
                            text = str(key).split('"')[1]
                            if text:
                                texts.append(text)
            return ' '.join(texts) if texts else None
        
        elif isinstance(node, dict):
            # Extract from first string key that has quotes
            for key in node.keys():
                if '"' in str(key):
                    text = str(key).split('"')[1]
                    if text:
                        return text
        
        return None
    
    def filter_by_creator(self, dashboards: List[DashboardMetadata]) -> List[DashboardMetadata]:
        """
        Additional safety filter to ensure only required_creator dashboards
        
        This is a redundant safety check since parse_snapshot_yaml already filters.
        Use this for additional validation before export operations.
        
        Args:
            dashboards: List of dashboard metadata
        
        Returns:
            Filtered list containing only dashboards by required_creator
        """
        filtered = [
            d for d in dashboards 
            if d.created_by == self.required_creator
        ]
        
        excluded_count = len(dashboards) - len(filtered)
        if excluded_count > 0:
            self.logger.warning(
                f"Safety filter: Excluded {excluded_count} dashboards "
                f"not created by '{self.required_creator}'"
            )
        
        return filtered
    
    def create_export_manifest(
        self, 
        dashboards: List[DashboardMetadata],
        output_dir: Path
    ) -> Dict:
        """
        Generate manifest JSON for bulk export operation
        
        Args:
            dashboards: List of dashboards to export (must be filtered by creator)
            output_dir: Directory where dashboard files will be saved
        
        Returns:
            Manifest dictionary with metadata
        """
        # Safety check: verify all dashboards are by required_creator
        invalid = [d for d in dashboards if d.created_by != self.required_creator]
        if invalid:
            raise ValueError(
                f"CRITICAL: Cannot create manifest - found {len(invalid)} dashboards "
                f"not created by '{self.required_creator}': "
                f"{[d.name for d in invalid]}"
            )
        
        manifest = {
            'export_metadata': {
                'creator': self.required_creator,
                'total_dashboards': len(dashboards),
                'export_directory': str(output_dir)
            },
            'dashboards': []
        }
        
        for dash in dashboards:
            filename = sanitize_filename(dash.name)
            manifest['dashboards'].append({
                **dash.to_dict(),
                'filename': filename,
                'filepath': str(output_dir / filename)
            })
        
        return manifest
    
    def sanitize_filename(self, dashboard_name: str) -> str:
        """Convert dashboard name to safe filename"""
        return sanitize_filename(dashboard_name)


def sanitize_filename(name: str) -> str:
    """
    Convert dashboard name to safe filename
    
    Args:
        name: Dashboard name (may contain special characters)
    
    Returns:
        Safe filename with extension .json
    """
    # Replace invalid filename characters with underscores
    safe_name = re.sub(r'[<>:"/\\|?*]', '_', name)
    # Replace spaces with underscores
    safe_name = safe_name.replace(' ', '_')
    # Remove multiple consecutive underscores
    safe_name = re.sub(r'_+', '_', safe_name)
    # Trim underscores from ends
    safe_name = safe_name.strip('_')
    # Limit length
    if len(safe_name) > 200:
        safe_name = safe_name[:200]
    
    return f"{safe_name}.json"


# Example usage
if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python dashboard_list_parser.py <yaml_file> <creator_name>")
        print("Example: python dashboard_list_parser.py dashboards-list.yaml 'Jason Gilbertson'")
        sys.exit(1)
    
    yaml_file = Path(sys.argv[1])
    creator = sys.argv[2]
    
    if not yaml_file.exists():
        print(f"Error: File not found: {yaml_file}")
        sys.exit(1)
    
    # Parse with mandatory creator filtering
    parser = DashboardListParser(required_creator=creator)
    
    print(f"\nParsing {yaml_file} for dashboards by '{creator}'...\n")
    yaml_content = yaml_file.read_text(encoding='utf-8')
    
    try:
        dashboards = parser.parse_snapshot_yaml(yaml_content)
        
        print(f"\n{'='*70}")
        print(f"✓ Found {len(dashboards)} dashboards created by '{creator}'")
        print(f"{'='*70}\n")
        
        for i, dashboard in enumerate(dashboards, 1):
            print(f"{i}. {dashboard.name}")
            print(f"   ID:            {dashboard.dashboard_id}")
            print(f"   URL:           {dashboard.url}")
            print(f"   Created:       {dashboard.created_date}")
            print(f"   Last accessed: {dashboard.last_accessed}")
            print(f"   Filename:      {sanitize_filename(dashboard.name)}")
            print()
    
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
