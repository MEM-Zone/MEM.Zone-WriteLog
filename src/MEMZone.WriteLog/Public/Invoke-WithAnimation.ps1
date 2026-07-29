function Invoke-WithAnimation {
<#
.SYNOPSIS
    Executes a scriptblock while displaying an animated progress indicator.
.DESCRIPTION
    Runs the specified scriptblock and displays an animated spinner/progress indicator on the console.
    When the operation completes, shows a success or failure indicator. Also logs the operation to the
    log file via Write-Log.

    Execution Model:
    The scriptblock runs on the CALLING thread, in the caller's session state, so it resolves the
    caller's variables, functions and modules exactly as inline code would. Only the animation itself
    is pushed to a background runspace, where it touches nothing but the console and its own state.

    This split matters. A scriptblock keeps the SessionState it was created in, so running it in a
    background runspace would execute it in the caller's session state from a second thread - two
    threads sharing one scope stack, which corrupts variable lookups in whichever one loses the race.
    Animating in the background instead of the work keeps the shared session state single-threaded.

    The scriptblock should not write console output itself - the animation stops as soon as it
    detects another writer, but the in-place indicator may then finish on a different line.
.PARAMETER Message
    The message to display alongside the animation.
.PARAMETER ScriptBlock
    The scriptblock to execute while showing the animation.
.PARAMETER Variables
    Optional hashtable of variables to make available to the scriptblock (injected via
    InvokeWithContext, so it works from both script and module contexts). The scriptblock already
    sees the caller's variables, so this is only needed to pass values it would not otherwise
    resolve, or to state the inputs explicitly for readability.
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
    Session-bound operations (Import-Module, New-PSDrive, Set-Location) work inside the scriptblock
    because it runs on the calling thread in the caller's session state.
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
        $Success = $true
        $ErrorRecord = $null
        $Result = $null
    }

    process {

        ## Make the requested variables available to the scriptblock via InvokeWithContext, which
        ## injects them into the scriptblock's own session state. Unlike Set-Variable -Scope Local,
        ## this also works from inside a module - a module function's local scope is invisible to a
        ## scriptblock bound to the caller's session state.
        [System.Collections.Generic.List[psvariable]]$VariableList = [System.Collections.Generic.List[psvariable]]::new()
        if ($Variables -and $Variables.Count -gt 0) {
            foreach ($Entry in $Variables.GetEnumerator()) {
                $VariableList.Add([psvariable]::new($Entry.Key, $Entry.Value))
            }
        }

        ## If console output is disabled or the host cannot position the cursor, run without animation
        if (-not $Script:LogToConsole -or -not (Test-ConsoleInteractive)) {
            Write-Log -Message "$Message..." -Console:$false
            try {
                $Result = if ($VariableList.Count -gt 0) { $ScriptBlock.InvokeWithContext($null, $VariableList, $null) } else { & $ScriptBlock }
            }
            catch {
                ## Log the outcome so non-interactive runs keep failure records too, then rethrow
                Write-Log -Message "$Message - Failed: $($PSItem.Exception.Message)" -Severity 'Error' -Console:$false
                throw
            }
            return $Result
        }

        ## Write initial message without newline and save the cursor position for the animation
        Write-Host "    - $Message " -NoNewline -ForegroundColor 'Yellow'
        $AnimationLeft = [Console]::CursorLeft
        $AnimationTop = [Console]::CursorTop

        ## Start the animation in a background runspace. It is handed only value types and the frame
        ## list, so it never reaches into the caller's session state.
        $StopSignal = [System.Threading.ManualResetEventSlim]::new($false)
        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.Open()
        $Runspace.SessionStateProxy.SetVariable('Frames', $Frames)
        $Runspace.SessionStateProxy.SetVariable('AnimationLeft', $AnimationLeft)
        $Runspace.SessionStateProxy.SetVariable('AnimationTop', $AnimationTop)
        $Runspace.SessionStateProxy.SetVariable('RefreshRate', $RefreshRate)
        $Runspace.SessionStateProxy.SetVariable('StopSignal', $StopSignal)

        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $null = $PowerShell.AddScript({
            $FrameIndex = 0
            $ExpectedLeft = -1
            $ExpectedTop = -1
            while (-not $StopSignal.IsSet) {
                try {

                    ## If another writer moved the cursor since the last frame, the saved coordinates
                    ## are stale - stop animating instead of painting frames over foreign output
                    if ($ExpectedTop -ge 0 -and ([Console]::CursorTop -ne $ExpectedTop -or [Console]::CursorLeft -ne $ExpectedLeft)) { break }

                    ## Save and restore the foreground color instead of resetting it, so a color set
                    ## by the main thread between frames is not clobbered
                    $PreviousColor = [Console]::ForegroundColor
                    [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
                    [Console]::ForegroundColor = 'Cyan'
                    [Console]::Write($Frames[$FrameIndex])
                    [Console]::ForegroundColor = $PreviousColor
                    $ExpectedLeft = [Console]::CursorLeft
                    $ExpectedTop = [Console]::CursorTop
                }
                catch {
                    ## The console went away (resized, redirected, closed) - stop animating quietly
                    break
                }
                $FrameIndex = ($FrameIndex + 1) % $Frames.Count
                [System.Threading.Thread]::Sleep($RefreshRate)
            }
        })
        $AsyncResult = $PowerShell.BeginInvoke()

        ## Suppress progress bars for the duration. Cmdlets like Invoke-WebRequest render progress
        ## through the host, which repaints and scrolls the console and would move the animation off
        ## its saved cursor position. Set at global scope (and restored in finally) so it also
        ## reaches the scriptblock's own scope chain when this function runs from inside a module.
        $PreviousProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'

        ## Run the actual work on THIS thread, in the caller's session state. Nothing is marshalled
        ## across a runspace boundary, so results, errors and variable lookups all behave normally.
        try {
            $Result = if ($VariableList.Count -gt 0) { $ScriptBlock.InvokeWithContext($null, $VariableList, $null) } else { & $ScriptBlock }
        }
        catch {
            $Success = $false
            $ErrorRecord = $PSItem

            ## InvokeWithContext surfaces scriptblock errors wrapped in a MethodInvocationException -
            ## unwrap so the caller gets the original ErrorRecord back
            if ($PSItem.Exception -is [System.Management.Automation.MethodInvocationException] -and $PSItem.Exception.InnerException -is [System.Management.Automation.IContainsErrorRecord]) {
                $ErrorRecord = $PSItem.Exception.InnerException.ErrorRecord
            }
        }
        finally {

            ## Restore progress rendering and stop the animation
            $global:ProgressPreference = $PreviousProgressPreference
            $StopSignal.Set()
            try { $null = $PowerShell.EndInvoke($AsyncResult) } catch { Write-Debug -Message "Animation runspace cleanup: $($PSItem.Exception.Message)" }
            $PowerShell.Dispose()
            $Runspace.Close()
            $Runspace.Dispose()
            $StopSignal.Dispose()
        }

        ## Show the completion indicator in place of the last animation frame. If the scriptblock
        ## wrote console output (or scrolled the buffer), the saved coordinates are stale - finish
        ## on the current line instead of overpainting whatever is there now.
        try {
            if ([Console]::CursorTop -eq $AnimationTop -and [Console]::CursorLeft -ge $AnimationLeft) {
                [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
                [Console]::Write('   ')
                [Console]::SetCursorPosition($AnimationLeft, $AnimationTop)
            }
            if ($Success) {
                [Console]::ForegroundColor = 'Green'
                [Console]::WriteLine($SuccessIndicator)
            }
            else {
                [Console]::ForegroundColor = 'Red'
                [Console]::WriteLine($FailureIndicator)
            }
            [Console]::ResetColor()
        }
        catch {
            Write-Host ''
        }

        ## Log the outcome
        if ($Success) {
            Write-Log -Message "$Message" -Console:$false
        }
        else {
            Write-Log -Message "$Message - Failed: $($ErrorRecord.Exception.Message)" -Severity 'Error' -Console:$false
        }

        ## Rethrow the original ErrorRecord so the caller keeps the exception type and stack
        if (-not $Success) { throw $ErrorRecord }

        return $Result
    }
}
