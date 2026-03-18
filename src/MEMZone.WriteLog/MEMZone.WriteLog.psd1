@{
    # Script module associated with this manifest
    RootModule        = 'MEMZone.WriteLog.psm1'

    # Version number of this module (SemVer)
    ModuleVersion     = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID              = 'a3f58b92-7c4e-4d8a-b6f1-2e9d0c5a1b3e'

    # Author of this module
    Author            = 'Ioan Popovici'

    # Company or vendor of this module
    CompanyName       = 'MEM.Zone'

    # Copyright statement for this module
    Copyright         = '(c) Ioan Popovici. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Structured logging with dual console/file output, rich text formatting (tables, blocks, timelines, headers), animated progress indicators via background runspaces, and debug-level function tracing.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Initialize-WriteLog'
        'Test-LogFile'
        'Write-LogBuffer'
        'Write-Log'
        'Format-Message'
        'Write-FunctionHeaderOrFooter'
        'Invoke-WithAnimation'
        'Invoke-WithStatus'
    )

    # Cmdlets, variables, and aliases to export (none)
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Private data passed to the module specified in RootModule
    PrivateData       = @{
        PSData = @{
            Tags         = @('Logging', 'Log', 'Write-Log', 'Console', 'Formatting', 'Animation', 'Progress', 'Table', 'PSEdition_Desktop', 'PSEdition_Core', 'Windows')
            LicenseUri   = 'https://github.com/MEM-Zone/MEM.Zone-WriteLog/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/MEM-Zone/MEM.Zone-WriteLog'
            IconUri      = 'https://raw.githubusercontent.com/MEM-Zone/MEM-Zone.github.io/master/media/MEM.Zone-Logo.png'
            ReleaseNotes = 'https://github.com/MEM-Zone/MEM.Zone-WriteLog/blob/main/docs/CHANGELOG.md'
        }
    }
}
