<#
.SYNOPSIS
    Build, test, and publish the PSWriteLog module.
.DESCRIPTION
    Orchestrates the module lifecycle: static analysis, unit tests, compiled builds, and
    PowerShell Gallery publishing. Supports individual or combined task execution.
.PARAMETER Task
    One or more build tasks to execute. Default: Analyze, Test.
    - Analyze : Run PSScriptAnalyzer on all module source files.
    - Test    : Run Pester unit and integration tests.
    - Build   : Compile module into a single-file .psm1 in the output directory.
    - Publish : Publish the module to the PowerShell Gallery (requires -NuGetApiKey).
.PARAMETER NuGetApiKey
    API key for publishing to the PowerShell Gallery. Required for the Publish task.
    Store securely and never commit to source control.
.PARAMETER OutputPath
    Directory for build output. Default: ./output/PSWriteLog
.EXAMPLE
    ./build.ps1
    Runs Analyze and Test tasks with default settings.
.EXAMPLE
    ./build.ps1 -Task Build
    Compiles the module into a single-file build.
.EXAMPLE
    ./build.ps1 -Task Analyze, Test, Publish -NuGetApiKey $env:NUGET_API_KEY
    Full CI pipeline: analyze, test, then publish.
#>
[CmdletBinding()]
param (
    [ValidateSet('Analyze', 'Test', 'Build', 'Publish')]
    [string[]]$Task = @('Analyze', 'Test'),

    [string]$NuGetApiKey,

    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '../output/PSWriteLog')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[string]$ProjectRoot      = Split-Path -Path $PSScriptRoot -Parent
[string]$ModuleSourcePath = Join-Path -Path $ProjectRoot -ChildPath 'src/PSWriteLog'
[string]$ModuleName       = 'PSWriteLog'
[string]$TestsPath        = Join-Path -Path $ProjectRoot -ChildPath 'tests'

#region Task: Analyze

if ('Analyze' -in $Task) {
    Write-Host "`n===[ PSScriptAnalyzer ]===" -ForegroundColor Cyan

    if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
        Write-Host '  Installing PSScriptAnalyzer...' -ForegroundColor Yellow
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
    }

    $AnalyzerResults = Invoke-ScriptAnalyzer -Path $ModuleSourcePath -Recurse -Settings PSGallery -Severity @('Error', 'Warning')

    if ($AnalyzerResults) {
        Write-Host "`n  PSScriptAnalyzer found $($AnalyzerResults.Count) issue(s):" -ForegroundColor Red
        $AnalyzerResults | Format-Table -Property Severity, RuleName, ScriptName, Line, Message -AutoSize -Wrap
        throw 'PSScriptAnalyzer validation failed.'
    }
    else {
        Write-Host '  No issues found.' -ForegroundColor Green
    }
}

#endregion

#region Task: Test

if ('Test' -in $Task) {
    Write-Host "`n===[ Pester Tests ]===" -ForegroundColor Cyan

    if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $PSItem.Version -ge [version]'5.0.0' })) {
        Write-Host '  Installing Pester 5...' -ForegroundColor Yellow
        Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion '5.0.0'
    }

    $PesterConfig = New-PesterConfiguration
    $PesterConfig.Run.Path           = $TestsPath
    $PesterConfig.Run.Exit           = $false
    $PesterConfig.Run.PassThru       = $true
    $PesterConfig.Output.Verbosity   = 'Detailed'
    $PesterConfig.TestResult.Enabled = $true
    $PesterConfig.TestResult.OutputPath   = Join-Path -Path $ProjectRoot -ChildPath 'testResults.xml'
    $PesterConfig.TestResult.OutputFormat = 'NUnitXml'

    $PesterResult = Invoke-Pester -Configuration $PesterConfig

    if ($PesterResult.FailedCount -gt 0) {
        throw "Pester: $($PesterResult.FailedCount) test(s) failed."
    }
    else {
        Write-Host "  All $($PesterResult.TotalCount) tests passed." -ForegroundColor Green
    }
}

#endregion

#region Task: Build

