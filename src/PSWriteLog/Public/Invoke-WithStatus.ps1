function Invoke-WithStatus {
<#
.SYNOPSIS
    Executes a scriptblock synchronously with status indicator (no animation).
.DESCRIPTION
    Runs the specified scriptblock in the CURRENT session (not a runspace) and displays
    a success or failure indicator. Use this for operations that must run in the main
    session (e.g., Import-Module, New-PSDrive, Set-Location for ConfigMgr).
.PARAMETER Message
    The message to display alongside the status.
.PARAMETER ScriptBlock
    The scriptblock to execute.
.PARAMETER SuccessIndicator
    Character to show on success. Default: checkmark
.PARAMETER FailureIndicator
    Character to show on failure. Default: X
.EXAMPLE
    Invoke-WithStatus -Message 'Loading ConfigMgr module' -ScriptBlock { Import-Module ... }
.INPUTS
    None
.OUTPUTS
    Returns the output of the ScriptBlock.
.NOTES
    Use this instead of Invoke-WithAnimation when the operation must run in the main session.
.LINK
    https://MEM.Zone
.COMPONENT
    Script Utilities
.FUNCTIONALITY
    Status Indicator
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [string]$SuccessIndicator = [char]0x2713,

        [Parameter()]
        [string]$FailureIndicator = [char]0x2717
    )

    process {

        if (-not $Script:LogToConsole) {
            Write-Log -Message "$Message" -Console:$false
            try {
                $Result = & $ScriptBlock
                return $Result
            }
            catch {
                throw
            }
        }

        [Console]::ForegroundColor = 'Yellow'
        [Console]::Write("    - $Message ")
        [Console]::ResetColor()

        $Success = $true
        $ErrorMessage = $null
        $Result = $null

        try {
            $Result = & $ScriptBlock
        }
        catch {
            $Success = $false
            $ErrorMessage = $PSItem.Exception.Message
        }

        if ($Success) {
            [Console]::ForegroundColor = 'Green'
            [Console]::WriteLine($SuccessIndicator)
            [Console]::ResetColor()
            Write-Log -Message "$Message" -Console:$false
        }
        else {
            [Console]::ForegroundColor = 'Red'
            [Console]::WriteLine($FailureIndicator)
            [Console]::ResetColor()
            Write-Log -Message "$Message - Failed: $ErrorMessage" -Severity 'Error' -Console:$false
            throw $ErrorMessage
        }

        return $Result
    }
}
