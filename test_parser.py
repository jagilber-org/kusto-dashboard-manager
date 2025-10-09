"""
Test parsing the raw accessibility snapshot text (not YAML)
"""
import re
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def parse_dashboard_snapshot(snapshot_text: str, required_creator: str):
    """Parse the text-based accessibility snapshot"""
    
    # Pattern to match dashboard rows:
    # - row "dashboard_name ... creator_name" [ref=eXXX]:
    #   - rowheader "dashboard_name" [ref=eXXX]:
    #     - link "dashboard_name" [ref=eXXX] [cursor=pointer]:
    #       - /url: /dashboards/{UUID}
    #   - gridcell "last_accessed" [ref=eXXX]
    #   - gridcell "created_date" [ref=eXXX]
    #   - gridcell "creator_name" [ref=eXXX]
    
    dashboards = []
    lines = snapshot_text.split('\n')
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Look for row lines (dashboard entries)
        if '- row "' in line and '[ref=' in line:
            # Extract the row text (contains all info)
            row_match = re.search(r'- row "([^"]+)"', line)
            if row_match:
                row_text = row_match.group(1)
                
                # Check if this row mentions the creator
                if required_creator in row_text:
                    # Extract details from subsequent lines
                    dashboard = extract_dashboard_from_lines(lines, i, required_creator)
                    if dashboard:
                        dashboards.append(dashboard)
        
        i += 1
    
    return dashboards


def extract_dashboard_from_lines(lines, start_idx, required_creator):
    """Extract dashboard metadata from lines starting at index"""
    
    name = None
    url = None
    dashboard_id = None
    last_accessed = None
    created_date = None
    created_by = None
    
    found_rowheader = False
    
    # Look ahead in the next ~10 lines for details
    for i in range(start_idx, min(start_idx + 15, len(lines))):
        line = lines[i]
        
        # Track when we hit the rowheader section
        if '- rowheader "' in line:
            found_rowheader = True
            # Extract name from rowheader
            header_match = re.search(r'- rowheader "([^"]+)"', line)
            if header_match:
                name = header_match.group(1)
        
        # Extract name from link (only from rowheader section, before we hit gridcell)
        if '- link "' in line and found_rowheader and name is None:
            link_match = re.search(r'- link "([^"]+)"', line)
            if link_match and link_match.group(1) != 'Edit':
                name = link_match.group(1)
        
        # Extract URL from the first /dashboards/ URL we find
        if '- /url: /dashboards/' in line and url is None:
            url_match = re.search(r'/url: (/dashboards/[a-f0-9\-]{36})', line)
            if url_match:
                url = url_match.group(1)
                # Extract UUID
                id_match = re.search(r'/dashboards/([a-f0-9\-]{36})', url)
                if id_match:
                    dashboard_id = id_match.group(1)
        
        # Once we hit gridcell, we're past the rowheader section
        if '- gridcell' in line:
            found_rowheader = False
        
        # Extract gridcell values (dates and creator)
        if '- gridcell "' in line:
            cell_match = re.search(r'- gridcell "([^"]+)"', line)
            if cell_match:
                value = cell_match.group(1)
                
                # Determine which field based on content
                if 'ago' in value or '/' in value:
                    if not last_accessed:
                        last_accessed = value
                    elif not created_date:
                        created_date = value
                elif value and not created_by and value != '--':
                    # This should be the creator
                    created_by = value
    
    # Validate we got the required fields
    if name and url and dashboard_id and created_by == required_creator:
        return {
            'name': name,
            'url': url,
            'dashboard_id': dashboard_id,
            'created_by': created_by,
            'created_date': created_date or 'Unknown',
            'last_accessed': last_accessed or 'Unknown'
        }
    
    return None


if __name__ == '__main__':
    snapshot_file = Path('docs/snapshots/dashboards-list.yaml')
    
    # Get creator from environment variable
    creator = os.getenv('DASHBOARD_CREATOR_NAME', 'Jason Gilbertson')
    
    print(f"Parsing {snapshot_file} for dashboards by '{creator}'...")
    print(f"(Creator loaded from DASHBOARD_CREATOR_NAME environment variable)\n")
    
    snapshot_text = snapshot_file.read_text(encoding='utf-8')
    dashboards = parse_dashboard_snapshot(snapshot_text, creator)
    
    print(f"\n{'='*70}")
    print(f"✓ Found {len(dashboards)} dashboards created by '{creator}'")
    print(f"{'='*70}\n")
    
    for i, dashboard in enumerate(dashboards, 1):
        print(f"{i}. {dashboard['name']}")
        print(f"   ID:            {dashboard['dashboard_id']}")
        print(f"   URL:           {dashboard['url']}")
        print(f"   Created:       {dashboard['created_date']}")
        print(f"   Last accessed: {dashboard['last_accessed']}")
        print()
