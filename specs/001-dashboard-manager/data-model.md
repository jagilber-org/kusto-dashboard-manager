# Data Model: Kusto Dashboard Manager

**Version**: 1.0.0  
**Last Updated**: 2025-10-08  
**Status**: Draft  

## Overview

This document defines the data models, schemas, and structures used by the Kusto Dashboard Manager for dashboard import/export operations.

## Dashboard Definition Format

### Top-Level Structure

```json
{
  "version": "1.0",
  "exported": "2025-10-08T10:00:00Z",
  "exportedBy": "user@domain.com",
  "exportTool": "KustoDashboardManager/1.0.0",
  "dashboard": { }
}
```

### Complete Dashboard Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Kusto Dashboard Definition",
  "type": "object",
  "required": ["version", "exported", "dashboard"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Schema version",
      "pattern": "^[0-9]+\\.[0-9]+$",
      "examples": ["1.0", "1.1", "2.0"]
    },
    "exported": {
      "type": "string",
      "description": "Export timestamp in ISO 8601 format",
      "format": "date-time"
    },
    "exportedBy": {
      "type": "string",
      "description": "User who performed the export",
      "format": "email"
    },
    "exportTool": {
      "type": "string",
      "description": "Tool and version used for export",
      "pattern": "^[A-Za-z0-9_-]+/[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "dashboard": {
      "type": "object",
      "required": ["id", "name", "dataSource", "tiles"],
      "properties": {
        "id": {
          "type": "string",
          "description": "Unique dashboard identifier (GUID)",
          "format": "uuid"
        },
        "name": {
          "type": "string",
          "description": "Dashboard display name",
          "minLength": 1,
          "maxLength": 255
        },
        "description": {
          "type": "string",
          "description": "Dashboard description",
          "maxLength": 2000
        },
        "tags": {
          "type": "array",
          "description": "Dashboard tags for categorization",
          "items": {
            "type": "string"
          },
          "uniqueItems": true
        },
        "dataSource": {
          "type": "object",
          "description": "Primary data source configuration",
          "required": ["clusterUri", "database"],
          "properties": {
            "clusterUri": {
              "type": "string",
              "description": "Kusto cluster URI",
              "format": "uri",
              "pattern": "^https://[a-z0-9-]+\\.[a-z0-9-]+\\.kusto\\.windows\\.net$"
            },
            "database": {
              "type": "string",
              "description": "Database name",
              "minLength": 1
            },
            "alias": {
              "type": "string",
              "description": "Data source alias"
            }
          }
        },
        "tiles": {
          "type": "array",
          "description": "Dashboard tiles (visualizations)",
          "items": {
            "$ref": "#/definitions/Tile"
          },
          "minItems": 0
        },
        "parameters": {
          "type": "array",
          "description": "Dashboard parameters",
          "items": {
            "$ref": "#/definitions/Parameter"
          }
        },
        "layout": {
          "type": "object",
          "description": "Dashboard layout configuration",
          "properties": {
            "columns": {
              "type": "integer",
              "minimum": 1,
              "maximum": 24
            },
            "autoPosition": {
              "type": "boolean"
            }
          }
        },
        "permissions": {
          "type": "object",
          "description": "Dashboard sharing and permissions",
          "properties": {
            "public": {
              "type": "boolean"
            },
            "viewers": {
              "type": "array",
              "items": {
                "type": "string",
                "format": "email"
              }
            },
            "editors": {
              "type": "array",
              "items": {
                "type": "string",
                "format": "email"
              }
            }
          }
        },
        "metadata": {
          "type": "object",
          "description": "Additional metadata",
          "properties": {
            "created": {
              "type": "string",
              "format": "date-time"
            },
            "modified": {
              "type": "string",
              "format": "date-time"
            },
            "createdBy": {
              "type": "string",
              "format": "email"
            },
            "modifiedBy": {
              "type": "string",
              "format": "email"
            }
          }
        }
      }
    }
  },
  "definitions": {
    "Tile": {
      "type": "object",
      "required": ["id", "title", "query", "visualization"],
      "properties": {
        "id": {
          "type": "string",
          "description": "Tile unique identifier"
        },
        "title": {
          "type": "string",
          "description": "Tile display title",
          "minLength": 1,
          "maxLength": 200
        },
        "query": {
          "type": "string",
          "description": "KQL query text",
          "minLength": 1
        },
        "visualization": {
          "type": "string",
          "description": "Visualization type",
          "enum": [
            "table",
            "chart",
            "linechart",
            "barchart",
            "columnchart",
            "areachart",
            "piechart",
            "scatterchart",
            "timechart",
            "map",
            "card",
            "stat",
            "markdown"
          ]
        },
        "position": {
          "type": "object",
          "description": "Tile position and size",
          "required": ["x", "y", "width", "height"],
          "properties": {
            "x": {
              "type": "integer",
              "minimum": 0
            },
            "y": {
              "type": "integer",
              "minimum": 0
            },
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 24
            },
            "height": {
              "type": "integer",
              "minimum": 1
            }
          }
        },
        "parameters": {
          "type": "object",
          "description": "Tile-specific parameters",
          "additionalProperties": true
        },
        "visualizationSettings": {
          "type": "object",
          "description": "Visualization-specific settings",
          "additionalProperties": true
        }
      }
    },
    "Parameter": {
      "type": "object",
      "required": ["name", "type"],
      "properties": {
        "name": {
          "type": "string",
          "description": "Parameter name",
          "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$"
        },
        "type": {
          "type": "string",
          "description": "Parameter data type",
          "enum": ["string", "number", "datetime", "timespan", "bool", "dynamic"]
        },
        "defaultValue": {
          "description": "Default parameter value"
        },
        "displayName": {
          "type": "string",
          "description": "Display name for UI"
        },
        "description": {
          "type": "string",
          "description": "Parameter description"
        },
        "required": {
          "type": "boolean",
          "description": "Whether parameter is required"
        },
        "multiSelect": {
          "type": "boolean",
          "description": "Allow multiple value selection"
        },
        "options": {
          "type": "array",
          "description": "Available parameter values",
          "items": {
            "type": "object",
            "properties": {
              "label": {
                "type": "string"
              },
              "value": {}
            }
          }
        }
      }
    }
  }
}
```

## PowerShell Object Models

### Dashboard Configuration Object

```powershell
class DashboardConfig {
    [string]$Version = "1.0"
    [datetime]$Exported
    [string]$ExportedBy
    [string]$ExportTool
    [Dashboard]$Dashboard
    
