function Invoke-WithAnimation {
<#
.SYNOPSIS
    Executes a scriptblock while displaying an animated progress indicator.
.DESCRIPTION
    Runs the specified scriptblock in a background runspace and displays an animated
    spinner/progress indicator on the console. When the operation completes, shows a
    success or failure indicator. Also logs the operation to the log file via Write-Log.

    Cross-Runspace Execution Model:
    The scriptblock retains its creation SessionState, so when invoked via & in the
    background runspace, PowerShell executes it in the ORIGINAL session state. This
    gives the scriptblock access to the caller's variables and imported modules
    (e.g., ConfigMgr cmdlets). For explicit variable passing, use the -Variables
    parameter to inject variables directly into the runspace.
.PARAMETER Message
    The message to display alongside the animation.
.PARAMETER ScriptBlock
    The scriptblock to execute while showing the animation.
.PARAMETER Variables
    Optional hashtable of variables to explicitly inject into the background runspace.
    Use this when session state binding is insufficient or for improved clarity.
.PARAMETER Animation
    The animation style to use. Valid values: Spinner, Dots, Braille, Bounce, Box.
    Default: Dots
.PARAMETER SuccessIndicator
    Character to show on success. Default: checkmark
.PARAMETER FailureIndicator
    Character to show on failure. Default: X
.PARAMETER RefreshRate
    Milliseconds between animation frames. Default: 100
.EXAMPLE
    Invoke-WithAnimation -Message 'Creating application' -ScriptBlock { New-CMApplication -Name 'Test' }
.EXAMPLE
    Invoke-WithAnimation -Message 'Copying file' -Variables @{ Source = $src; Dest = $dst } -ScriptBlock {
        Copy-Item -Path $Source -Destination $Dest
    }
.INPUTS
    None
.OUTPUTS
    Returns the output of the ScriptBlock.
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
    Script Utilities
.FUNCTIONALITY
    Animated Progress
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [hashtable]$Variables,

        [Parameter(Position = 2)]
        [ValidateSet('Spinner', 'Dots', 'Braille', 'Bounce', 'Box')]
        [string]$Animation = 'Dots',

        [Parameter()]
        [string]$SuccessIndicator = [char]0x2713,

        [Parameter()]
        [string]$FailureIndicator = [char]0x2717,

        [Parameter()]
        [int]$RefreshRate = 100
    )

    begin {

        ## Define animation frames
        $AnimationFrames = @{
            Spinner = @('|', '/', '-', '\')
            Dots    = @('.  ', '.. ', '...', ' ..', '  .', '   ')
            Braille = @([char]0x280B, [char]0x2819, [char]0x2839, [char]0x2838, [char]0x283C, [char]0x2834, [char]0x2826, [char]0x2827, [char]0x2807, [char]0x280F)
            Bounce  = @([char]0x2801, [char]0x2802, [char]0x2804, [char]0x2802)
            Box     = @([char]0x2596, [char]0x2598, [char]0x259D, [char]0x2597)
        }

        $Frames = $AnimationFrames[$Animation]
        $FrameIndex = 0
        $Success = $true
        $ErrorMessage = $null
        $Result = $null
    }

    process {

        ## If console output disabled, just run without animation
        if (-not $Script:LogToConsole) {
            Write-Log -Message "$Message..." -Console:$false
            try {
                $Result = & $ScriptBlock
            }
            catch {
                $Success = $false
                $ErrorMessage = $PSItem.Exception.Message
                throw
            }
            return $Result
        }

        ## Write initial message without newline
        Write-Host "    - $Message " -NoNewline -ForegroundColor 'Yellow'

        ## Save cursor position for animation
        $AnimationLeft = [Console]::CursorLeft
        $AnimationTop = [Console]::CursorTop
        Write-Host "$($Frames[0])" -NoNewline -ForegroundColor 'Cyan'
        $FrameIndex = 1

        ## Start background runspace
        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.Open()
        $Runspace.SessionStateProxy.SetVariable('ScriptBlock', $ScriptBlock)

        if ($Variables -and $Variables.Count -gt 0) {
            foreach ($Entry in $Variables.GetEnumerator()) {
                $Runspace.SessionStateProxy.SetVariable($Entry.Key, $Entry.Value)
            }
        }

        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $null = $PowerShell.AddScript({
            try {
                $Result = & $ScriptBlock
                @{ Success = $true; Result = $Result; Error = $null }
            }
            catch {
                @{ Success = $false; Result = $null; Error = $PSItem.Exception.Message }
            }
        })

        ## Use input/output buffers to capture streams and prevent console interference
        $InputBuffer = [System.Management.Automation.PSDataCollection[PSObject]]::new()
        $OutputBuffer = [System.Management.Automation.PSDataCollection[PSObject]]::new()
        $AsyncResult = $PowerShell.BeginInvoke($InputBuffer, $OutputBuffer)

        ## Animate while waiting for completion - use .NET methods to avoid cmdlet resolution issues
        try {
            while (-not $AsyncResult.IsCompleted) {
                [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
                [Console]::ForegroundColor = 'Cyan'
                [Console]::Write($Frames[$FrameIndex])
                [Console]::ResetColor()
                $FrameIndex = ($FrameIndex + 1) % $Frames.Count
                [System.Threading.Thread]::Sleep($RefreshRate)
            }

            ## Get the result from output buffer
            $null = $PowerShell.EndInvoke($AsyncResult)
            if ($OutputBuffer -and $OutputBuffer.Count -gt 0) {
                $Success = $OutputBuffer[0].Success
                $Result = $OutputBuffer[0].Result
                $ErrorMessage = $OutputBuffer[0].Error
            }

            ## Show completion indicator BEFORE runspace disposal - use .NET methods
            [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
            [Console]::Write('   ')
            [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
            if ($Success) {
                [Console]::ForegroundColor = 'Green'
                [Console]::WriteLine($SuccessIndicator)
                [Console]::ResetColor()
            }
            else {
                [Console]::ForegroundColor = 'Red'
                [Console]::WriteLine($FailureIndicator)
                [Console]::ResetColor()
            }
        }
        finally {
            ## Clean up runspace
            [System.Threading.Thread]::Sleep(50)
            $PowerShell.Dispose()
            $Runspace.Close()
            $Runspace.Dispose()
        }

        ## Log to file AFTER runspace cleanup (Write-Log is safe now)
        if ($Success) {
            Write-Log -Message "$Message" -Console:$false
        }
        else {
            Write-Log -Message "$Message - Failed: $ErrorMessage" -Severity 'Error' -Console:$false
        }

        ## Return result or throw error
        if (-not $Success -and $ErrorMessage) {
            throw $ErrorMessage
        }

        return $Result
    }
}
