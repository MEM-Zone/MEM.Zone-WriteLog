# MEMZone.WriteLog

[![CI](https://github.com/MEM-Zone/MEM.Zone-WriteLog/actions/workflows/ci.yml/badge.svg)](https://github.com/MEM-Zone/MEM.Zone-WriteLog/actions/workflows/ci.yml)
[![PSGallery Version](https://img.shields.io/powershellgallery/v/MEMZone.WriteLog.svg)](https://www.powershellgallery.com/packages/MEMZone.WriteLog)
[![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/MEMZone.WriteLog.svg)](https://www.powershellgallery.com/packages/MEMZone.WriteLog)
[![License](https://img.shields.io/github/license/MEM-Zone/MEM.Zone-WriteLog.svg)](LICENSE)

Structured PowerShell logging with dual console/file output, rich text formatting, animated progress indicators, and debug-level function tracing.

## Features

- **Dual output** - simultaneous console (colored) and file logging with buffered writes
- **Rich formatting** - tables, centered blocks, inline headers, timelines, lists, and separators
- **Animated progress** - background runspace execution with spinner/dots/braille/bounce/box indicators
- **Size-based rotation** - automatic log file archival with timestamp when size limit is exceeded
- **Debug tracing** - function entry/exit logging with full parameter capture
- **Cross-platform** - PowerShell 5.1 (Desktop) and PowerShell 7+ (Core)

## Installation

### PowerShell Gallery (recommended)

```powershell
Install-Module -Name MEMZone.WriteLog -Scope CurrentUser
```

### Manual

Clone the repository and import the module directly:

```powershell
git clone https://github.com/MEM-Zone/MEM.Zone-WriteLog.git
Import-Module ./MEM.Zone-WriteLog/src/MEMZone.WriteLog/MEMZone.WriteLog.psd1
```

## Quick Start

```powershell
Import-Module MEMZone.WriteLog

# Initialize logging
Initialize-WriteLog -LogName 'MyScript' -LogPath 'C:\Logs\MyScript'

# Write messages with different formatting
Write-Log -Message 'Operation completed successfully'
Write-Log -Message 'DEPLOYMENT' -FormatOptions @{ Mode = 'InlineHeader'; ForegroundColor = 'Cyan' }
Write-Log -Severity 'Warning' -Message 'Disk space is running low'

# Display a formatted table
$Data = @(
    [PSCustomObject]@{ Server = 'SRV01'; Status = 'Online';  CPU = '23%' }
    [PSCustomObject]@{ Server = 'SRV02'; Status = 'Offline'; CPU = 'N/A' }
)
Write-Log -Message $Data -FormatOptions @{
    Mode        = 'Table'
    Title       = 'Server Status'
    CellPadding = 1
    AddEmptyRow = 'BeforeAndAfter'
}

# Execute with animated progress
Invoke-WithAnimation -Message 'Copying files' -ScriptBlock {
    Copy-Item -Path $Source -Destination $Dest -Recurse
}

# Execute in current session with status indicator
Invoke-WithStatus -Message 'Loading module' -ScriptBlock {
    Import-Module SomeModule
}

# Flush remaining log buffer
Write-LogBuffer
```

## Functions

| Function | Description |
|---|---|
| `Initialize-WriteLog` | Configure logging (path, console output, debug, rotation size) |
| `Write-Log` | Write a structured log entry with severity and formatting |
| `Write-LogBuffer` | Flush the in-memory buffer to the log file |
| `Test-LogFile` | Ensure log directory/file exist; rotate if oversized |
| `Format-Message` | Format text as Block, Table, Timeline, List, Header, etc. |
| `Write-FunctionHeaderOrFooter` | Debug-trace function entry/exit with parameters |
| `Invoke-WithAnimation` | Run a scriptblock with animated console progress |
| `Invoke-WithStatus` | Run a scriptblock with synchronous status indicator |

## Format Modes

`Format-Message` and `Write-Log -FormatOptions` support these modes:

| Mode | Output |
|---|---|
| `Block` | Full-width separator box with arrow prefix |
| `CenteredBlock` | Full-width separator box with centered text |
| `Line` | Single separator line |
| `InlineHeader` | `===[ TITLE ]===` |
| `InlineSubHeader` | `---[ title ]---` |
| `Timeline` | `    - message` (indented bullet) |
| `TimelineHeader` | `    message` (indented, no bullet) |
| `List` | Key-value pairs from hashtable/PSCustomObject |
| `Table` | Formatted table with headers, row numbers, optional footer |

## Build & Test

```powershell
# Run static analysis and tests
./build/build.ps1

# Run specific tasks
./build/build.ps1 -Task Analyze
./build/build.ps1 -Task Test
./build/build.ps1 -Task Build

# Full pipeline: analyze, test, build, publish
./build/build.ps1 -Task Analyze, Test, Build, Publish -NuGetApiKey $env:NUGET_API_KEY
```

### Requirements

- [Pester](https://pester.dev/) 5.0+
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)

## CI/CD

The repository includes GitHub Actions workflows:

- **CI** (`ci.yml`) - runs on every push/PR to `main`: PSScriptAnalyzer + Pester on Windows and Ubuntu.
- **Publish** (`publish.yml`) - runs on version tags (`v*`): full pipeline + publish to PSGallery.

To publish, create a tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `NUGET_API_KEY` secret must be configured in the repository settings.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Add tests for any new functionality
4. Ensure `./build/build.ps1` passes
5. Submit a pull request

## License

This project is licensed under the [MIT License](LICENSE).
