function Test-LogFile {
<#
.SYNOPSIS
    Checks if the log path exists and if the log file exceeds the maximum specified size.
.DESCRIPTION
    Checks if the log path exists and creates the folder and file if needed.
    Checks if the log file exceeds the maximum specified size and rotates it by
    renaming the current file with a timestamp suffix (e.g., Application_20250114-153000.log).
.PARAMETER LogFile
    Specifies the path to the log file.
.PARAMETER MaxSizeMB
    Specifies the maximum size in MB before the log file is rotated.
.EXAMPLE
    Test-LogFile -LogFile 'C:\Logs\Application.log' -MaxSizeMB 5
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
    Log File Management
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$LogFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 100)]
        [int]$MaxSizeMB
    )

    process {
        try {

            ## Create log folder if it doesn't exist
            $LogPath = [System.IO.Path]::GetDirectoryName($LogFile)
            [bool]$IsLogFolderPresent = Test-Path -Path $LogPath -PathType Container
            if (-not $IsLogFolderPresent) {
                try {
                    $null = New-Item -Path $LogPath -ItemType Directory -Force -ErrorAction Stop
                }
                catch {
                    $Script:LogPath     = [System.IO.Path]::GetTempPath()
                    $Script:LogFullName = [System.IO.Path]::Combine($Script:LogPath, "$Script:LogName.log")
                    Write-Warning -Message "Failed to create log folder: $($PSItem.Exception.Message). Using temp directory instead."
                }
            }

            ## Create log file if it doesn't exist
            [bool]$IsLogFilePresent = Test-Path -Path $LogFile -PathType Leaf
            if (-not $IsLogFilePresent) {
                try {
                    $null = New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning -Message "Failed to create log file: $($PSItem.Exception.Message)"
                }
            }

            ## Get log file information
            [System.IO.FileInfo]$LogFileInfo = Get-Item -Path $LogFile -ErrorAction Stop

            ## Convert bytes to MB
            [double]$LogFileSizeMB = $LogFileInfo.Length / 1MB

            ## If log file exceeds maximum size, rotate it by renaming with a timestamp
            if ($LogFileSizeMB -ge $MaxSizeMB) {
                Write-Verbose -Message "Log file size [$($LogFileSizeMB.ToString('0.00')) MB] exceeds maximum size [$MaxSizeMB MB]. Rotating log file..."
                [string]$FileTimestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
                [string]$BaseName       = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
                [string]$Extension      = [System.IO.Path]::GetExtension($LogFile)
                [string]$ArchiveName    = "${BaseName}_${FileTimestamp}${Extension}"
                [string]$ArchivePath    = [System.IO.Path]::Combine($LogPath, $ArchiveName)
                Rename-Item -Path $LogFile -NewName $ArchivePath -Force -ErrorAction Stop
                [string]$CurrentTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                [string]$RotationMessage = "$CurrentTimestamp [Information] Log file rotated. Previous log archived to [$ArchiveName]"
                $null = New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop
                Set-Content -Path $LogFile -Value $RotationMessage -Encoding UTF8 -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Warning -Message "Error checking log file size: $($PSItem.Exception.Message)"
        }
    }
}