    DashboardConfig() {
        $this.Exported = Get-Date
        $this.ExportedBy = "$env:USERNAME@$env:USERDNSDOMAIN"
        $this.ExportTool = "KustoDashboardManager/1.0.0"
    }
}

class Dashboard {
    [string]$Id
    [string]$Name
    [string]$Description
    [string[]]$Tags
    [DataSource]$DataSource
    [Tile[]]$Tiles
    [Parameter[]]$Parameters
    [hashtable]$Layout
    [hashtable]$Permissions
    [hashtable]$Metadata
}

class DataSource {
    [string]$ClusterUri
    [string]$Database
    [string]$Alias
    
    [void]Validate() {
        if ([string]::IsNullOrEmpty($this.ClusterUri)) {
            throw "ClusterUri is required"
        }
        if ($this.ClusterUri -notmatch '^https://[a-z0-9-]+\.[a-z0-9-]+\.kusto\.windows\.net$') {
            throw "Invalid ClusterUri format"
        }
        if ([string]::IsNullOrEmpty($this.Database)) {
            throw "Database is required"
        }
    }
}

class Tile {
    [string]$Id
    [string]$Title
    [string]$Query
    [string]$Visualization
    [TilePosition]$Position
    [hashtable]$Parameters
    [hashtable]$VisualizationSettings
    
    [void]Validate() {
        if ([string]::IsNullOrEmpty($this.Query)) {
            throw "Tile query is required"
        }
        
        $validVisualizations = @(
            'table', 'chart', 'linechart', 'barchart', 'columnchart',
            'areachart', 'piechart', 'scatterchart', 'timechart',
            'map', 'card', 'stat', 'markdown'
        )
        
        if ($this.Visualization -notin $validVisualizations) {
            throw "Invalid visualization type: $($this.Visualization)"
        }
    }
}

class TilePosition {
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    
    [void]Validate() {
        if ($this.Width -lt 1 -or $this.Width -gt 24) {
            throw "Width must be between 1 and 24"
        }
        if ($this.Height -lt 1) {
            throw "Height must be at least 1"
        }
    }
}

class Parameter {
    [string]$Name
    [string]$Type
    [object]$DefaultValue
    [string]$DisplayName
    [string]$Description
    [bool]$Required
    [bool]$MultiSelect
    [ParameterOption[]]$Options
    
    [void]Validate() {
        if ($this.Name -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*$') {
            throw "Invalid parameter name: $($this.Name)"
        }
        
        $validTypes = @('string', 'number', 'datetime', 'timespan', 'bool', 'dynamic')
        if ($this.Type -notin $validTypes) {
            throw "Invalid parameter type: $($this.Type)"
        }
    }
}

class ParameterOption {
    [string]$Label
    [object]$Value
}
```

## Export File Formats

### Standard JSON Export

**Filename Pattern**: `{dashboard-id}_{timestamp}.json`

**Example**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890_20251008T100000Z.json`

