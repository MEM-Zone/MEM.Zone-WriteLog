<#
.SYNOPSIS
    PSWriteLog - PowerShell Logging, Formatting, and Animation Module.
.DESCRIPTION
    Provides structured logging with dual console/file output, rich text formatting
    (tables, blocks, timelines, headers), animated progress indicators via background
    runspaces, and debug-level function tracing.
.NOTES
    Author:         Ioan Popovici
    Creation Date:  2025-01-14
    Module Version: 1.0.0
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>

#region Module State

[string]$Script:LogName           = ''
[string]$Script:LogPath           = ''
[string]$Script:LogFullName       = ''
[bool]$Script:LogDebugMessages    = $false
[bool]$Script:LogToConsole        = $true
[int]$Script:LogMaxSizeMB         = 5
$Script:LogBuffer                 = [System.Collections.ArrayList]::new()

#endregion Module State

#region Dot-Source Function Files

$Public  = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1"  -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)

foreach ($FunctionFile in @($Public + $Private)) {
    try {
        . $FunctionFile.FullName
    }
    catch {
        Write-Error -Message "Failed to import [$($FunctionFile.FullName)]: $($PSItem.Exception.Message)"
    }
}

#endregion Dot-Source Function Files

#region Module Cleanup

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($null -ne $Script:LogBuffer -and $Script:LogBuffer.Count -gt 0) {
        Write-LogBuffer
    }
}

#endregion Module Cleanup
