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
.LINK
    https://MEM.Zone
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

            switch ($Mode) {
                'Line' {
                    $OutputLines = @($Separator)
                }
                'Block' {
                    [string]$Prefix = [char]0x25B6 + ' '
                    [int]$MaxMessageLength = $LineWidth - $Prefix.Length
                    [string]$FormattedMessage = $Prefix + $Message.ToString().Trim()
                    if ($FormattedMessage.Length -gt $LineWidth) {
                        $FormattedMessage = $Prefix + $Message.ToString().Trim().Substring(0, $MaxMessageLength - 3) + '...'
                    }
                    $OutputLines = @($Separator, $FormattedMessage, $Separator)
                }
                'CenteredBlock' {
                    [string]$CleanMessage = $Message.ToString().Trim()
                    if ($CleanMessage.Length -gt ($LineWidth - 4)) {
                        $CleanMessage = $CleanMessage.Substring(0, $LineWidth - 7) + '...'
                    }
                    [int]$ContentWidth = $CleanMessage.Length
                    [int]$SidePadding = [math]::Floor(($LineWidth - $ContentWidth) / 2)
                    [string]$CenteredLine = $CleanMessage.PadLeft($ContentWidth + $SidePadding).PadRight($LineWidth)
                    $OutputLines = @($Separator, $CenteredLine, $Separator)
                }
                'InlineHeader' {
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    $OutputLines = @("===[ $Trimmed ]===")
                }
                'InlineSubHeader' {
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    $OutputLines = @("---[ $Trimmed ]---")
                }
                'Table' {
                    if ($null -eq $Message -or @($Message).Count -eq 0) { $Message = @(' ') }
                    $OutputLines = @()
                    if ($null -eq $NewHeaders -or @($NewHeaders).Count -eq 0) {
                        $FirstObject = $Message[0]
                        $Headers = @($FirstObject.PSObject.Properties.Name)
                        $UseNewHeaders = $false
                    }
                    else {
                        $Headers = @($NewHeaders.Keys)
                        $UseNewHeaders = $true
                    }
                    if ($ShowRowNumbers) { $Headers = @('#') + $Headers }
                    if ($null -eq $ColumnWidths -or @($ColumnWidths).Count -eq 0) {
                        $ColumnWidths = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            $MaxWidth = $Headers[$Counter].Length
                            if ($ShowRowNumbers -and $Counter -eq 0) {
                                $MaxWidth = [Math]::Max($MaxWidth, @($Message).Count.ToString().Length)
                            }
                            else {
                                foreach ($Row in $Message) {
                                    $ActualHeader = $Headers[$Counter]
                                    $Value = if ($UseNewHeaders) { $Row.($NewHeaders[$ActualHeader]) } else { $Row.($ActualHeader) }
                                    if ($null -ne $Value) { $MaxWidth = [Math]::Max($MaxWidth, $Value.ToString().Length) }
                                }
                            }
                            $ColumnWidths += $MaxWidth
                        }
                    }
                    $FormatString = '| '
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        $PaddedWidth = $ColumnWidths[$Counter] + ($CellPadding * 2)
                        $FormatString += "{$Counter,-$PaddedWidth} | "
                    }
                    $HeaderData = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        if ($CellPadding -gt 0) { $HeaderData += (' ' * $CellPadding) + $Headers[$Counter] + (' ' * $CellPadding) }
                        else { $HeaderData += $Headers[$Counter] }
                    }
                    $HeaderLine = $FormatString -f $HeaderData
                    [int]$TableWidth = $HeaderLine.TrimEnd().Length
                    [int]$TitlePadding = [Math]::Max(0, [Math]::Floor(($TableWidth - $Title.Length) / 2))
                    $OutputLines += (' ' * $TitlePadding) + $Title
                    $OutputLines += ''
                    if ($VerticalPadding -gt 0) { for ($i = 0; $i -lt $VerticalPadding; $i++) { $OutputLines += '' } }
                    $OutputLines += $HeaderLine
                    $SeparatorParts = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        $SeparatorText = '-' * $ColumnWidths[$Counter]
                        if ($CellPadding -gt 0) { $SeparatorParts += (' ' * $CellPadding) + $SeparatorText + (' ' * $CellPadding) }
                        else { $SeparatorParts += $SeparatorText }
                    }
                    $OutputLines += ($FormatString -f $SeparatorParts)
                    [int]$RowNumber = 0
                    foreach ($Row in $Message) {
                        $RowNumber++
                        $RowData = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            if ($ShowRowNumbers -and $Counter -eq 0) { $FormattedValue = $RowNumber.ToString() }
                            else {
                                $Value = if ($UseNewHeaders) { $Row.($NewHeaders[$Headers[$Counter]]) } else { $Row.($Headers[$Counter]) }
                                $FormattedValue = if ($null -eq $Value) { '' } else { $Value.ToString() }
                            }
                            if ($CellPadding -gt 0) { $RowData += (' ' * $CellPadding) + $FormattedValue + (' ' * $CellPadding) }
                            else { $RowData += $FormattedValue }
                        }
                        $OutputLines += ($FormatString -f $RowData)
                    }
                    if ($VerticalPadding -gt 0) { for ($i = 0; $i -lt $VerticalPadding; $i++) { $OutputLines += '' } }
                    if (-not [string]::IsNullOrEmpty($Footer)) {
                        [string]$LastDataLine = $OutputLines[$OutputLines.Count - 1]
                        [int]$TableWidth = $LastDataLine.TrimEnd().Length
                        $OutputLines += ' ' + ('-' * ($TableWidth - 2))
                        [int]$FooterPadding = [Math]::Max(0, [Math]::Floor(($TableWidth - $Footer.Length) / 2))
                        $OutputLines += (' ' * $FooterPadding) + $Footer
                    }
                }
                'Timeline'       { $OutputLines = @("    - $($Message.ToString())") }
                'TimelineHeader' { $OutputLines = @("    $($Message.ToString())") }
                'List' {
                    $OutputLines = @()
                    if ($Message -is [System.Collections.Specialized.OrderedDictionary] -or $Message -is [hashtable]) {
                        $MaxKeyLength = ($Message.Keys | ForEach-Object { $PSItem.ToString().Length } | Measure-Object -Maximum).Maximum
                        foreach ($Entry in $Message.GetEnumerator()) {
                            $OutputLines += "    $($Entry.Key.ToString().PadRight($MaxKeyLength)) : $($Entry.Value)"
                        }
                    }
                    elseif ($Message -is [PSCustomObject]) {
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
                Default { $OutputLines = @($Message.ToString().Trim()) }
            }

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
