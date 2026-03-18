function Initialize-WriteLog {
<#
.SYNOPSIS
    Initializes the MEMZone.WriteLog module state.
.DESCRIPTION
    Configures logging parameters including log file path, console output preference,
    debug message logging, and maximum log file size. Automatically creates the log
    directory and file, and handles size-based rotation.
.PARAMETER LogName
    The base name for the log file (without extension).
.PARAMETER LogPath
    The directory path where the log file will be created.
.PARAMETER LogToConsole
    Whether to output messages to the console. Default: $true.
.PARAMETER LogDebugMessages
    Whether to write debug messages to the log file. Default: $false.
.PARAMETER LogMaxSizeMB
    Maximum log file size in MB before rotation. Default: 5.
.EXAMPLE
    Initialize-WriteLog -LogName 'MyScript' -LogPath 'C:\Logs\MyScript'
.EXAMPLE
    Initialize-WriteLog -LogName 'MyScript' -LogPath 'C:\Logs\MyScript' -LogToConsole $false -LogDebugMessages $true
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEMZ.one/WriteLog
.LINK
    https://MEMZ.one/WriteLog-GIT
.LINK
    https://MEMZ.one/WriteLog-ISSUES
.COMPONENT
    Script Logging
.FUNCTIONALITY
    Log Initialization
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$LogName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,

        [Parameter(Position = 2)]
        [bool]$LogToConsole = $true,

        [Parameter(Position = 3)]
        [bool]$LogDebugMessages = $false,

        [Parameter(Position = 4)]
        [ValidateRange(1, 100)]
        [int]$LogMaxSizeMB = 5
    )

    process {

        ## Set module state variables
        $Script:LogName           = $LogName
        $Script:LogPath           = $LogPath
        $Script:LogFullName       = [System.IO.Path]::Combine($LogPath, "$LogName.log")
        $Script:LogToConsole      = $LogToConsole
        $Script:LogDebugMessages  = $LogDebugMessages
        $Script:LogMaxSizeMB      = $LogMaxSizeMB
        $Script:LogBuffer         = [System.Collections.ArrayList]::new()

        ## Create log directory and file, rotate if oversized
        Test-LogFile -LogFile $Script:LogFullName -MaxSizeMB $Script:LogMaxSizeMB
    }
}
