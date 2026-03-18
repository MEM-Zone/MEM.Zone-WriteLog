function Format-Message {
<#
.SYNOPSIS
    Formats a text header or table.
.DESCRIPTION
    Formats a header block, centered block, section header, sub-header, inline log, table, or adds separator rows.
.PARAMETER Message
    Specifies the message or data to display. For tables, this contains the data to format.
.PARAMETER FormatData
    Specifies the formatting options as a hashtable:
    - Mode:
        - 'Block'
        - 'CenteredBlock'
        - 'Line'
        - 'InlineHeader'
        - 'InlineSubHeader'
        - 'Timeline'
        - 'TimelineHeader'
        - 'List'
        - 'Table'
            - Title          : Table title. Default is: 'Data Table'.
            - Footer         : Table footer text displayed below the table. Default is: $null.
            - NewHeaders     : Mapping of display headers to property names. Default is: (Auto-Detected).
            - ColumnWidths   : Custom column widths. Default is: 0.
            - CellPadding    : Amount of horizontal padding to add within cells. Default is: 0.
            - VerticalPadding: Amount of padding to add above and below the table. Default is: 0.
            - ShowRowNumbers : Whether to show row numbers as the first column. Default is: $true.
    Default is: 'Timeline'.
    - AddEmptyRow:
        - 'No'
        - 'Before'
        - 'After'
        - 'BeforeAndAfter'
        Default is: 'No'.
.EXAMPLE
    Format-Message -Message 'IMPORT APPLICATION' -FormatData @{ Mode = 'InlineHeader' }
.EXAMPLE
    Format-Message -Message $Data -FormatData @{
        Mode             = 'Table'
        Title            = 'MEM.Zone'
        NewHeaders       = [ordered]@{
            'Location'   = 'City'
            'Status'     = 'OperationStatus'
            'Compliance' = 'ComplianceStatus'
        }
        CellPadding      = 1
        VerticalPadding  = 1
        AddEmptyRow      = 'BeforeAndAfter'
    }
.INPUTS
    System.Object
    System.Collections.Hashtable
.OUTPUTS
    System.String[]
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
    Message Formatting
#>
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object]$Message,

        [Parameter(Position = 1)]
        [hashtable]$FormatData = @{}
    )

    begin {

        ## Initialize variables
        If ($null -eq $Message) { $Message = @() }
        [int]$LineWidth        = 80
        [string]$Separator     = '=' * $LineWidth
        [string[]]$OutputLines = @()
        $Mode            = if ($FormatData.ContainsKey('Mode'))            { $FormatData['Mode']            } else { 'Default'    }
        $AddEmptyRow     = if ($FormatData.ContainsKey('AddEmptyRow'))     { $FormatData['AddEmptyRow']     } else { 'No'         }
        $Title           = if ($FormatData.ContainsKey('Title'))           { $FormatData['Title']           } else { 'Data Table' }
        $Footer          = if ($FormatData.ContainsKey('Footer'))          { $FormatData['Footer']          } else { $null        }
        $NewHeaders      = if ($FormatData.ContainsKey('NewHeaders'))      { $FormatData['NewHeaders']      } else { $null        }
        $ColumnWidths    = if ($FormatData.ContainsKey('ColumnWidths'))    { $FormatData['ColumnWidths']    } else { @()          }
        $CellPadding     = if ($FormatData.ContainsKey('CellPadding'))     { $FormatData['CellPadding']     } else { 0            }
        $VerticalPadding = if ($FormatData.ContainsKey('VerticalPadding')) { $FormatData['VerticalPadding'] } else { 0            }
        $ShowRowNumbers  = if ($FormatData.ContainsKey('ShowRowNumbers'))  { $FormatData['ShowRowNumbers']  } else { $true        }
    }

    process {
        try {

            ## Format the message based on the specified mode
            switch ($Mode) {

                ## LINE MODE
                'Line' {
                    $OutputLines = @($Separator)
                }

                ## BLOCK MODE
                'Block' {
                    #  Add prefix and format the message
                    [string]$Prefix = [char]0x25B6 + ' '
                    [int]$MaxMessageLength = $LineWidth - $Prefix.Length
                    [string]$FormattedMessage = $Prefix + $Message.ToString().Trim()
                    #  Truncate message if it exceeds the maximum length
                    if ($FormattedMessage.Length -gt $LineWidth) {
                        $FormattedMessage = $Prefix + $Message.ToString().Trim().Substring(0, $MaxMessageLength - 3) + '...'
                    }
                    #  Add separator lines
                    $OutputLines = @($Separator, $FormattedMessage, $Separator)
                }

                ## CENTERED BLOCK MODE
                'CenteredBlock' {
                    #  Trim message
                    [string]$CleanMessage = $Message.ToString().Trim()
                    #  Truncate message if it exceeds the maximum length
                    if ($CleanMessage.Length -gt ($LineWidth - 4)) {
                        $CleanMessage = $CleanMessage.Substring(0, $LineWidth - 7) + '...'
                    }
                    #  Center the message
                    [int]$ContentWidth = $CleanMessage.Length
                    [int]$SidePadding = [math]::Floor(($LineWidth - $ContentWidth) / 2)
                    [string]$CenteredLine = $CleanMessage.PadLeft($ContentWidth + $SidePadding).PadRight($LineWidth)
                    #  Add separator lines
                    $OutputLines = @($Separator, $CenteredLine, $Separator)
                }

                ## INLINE HEADER MODE
                'InlineHeader' {
                    #  Trim and truncate message
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    #  Add padding to the message
                    $OutputLines = @("===[ $Trimmed ]===")
                }

                ## INLINE SUBHEADER MODE
                'InlineSubHeader' {
                    #  Trim and truncate message
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    #  Add padding to the message
                    $OutputLines = @("---[ $Trimmed ]---")
                }

                ## TABLE MODE
                'Table' {
                    #  Set empty message to a single space if no data is provided
                    if ($null -eq $Message -or @($Message).Count -eq 0) { $Message = @(' ') }
                    #  Initialize output (title added later after calculating table width)
                    $OutputLines = @()
                    #  Determine headers
                    if ($null -eq $NewHeaders -or @($NewHeaders).Count -eq 0) {
                        $FirstObject = $Message[0]
                        $Headers = @($FirstObject.PSObject.Properties.Name)
                        $UseNewHeaders = $false
                    }
                    else {
                        #  Use the keys from NewHeaders as our display headers
                        $Headers = @($NewHeaders.Keys)
                        $UseNewHeaders = $true
                    }
                    #  Add row number column if enabled
                    if ($ShowRowNumbers) { $Headers = @('#') + $Headers }
                    #  Calculate column widths if not provided
                    if ($null -eq $ColumnWidths -or @($ColumnWidths).Count -eq 0) {
                        $ColumnWidths = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            #  Get the header width
                            $MaxWidth = $Headers[$Counter].Length
                            #  Handle row number column separately
                            if ($ShowRowNumbers -and $Counter -eq 0) {
                                #  Width based on max row number length
                                $MaxWidth = [Math]::Max($MaxWidth, @($Message).Count.ToString().Length)
                            }
                            else {
                                #  Check each row's value width
                                foreach ($Row in $Message) {
                                    $ActualHeader = $Headers[$Counter]
                                    $Value = if ($UseNewHeaders) { $Row.($NewHeaders[$ActualHeader]) } else { $Row.($ActualHeader) }
                                    if ($null -ne $Value) { $MaxWidth = [Math]::Max($MaxWidth, $Value.ToString().Length) }
                                }
                            }
                            $ColumnWidths += $MaxWidth
                        }
                    }
                    #  Create the format string for consistent column alignment
                    $FormatString = '| '
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        #  Apply padding to column width
                        $PaddedWidth = $ColumnWidths[$Counter] + ($CellPadding * 2)
                        $FormatString += "{$Counter,-$PaddedWidth} | "
                    }
                    #  Add the header row
                    $HeaderData = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        #  Add padding to header text if requested
                        if ($CellPadding -gt 0) { $HeaderData += (' ' * $CellPadding) + $Headers[$Counter] + (' ' * $CellPadding) }
                        else { $HeaderData += $Headers[$Counter] }
                    }
                    $HeaderLine = $FormatString -f $HeaderData
                    #  Calculate table width and create centered title
                    [int]$TableWidth = $HeaderLine.TrimEnd().Length
                    [int]$TitlePadding = [Math]::Max(0, [Math]::Floor(($TableWidth - $Title.Length) / 2))
                    $OutputLines += (' ' * $TitlePadding) + $Title
                    $OutputLines += ''
                    #  Add vertical padding above the table
                    if ($VerticalPadding -gt 0) { for ($i = 0; $i -lt $VerticalPadding; $i++) { $OutputLines += '' } }
                    $OutputLines += $HeaderLine
                    #  Add a separator line
                    $SeparatorParts = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        #  Create padded separator for each column
                        $SeparatorText = '-' * $ColumnWidths[$Counter]
                        if ($CellPadding -gt 0) { $SeparatorParts += (' ' * $CellPadding) + $SeparatorText + (' ' * $CellPadding) }
                        else { $SeparatorParts += $SeparatorText }
                    }
                    $OutputLines += ($FormatString -f $SeparatorParts)
                    #  Add data rows
                    [int]$RowNumber = 0
                    foreach ($Row in $Message) {
                        $RowNumber++
                        $RowData = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            #  Handle row number column
                            if ($ShowRowNumbers -and $Counter -eq 0) { $FormattedValue = $RowNumber.ToString() }
                            else {
                                #  Get the value using the appropriate property name
                                $Value = if ($UseNewHeaders) { $Row.($NewHeaders[$Headers[$Counter]]) } else { $Row.($Headers[$Counter]) }
                                #  Format the value
                                $FormattedValue = if ($null -eq $Value) { '' } else { $Value.ToString() }
                            }
                            #  Add padding if requested
                            if ($CellPadding -gt 0) { $RowData += (' ' * $CellPadding) + $FormattedValue + (' ' * $CellPadding) }
                            else { $RowData += $FormattedValue }
                        }
                        $OutputLines += ($FormatString -f $RowData)
                    }
                    #  Add vertical padding below the table
                    if ($VerticalPadding -gt 0) { for ($i = 0; $i -lt $VerticalPadding; $i++) { $OutputLines += '' } }
                    #  Add footer if specified (divider line, content below)
                    if (-not [string]::IsNullOrEmpty($Footer)) {
                        [string]$LastDataLine = $OutputLines[$OutputLines.Count - 1]
                        [int]$TableWidth = $LastDataLine.TrimEnd().Length
                        $OutputLines += ' ' + ('-' * ($TableWidth - 2))
                        [int]$FooterPadding = [Math]::Max(0, [Math]::Floor(($TableWidth - $Footer.Length) / 2))
                        $OutputLines += (' ' * $FooterPadding) + $Footer
                    }
                }

                ## TIMELINE MODE
                'Timeline' {
                    #  Add prefix to the message
                    $OutputLines = @("    - $($Message.ToString())")
                }

                ## TIMELINE HEADER MODE
                'TimelineHeader' {
                    #  Add prefix to the message
                    $OutputLines = @("    $($Message.ToString())")
                }

                ## LIST MODE
                'List' {
                    #  Format key-value pairs with consistent width
                    $OutputLines = @()
                    if ($Message -is [System.Collections.Specialized.OrderedDictionary] -or $Message -is [hashtable]) {
                        #  Calculate max key length for alignment
                        $MaxKeyLength = ($Message.Keys | ForEach-Object { $PSItem.ToString().Length } | Measure-Object -Maximum).Maximum
                        foreach ($Entry in $Message.GetEnumerator()) {
                            $OutputLines += "    $($Entry.Key.ToString().PadRight($MaxKeyLength)) : $($Entry.Value)"
                        }
                    }
                    elseif ($Message -is [PSCustomObject]) {
                        #  Calculate max property name length for alignment
                        $MaxKeyLength = ($Message.PSObject.Properties.Name | ForEach-Object { $PSItem.Length } | Measure-Object -Maximum).Maximum
                        foreach ($Property in $Message.PSObject.Properties) {
                            $OutputLines += "    $($Property.Name.PadRight($MaxKeyLength)) : $($Property.Value)"
                        }
                    }
                    elseif ($Message -is [array]) {
                        foreach ($Item in $Message) { $OutputLines += "    $($Item.ToString())" }
                    }
                    else { $OutputLines += "    $($Message.ToString())" }
                }

                ## DEFAULT MODE
                Default {
                    #  Just return the trimmed message
                    $OutputLines = @($Message.ToString().Trim())
                }
            }

            ## Add spacing if requested
            switch ($AddEmptyRow) {
                'Before'         { $OutputLines = @('') + $OutputLines }
                'After'          { $OutputLines += '' }
                'BeforeAndAfter' { $OutputLines = @('') + $OutputLines + @('') }
            }
        }
        catch {
            Write-Warning -Message "Error in Format-Message: $($PSItem.Exception.Message)"
            $OutputLines = @($Message.ToString().Trim())
        }
        finally {
            Write-Output -InputObject $OutputLines -NoEnumerate
        }
    }
}
