function Write-LogBuffer {
<#
.SYNOPSIS
    Writes the log buffer to the log file.
.DESCRIPTION
    Writes the log buffer to the log file and clears the buffer.
.INPUTS
    None
.OUTPUTS
    None
.EXAMPLE
    Write-LogBuffer
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
    Log Buffer Management
#>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    process {
        if ($null -ne $Script:LogBuffer -and $Script:LogBuffer.Count -gt 0) {
            try {

                ## Convert ArrayList to string array for Add-Content
                [string[]]$LogEntries = $Script:LogBuffer.ToArray()

                ## Append to log file
                if ($null -ne $Script:LogFullName -and (Test-Path -Path (Split-Path -Path $Script:LogFullName -Parent) -PathType Container)) {
                    Add-Content -Path $Script:LogFullName -Value $LogEntries -Encoding UTF8 -ErrorAction Stop
                }

                ## Clear buffer
                $Script:LogBuffer.Clear()
            }
            catch {
                Write-Warning -Message "Failed to write to log file: $($PSItem.Exception.Message)"
            }
        }
    }
}
