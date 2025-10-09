"""
Environment Configuration Utilities
Load and validate environment variables for dashboard management
"""
import os
from pathlib import Path
from dotenv import load_dotenv
from typing import Optional

# Load .env file from project root
_env_path = Path(__file__).parent.parent / '.env'
load_dotenv(_env_path)


def get_dashboard_creator() -> str:
    """
    Get the dashboard creator name from environment variable
    
    CRITICAL: This determines which dashboards will be exported/imported.
    Only dashboards created by this user will be processed.
    
    Returns:
        Creator name from DASHBOARD_CREATOR_NAME environment variable
    
    Raises:
        ValueError: If DASHBOARD_CREATOR_NAME is not set
    """
    creator = os.getenv('DASHBOARD_CREATOR_NAME')
    
    if not creator or not creator.strip():
        raise ValueError(
            "DASHBOARD_CREATOR_NAME environment variable is not set. "
            "This is required to prevent exporting/importing other users' dashboards. "
            "Please set it in your .env file. Example: DASHBOARD_CREATOR_NAME=Jason Gilbertson"
        )
    
    return creator.strip()


def get_dashboard_output_dir() -> Path:
    """
    Get the output directory for exported dashboards
    
    Returns:
        Path object for dashboard output directory (default: ./output/dashboards)
    """
    output_dir = os.getenv('DASHBOARD_OUTPUT_DIR', './output/dashboards')
    path = Path(output_dir)
    
    # Create directory if it doesn't exist
    path.mkdir(parents=True, exist_ok=True)
    
    return path


def get_dashboard_manifest_file() -> str:
    """
    Get the manifest filename
    
    Returns:
        Manifest filename (default: manifest.json)
    """
    return os.getenv('DASHBOARD_MANIFEST_FILE', 'manifest.json')


def get_kusto_cluster_url() -> Optional[str]:
    """
    Get the Kusto cluster URL from environment
    
    Returns:
        Kusto cluster URL or None if not set
    """
    return os.getenv('KUSTO_CLUSTER_URL')


def get_kusto_database() -> Optional[str]:
    """
    Get the Kusto database name from environment
    
    Returns:
        Kusto database name or None if not set
    """
    return os.getenv('KUSTO_DATABASE')


def validate_dashboard_config() -> dict:
    """
    Validate all required dashboard configuration variables
    
    Returns:
        Dictionary with validated configuration
    
    Raises:
        ValueError: If required variables are missing
    """
    config = {
        'creator': get_dashboard_creator(),
        'output_dir': get_dashboard_output_dir(),
        'manifest_file': get_dashboard_manifest_file(),
        'kusto_cluster_url': get_kusto_cluster_url(),
        'kusto_database': get_kusto_database()
    }
    
    return config


def print_dashboard_config():
    """Print current dashboard configuration for debugging"""
    print("Dashboard Configuration:")
    print("=" * 60)
    
    try:
        creator = get_dashboard_creator()
        print(f"✓ Creator:       {creator}")
    except ValueError as e:
        print(f"✗ Creator:       ERROR - {e}")
    
    output_dir = get_dashboard_output_dir()
    print(f"✓ Output Dir:    {output_dir}")
    
    manifest = get_dashboard_manifest_file()
    print(f"✓ Manifest:      {manifest}")
    
    cluster_url = get_kusto_cluster_url()
    if cluster_url:
        print(f"✓ Kusto Cluster: {cluster_url}")
    else:
        print(f"  Kusto Cluster: (not set)")
    
    database = get_kusto_database()
    if database:
        print(f"✓ Kusto DB:      {database}")
    else:
        print(f"  Kusto DB:      (not set)")
    
    print("=" * 60)


# Example usage and validation
if __name__ == '__main__':
    print_dashboard_config()
    
    # Validate config
    try:
        config = validate_dashboard_config()
        print("\n✓ Configuration is valid!")
        print(f"\nWill export/import dashboards created by: {config['creator']}")
        print(f"Output directory: {config['output_dir']}")
    except ValueError as e:
        print(f"\n✗ Configuration error: {e}")
        exit(1)
