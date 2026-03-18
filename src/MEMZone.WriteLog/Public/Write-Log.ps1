function Write-Log {
<#
.SYNOPSIS
    Writes a message to the log file and/or console.
.DESCRIPTION
    Writes a timestamped log entry to the internal buffer and displays it with optional formatting.
    By default uses Write-Verbose. Use -Console to use Write-Host with color support instead.
.PARAMETER Severity
    Specifies the severity level of the message. Available options: Information, Warning, Debug, Error.
.PARAMETER Message
    The log message to write. Can be a string, array of strings, or object data for table formatting.
.PARAMETER Source
    The source of the message. This is used to identify the source of the message in the log file.
.PARAMETER FormatOptions
    Optional hashtable of formatting parameters:
        - Mode        : Output style (Block, CenteredBlock, Line, InlineHeader, InlineSubHeader, Timeline, TimelineHeader, List, Table, Default)
        - AddEmptyRow : Add blank lines (No, Before, After, BeforeAndAfter)
        - Title       : For table mode, specifies the table title
        - NewHeaders  : Maps display headers to property names
        - ColumnWidths: Optional custom column widths
        - CellPadding : Amount of horizontal padding to add within cells. Default is: 0.
        - VerticalPadding: Amount of padding to add above and below the table. Default is: 0.
        - ForegroundColor : Color for Write-Host output (ignored in verbose mode). Default: Yellow
        - SeparatorColor  : Color for separators in Write-Host output (ignored in verbose mode). Default: DarkGray
.PARAMETER Console
    If specified, uses Write-Host with color support instead of Write-Verbose for output.
.PARAMETER DebugMessage
    Specifies that the message is a debug message. Debug messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER LogDebugMessages
    Whether to write debug messages to the log file (default: value of module LogDebugMessages setting).
.PARAMETER SkipLogFormatting
    Whether to skip formatting for the log message.
.EXAMPLE
    Write-Log -Message 'Successfully Installed'
.EXAMPLE
    Write-Log -Message $Message -FormatOptions @{
        Mode        = 'Table'
        Title       = 'MEM.Zone'
        NewHeaders  = [ordered]@{
            'Location'   = 'City'
            'Status'     = 'OperationStatus'
            'Compliance' = 'ComplianceStatus'
        }
        AddEmptyRow = 'BeforeAndAfter'
    }
.EXAMPLE
    Write-Log -Message 'IMPORT APPLICATION' -FormatOptions @{ Mode = 'InlineHeader'; ForegroundColor = 'Cyan' }
.INPUTS
    System.Object
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
    Log Message
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Position = 0)]
        [Alias('Level')]
        [ValidateSet('Information', 'Warning', 'Debug', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('LogMessage')]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Message,

        [Parameter(Position = 2)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source,

        [Parameter(Position = 3)]
        [hashtable]$FormatOptions,

        [Parameter()]
        [bool]$Console = $Script:LogToConsole,

        [Parameter()]
        [switch]$DebugMessage,

        [Parameter()]
        [switch]$LogDebugMessages = $Script:LogDebugMessages,

        [Parameter()]
        [switch]$SkipLogFormatting
    )

    begin {

        ## Initialize variables
        [string]$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        [string[]]$MessageLines = @()
    }

    process {
        try {

            ## Format the message or use raw message if formatting is skipped
            if ($SkipLogFormatting -or $DebugMessage) {
                if ($null -eq $Message) {
                    $MessageLines = @('(No message)')
                }
                elseif ($Message -is [array] -and $Message[0] -is [string]) {
                    $MessageLines = @($Message | ForEach-Object { if ($null -eq $PSItem) { '(null)' } else { $PSItem.ToString() } })
                }
                else {
                    try {
                        $MessageLines = @($Message.ToString())
                    }
                    catch {
                        $MessageLines = @('(Message cannot be displayed)')
                    }
                }
            }
            else {

                #  Initialize FormatOptions if not provided
                if ($null -eq $FormatOptions) {
                    $FormatOptions = @{ Mode = 'Timeline' }
                }

                #  Ensure Mode is set
                if (-not $FormatOptions.ContainsKey('Mode')) {
                    $FormatOptions['Mode'] = 'Timeline'
                }

                #  Use Format-Message for all formatting
                $MessageLines = Format-Message -Message $Message -FormatData $FormatOptions
            }

            ## Ensure we have at least one line and MessageLines is not null
            if ($null -eq $MessageLines -or $MessageLines.Count -eq 0) {
                $MessageLines = @('(Empty message)')
            }

            ## Extract color options (only used in Console mode)
            [string]$ForegroundColor = if ($FormatOptions -and $FormatOptions.ContainsKey('ForegroundColor')) { $FormatOptions['ForegroundColor'] } else { 'Yellow' }
            [string]$SeparatorColor  = if ($FormatOptions -and $FormatOptions.ContainsKey('SeparatorColor'))  { $FormatOptions['SeparatorColor']  } else { 'DarkGray' }

            ## Write to console and log file
            foreach ($MessageLine in $MessageLines) {
                if (-not $DebugMessage) {
                    switch ($Severity) {
                        'Information' {
                            if ($Console) {
                                #  Use [Console]::WriteLine for proper Unicode support
                                if ($MessageLine -match '^[=\-]+$') {
                                    [Console]::ForegroundColor = $SeparatorColor
                                }
                                else {
                                    [Console]::ForegroundColor = $ForegroundColor
                                }
                                [Console]::WriteLine($MessageLine)
                                [Console]::ResetColor()
                            }
                            else {
                                Write-Verbose -Message $MessageLine
                            }
                        }
                        'Warning' { Write-Warning -Message $MessageLine }
                        'Error'   { Write-Error   -Message "  $MessageLine" -ErrorAction Continue }
                    }
                }
                else {
                    if ($Source) {
                        Write-Debug -Message "[$Source] $MessageLine"
                    }
                    else {
                        Write-Debug -Message "  $MessageLine"
                    }
                }

                #  Skip debug logging if disabled
                if ($DebugMessage -and -not $LogDebugMessages) { continue }

                #  Add timestamp and severity to the message and add to the log buffer
                if ($DebugMessage -and $Source) {
                    [string]$LogEntry = "$Timestamp [$Source] [$Severity] $MessageLine"
                }
                else {
                    [string]$LogEntry = "$Timestamp [$Severity] $MessageLine"
                }

                # Ensure LogBuffer exists before trying to add to it
                if ($null -ne $Script:LogBuffer) {
                    $null = $Script:LogBuffer.Add($LogEntry)
                }
            }

            ## Write the log buffer to the log file if it exceeds the threshold or if the severity is Error
            if ($null -ne $Script:LogBuffer -and ($Script:LogBuffer.Count -ge 20 -or $Severity -eq 'Error')) { Write-LogBuffer }
        }
        catch {
            Write-Warning -Message "Write-Log failed: $($PSItem.Exception.Message)"
        }
    }
}