```json
{
  "version": "1.0",
  "exported": "2025-10-08T10:00:00Z",
  "exportedBy": "user@contoso.com",
  "exportTool": "KustoDashboardManager/1.0.0",
  "dashboard": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "My Dashboard",
    "description": "Dashboard description",
    "dataSource": {
      "clusterUri": "https://mycluster.region.kusto.windows.net",
      "database": "MyDatabase"
    },
    "tiles": [
      {
        "id": "tile-001",
        "title": "Query Results",
        "query": "MyTable | take 100",
        "visualization": "table",
        "position": {
          "x": 0,
          "y": 0,
          "width": 12,
          "height": 4
        }
      }
    ]
  }
}
```

### Batch Export Manifest

When exporting multiple dashboards, create a manifest file:

**Filename**: `export-manifest.json`

```json
{
  "exportDate": "2025-10-08T10:00:00Z",
  "exportedBy": "user@contoso.com",
  "totalDashboards": 5,
  "successCount": 5,
  "failureCount": 0,
  "dashboards": [
    {
      "id": "dashboard-guid-1",
      "name": "Dashboard 1",
      "file": "dashboard-guid-1_20251008T100000Z.json",
      "status": "success",
      "exportedAt": "2025-10-08T10:00:00Z"
    },
    {
      "id": "dashboard-guid-2",
      "name": "Dashboard 2",
      "file": "dashboard-guid-2_20251008T100010Z.json",
      "status": "success",
      "exportedAt": "2025-10-08T10:00:10Z"
    }
  ],
  "errors": []
}
```

## Configuration File Format

### Application Configuration

**File**: `config/default.json`

```json
{
  "application": {
    "name": "KustoDashboardManager",
    "version": "1.0.0",
    "logLevel": "Info"
  },
  "browser": {
    "type": "msedge",
    "headless": false,
    "timeout": 30000,
    "workProfile": "Default",
    "launchArgs": []
  },
  "kusto": {
    "baseUrl": "https://dataexplorer.azure.com",
    "dashboardsPath": "/dashboards",
    "timeout": 60000
  },
  "export": {
    "outputPath": "./exports",
    "filenamePattern": "{id}_{timestamp}.json",
    "includeMetadata": true,
    "prettyPrint": true,
    "createManifest": true
  },
  "import": {
    "validateSchema": true,
    "conflictResolution": "prompt",
    "backupExisting": true
  },
  "logging": {
    "level": "Info",
    "format": "json",
    "outputPath": "./logs",
    "filename": "dashboard-manager_{date}.log",
    "maxFileSizeMB": 10,
    "maxFiles": 30
  }
}
```

## Validation Rules

### Dashboard Validation Rules

1. **Required Fields**: All required fields must be present
2. **Format Validation**: UUIDs, URLs, and emails must match specified formats
3. **Range Validation**: Numeric values must be within specified ranges
4. **Query Validation**: KQL queries must be syntactically valid
5. **Reference Integrity**: Parameter references in queries must exist

### Implementation

```powershell
function Test-DashboardDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Dashboard
    )
    
    $errors = @()
    
    # Validate required fields
    if ([string]::IsNullOrEmpty($Dashboard.dashboard.id)) {
        $errors += "Dashboard ID is required"
    }
    
    if ([string]::IsNullOrEmpty($Dashboard.dashboard.name)) {
        $errors += "Dashboard name is required"
    }
    
    # Validate data source
    if ($Dashboard.dashboard.dataSource.clusterUri -notmatch '^https://[a-z0-9-]+\.[a-z0-9-]+\.kusto\.windows\.net$') {
        $errors += "Invalid cluster URI format"
    }
    
    # Validate tiles
    foreach ($tile in $Dashboard.dashboard.tiles) {
        if ([string]::IsNullOrEmpty($tile.query)) {
            $errors += "Tile '$($tile.id)' is missing query"
        }
        
        if ($tile.position.width -lt 1 -or $tile.position.width -gt 24) {
            $errors += "Tile '$($tile.id)' has invalid width"
        }
    }
    
    return @{
        IsValid = $errors.Count -eq 0
        Errors = $errors
    }
}
```

## Migration and Versioning

### Schema Version Migration

When schema versions change, implement migration functions:

```powershell
function ConvertTo-SchemaVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Dashboard,
        
        [Parameter(Mandatory)]
        [string]$TargetVersion
    )
    
    $currentVersion = $Dashboard.version
    
    if ($currentVersion -eq $TargetVersion) {
        return $Dashboard
    }
    
    # Implement version-specific migrations
    switch ("$currentVersion->$TargetVersion") {
        "1.0->1.1" {
            # Add new fields with defaults
            $Dashboard | Add-Member -NotePropertyName 'exportTool' -NotePropertyValue 'KustoDashboardManager/1.0.0'
        }
        "1.1->2.0" {
            # Breaking changes - restructure data
            # ... migration logic
        }
    }
    
    $Dashboard.version = $TargetVersion
    return $Dashboard
}
```

---

**Status**: Draft  
**Next Review**: After implementation phase 1  
**Schema Version**: 1.0.0