if ('Build' -in $Task) {
    Write-Host "`n===[ Build ]===" -ForegroundColor Cyan

    if (Test-Path -Path $OutputPath) {
        Remove-Item -Path $OutputPath -Recurse -Force
    }
    $null = New-Item -Path $OutputPath -ItemType Directory -Force

    ## Read the manifest to get version info
    $ManifestData = Import-PowerShellDataFile -Path (Join-Path -Path $ModuleSourcePath -ChildPath "$ModuleName.psd1")
    Write-Host "  Building $ModuleName v$($ManifestData.ModuleVersion)" -ForegroundColor Yellow

    ## Compile all function files into a single .psm1 for distribution performance
    $CompiledContent = [System.Text.StringBuilder]::new()

    ## Preserve module header and state from the source .psm1
    $SourcePsm1 = Get-Content -Path (Join-Path -Path $ModuleSourcePath -ChildPath "$ModuleName.psm1") -Raw
    $SectionDivider = "##*============================================="
    $HeaderMatch = [regex]::Match($SourcePsm1, '(?s)\A.*?##\*\s*END MODULE STATE\s*\r?\n##\*=+')
    if ($HeaderMatch.Success) {
        [void]$CompiledContent.AppendLine($HeaderMatch.Value)
        [void]$CompiledContent.AppendLine()
    }

    ## Append Function Listings section
    [void]$CompiledContent.AppendLine($SectionDivider)
    [void]$CompiledContent.AppendLine('##* FUNCTION LISTINGS')
    [void]$CompiledContent.AppendLine($SectionDivider)
    [void]$CompiledContent.AppendLine('#region FunctionListings')
    [void]$CompiledContent.AppendLine()

    ## Append Private functions
    $PrivateFiles = Get-ChildItem -Path "$ModuleSourcePath/Private/*.ps1" -ErrorAction SilentlyContinue
    if ($PrivateFiles) {
        foreach ($File in $PrivateFiles) {
            [string]$FunctionName = $File.BaseName
            [void]$CompiledContent.AppendLine("#region function $FunctionName")
            [void]$CompiledContent.AppendLine((Get-Content -Path $File.FullName -Raw))
            [void]$CompiledContent.AppendLine("#endregion function $FunctionName")
            [void]$CompiledContent.AppendLine()
        }
    }

    ## Append Public functions
    $PublicFiles = Get-ChildItem -Path "$ModuleSourcePath/Public/*.ps1" -ErrorAction SilentlyContinue
    if ($PublicFiles) {
        foreach ($File in $PublicFiles) {
            [string]$FunctionName = $File.BaseName
            [void]$CompiledContent.AppendLine("#region function $FunctionName")
            [void]$CompiledContent.AppendLine((Get-Content -Path $File.FullName -Raw))
            [void]$CompiledContent.AppendLine("#endregion function $FunctionName")
            [void]$CompiledContent.AppendLine()
        }
    }

    [void]$CompiledContent.AppendLine('#endregion FunctionListings')
    [void]$CompiledContent.AppendLine($SectionDivider)
    [void]$CompiledContent.AppendLine('##* END FUNCTION LISTINGS')
    [void]$CompiledContent.AppendLine($SectionDivider)
    [void]$CompiledContent.AppendLine()

    ## Preserve module cleanup handler from the source .psm1
    $CleanupMatch = [regex]::Match($SourcePsm1, '(?s)##\*=+\r?\n##\* MODULE CLEANUP.*?##\*\s*END MODULE CLEANUP\s*\r?\n##\*=+')
    if ($CleanupMatch.Success) {
        [void]$CompiledContent.AppendLine($CleanupMatch.Value)
        [void]$CompiledContent.AppendLine()
    }

    Set-Content -Path (Join-Path -Path $OutputPath -ChildPath "$ModuleName.psm1") -Value $CompiledContent.ToString() -Encoding UTF8 -Force

    ## Copy the manifest
    Copy-Item -Path (Join-Path -Path $ModuleSourcePath -ChildPath "$ModuleName.psd1") -Destination $OutputPath -Force

    Write-Host "  Build output: $OutputPath" -ForegroundColor Green
}

#endregion

#region Task: Publish

if ('Publish' -in $Task) {
    Write-Host "`n===[ Publish to PSGallery ]===" -ForegroundColor Cyan

    if ([string]::IsNullOrEmpty($NuGetApiKey)) {
        throw 'NuGetApiKey is required for the Publish task. Pass it via -NuGetApiKey or $env:NUGET_API_KEY.'
    }

    ## Determine the publish path (prefer compiled build output, fallback to source)
    [string]$PublishPath = if (Test-Path -Path (Join-Path -Path $OutputPath -ChildPath "$ModuleName.psd1")) {
        $OutputPath
    }
    else {
        Write-Host '  No build output found. Publishing from source.' -ForegroundColor Yellow
        $ModuleSourcePath
    }

    Write-Host "  Publishing from: $PublishPath" -ForegroundColor Yellow

    Publish-Module -Path $PublishPath -NuGetApiKey $NuGetApiKey -Verbose

    Write-Host '  Published successfully.' -ForegroundColor Green
}

#endregion

Write-Host "`n===[ Done ]===" -ForegroundColor Cyan
