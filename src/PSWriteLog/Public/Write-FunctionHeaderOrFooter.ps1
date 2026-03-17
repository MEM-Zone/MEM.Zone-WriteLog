function Write-FunctionHeaderOrFooter {
<#
.SYNOPSIS
    Write the function header or footer to the log upon first entering or exiting a function.
.DESCRIPTION
    Write the "Function Start" message, the bound parameters the function was invoked with,
    or the "Function End" message when entering or exiting a function.
    Messages are debug messages so will only be logged if LogDebugMessage option is enabled.
.PARAMETER CmdletName
    The name of the function this function is invoked from.
.PARAMETER CmdletBoundParameters
    The bound parameters of the function this function is invoked from.
.PARAMETER Header
    Write the function header.
.PARAMETER Footer
    Write the function footer.
.EXAMPLE
    Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
.EXAMPLE
    Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
.INPUTS
    None
.OUTPUTS
    None
.LINK
    https://MEM.Zone
.COMPONENT
    Script Utilities
.FUNCTIONALITY
    Function Tracing
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CmdletName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Header')]
        [AllowEmptyCollection()]
        [hashtable]$CmdletBoundParameters,

        [Parameter(Mandatory = $true, ParameterSetName = 'Header')]
        [switch]$Header,

        [Parameter(Mandatory = $true, ParameterSetName = 'Footer')]
        [switch]$Footer
    )

    process {
        if ($Header) {
            Write-Log -Message 'Function Start' -Source $CmdletName -DebugMessage

            if ($CmdletBoundParameters.Count -gt 0) {
                $ParamStringBuilder = [System.Text.StringBuilder]::new()

                [int]$MaxKeyLength = 0
                foreach ($Key in $CmdletBoundParameters.Keys) {
                    [int]$KeyLength = $Key.Length + 4
                    if ($KeyLength -gt $MaxKeyLength) { $MaxKeyLength = $KeyLength }
                }
                $MaxKeyLength += 2

                foreach ($Param in $CmdletBoundParameters.GetEnumerator()) {
                    [string]$ParameterName = "[-$($Param.Key)]"
                    [string]$ParameterValue = Switch ($Param.Value) {
                        { $null -eq $PSItem } { '<null>' }
                        { $PSItem -is [System.Security.SecureString] } { '<SecureString>' }
                        { $PSItem -is [System.Management.Automation.PSCredential] } { "<PSCredential: $($PSItem.UserName)>" }
                        { $PSItem -is [array] } {
                            if ($PSItem.Count -eq 0) { '@()' }
                            elseif ($PSItem.Count -gt 10) { "@($($PSItem.Count) items)" }
                            else { "@($($PSItem -join ', '))" }
                        }
                        { $PSItem -is [hashtable] } {
                            if ($PSItem.Count -eq 0) { '@{}' }
                            elseif ($PSItem.Count -gt 10) { "@{$($PSItem.Count) keys}" }
                            else { "@{$($PSItem.Keys -join ', ')}" }
                        }
                        { $PSItem -is [bool] } { $PSItem.ToString() }
                        { $PSItem -is [switch] } { $PSItem.IsPresent.ToString() }
                        default {
                            [string]$StringValue = $PSItem.ToString()
                            if ($StringValue.Length -gt 100) { "$($StringValue.Substring(0, 97))..." }
                            else { $StringValue }
                        }
                    }
                    [void]$ParamStringBuilder.AppendLine(("{0,-$MaxKeyLength} {1}" -f $ParameterName, $ParameterValue))
                }

                [string]$FormattedParameters = $ParamStringBuilder.ToString().TrimEnd()
                Write-Log -Message "Function invoked with bound parameter(s):`n$FormattedParameters" -Source $CmdletName -DebugMessage
            }
            else {
                Write-Log -Message 'Function invoked without any bound parameters.' -Source $CmdletName -DebugMessage
            }
        }
        elseif ($Footer) {
            Write-Log -Message 'Function End' -Source $CmdletName -DebugMessage
        }
    }
}
