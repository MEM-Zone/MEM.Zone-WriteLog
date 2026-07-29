function Invoke-WithStatus {
<#
.SYNOPSIS
    Executes a scriptblock synchronously with status indicator (no animation).
.DESCRIPTION
    Runs the specified scriptblock synchronously and displays a success or failure indicator.
    Like Invoke-WithAnimation, the scriptblock runs on the calling thread in the caller's
    session state - the only difference is that no animation thread is started. Use it for
    operations that are too quick to animate or where a spinner is unwanted.
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
    Both this function and Invoke-WithAnimation run the scriptblock in the main session, so
    session-bound operations (Import-Module, New-PSDrive, Set-Location) work in either.
    Prefer this one for near-instant operations where animation frames would only flicker.
.LINK
    https://MEM.Zone
.LINK
    https://MEMZ.one/WriteLog
.LINK
    https://MEMZ.one/WriteLog-GIT
.LINK
    https://MEMZ.one/WriteLog-ISSUES
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

        ## If console output is disabled or the host has no console, just run without status display
        if (-not $Script:LogToConsole -or -not (Test-ConsoleInteractive)) {
            Write-Log -Message "$Message" -Console:$false
            try {
                $Result = & $ScriptBlock
                return $Result
            }
            catch {
                ## Log the outcome so non-interactive runs keep failure records too, then rethrow
                Write-Log -Message "$Message - Failed: $($PSItem.Exception.Message)" -Severity 'Error' -Console:$false
                throw
            }
        }

        ## Write message without newline
        [Console]::ForegroundColor = 'Yellow'
        [Console]::Write("    - $Message ")
        [Console]::ResetColor()

        ## Execute scriptblock synchronously in current session
        $Success = $true
        $ErrorRecord = $null
        $Result = $null

        try {
            $Result = & $ScriptBlock
        }
        catch {
            $Success = $false
            $ErrorRecord = $PSItem
        }

        ## Show result indicator
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
            Write-Log -Message "$Message - Failed: $($ErrorRecord.Exception.Message)" -Severity 'Error' -Console:$false

            ## Rethrow the original ErrorRecord so the caller keeps the exception type and stack
            throw $ErrorRecord
        }

        return $Result
    }
}
