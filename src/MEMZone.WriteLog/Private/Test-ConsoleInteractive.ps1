function Test-ConsoleInteractive {
<#
.SYNOPSIS
    Checks whether the current host supports cursor-based console output.
.DESCRIPTION
    Checks whether the current host supports cursor positioning, which is required for animated
    or in-place console output. Returns $false when output is redirected (piped, captured, or
    running non-interactively), when no console is attached, or when running in the PowerShell ISE.
.EXAMPLE
    if (Test-ConsoleInteractive) { [Console]::SetCursorPosition(0, 0) }
.INPUTS
    None
.OUTPUTS
    System.Boolean
.NOTES
    This is an internal module function and should typically not be called directly.
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
    Console Capability Detection
#>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param ()

    process {
        try {

            ## The ISE host has no real console and throws on cursor positioning
            if ($Host.Name -eq 'Windows PowerShell ISE Host') { return $false }

            ## Redirected output has no cursor to position
            if ([Console]::IsOutputRedirected) { return $false }

            ## Probe the cursor - throws when no console is attached (services, task sequences)
            $null = [Console]::CursorLeft
            return $true
        }
        catch {
            return $false
        }
    }
}
