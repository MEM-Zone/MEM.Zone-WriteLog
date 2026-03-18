#Requires -Module Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/MEMZone.WriteLog/MEMZone.WriteLog.psd1'
    Import-Module -Name $ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name MEMZone.WriteLog -Force -ErrorAction SilentlyContinue
}

Describe 'Module: MEMZone.WriteLog' {

    Context 'Module Import' {

        It 'Should import without errors' {
            { Import-Module -Name (Join-Path $PSScriptRoot '../src/MEMZone.WriteLog/MEMZone.WriteLog.psd1') -Force } | Should -Not -Throw
        }

        It 'Should be loaded' {
            Get-Module -Name MEMZone.WriteLog | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Exported Functions' {

        BeforeAll {
            $ExpectedFunctions = @(
                'Initialize-WriteLog'
                'Test-LogFile'
                'Write-LogBuffer'
                'Write-Log'
                'Format-Message'
                'Write-FunctionHeaderOrFooter'
                'Invoke-WithAnimation'
                'Invoke-WithStatus'
            )
        }

        It "Should export '<_>'" -ForEach @(
            'Initialize-WriteLog'
            'Test-LogFile'
            'Write-LogBuffer'
            'Write-Log'
            'Format-Message'
            'Write-FunctionHeaderOrFooter'
            'Invoke-WithAnimation'
            'Invoke-WithStatus'
        ) {
            (Get-Command -Module MEMZone.WriteLog -Name $_ -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }

        It 'Should not export unexpected functions' {
            $ExportedCount = (Get-Command -Module MEMZone.WriteLog).Count
            $ExportedCount | Should -Be 8
        }
    }

    Context 'Function Help' {

        It "Should have help for '<_>'" -ForEach @(
            'Initialize-WriteLog'
            'Test-LogFile'
            'Write-LogBuffer'
            'Write-Log'
            'Format-Message'
            'Write-FunctionHeaderOrFooter'
            'Invoke-WithAnimation'
            'Invoke-WithStatus'
        ) {
            $Help = Get-Help -Name $_ -Full
            $Help.Synopsis | Should -Not -BeNullOrEmpty
            $Help.Description | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Initialize-WriteLog' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_Test_$([guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should initialize without errors' {
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath } | Should -Not -Throw
    }

    It 'Should create the log directory' {
        Test-Path -Path $TestLogPath -PathType Container | Should -BeTrue
    }

    It 'Should create the log file' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'TestLog.log'
        Test-Path -Path $LogFile -PathType Leaf | Should -BeTrue
    }

    It 'Should accept custom LogToConsole setting' {
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogToConsole $false } | Should -Not -Throw
    }

    It 'Should accept custom LogDebugMessages setting' {
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogDebugMessages $true } | Should -Not -Throw
    }

    It 'Should accept custom LogMaxSizeMB setting' {
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogMaxSizeMB 10 } | Should -Not -Throw
    }

    It 'Should reject LogMaxSizeMB outside valid range' {
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogMaxSizeMB 0 } | Should -Throw
        { Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogMaxSizeMB 101 } | Should -Throw
    }

    It 'Should reset the log buffer on re-initialization' {
        Write-Log -Message 'Before re-init' -SkipLogFormatting
        Initialize-WriteLog -LogName 'TestLog' -LogPath $TestLogPath -LogToConsole $false
        # Buffer should be empty after re-initialization (new ArrayList created)
        # Verify by flushing - should not add the old entry to the new log
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'TestLog.log'
        $ContentBefore = Get-Content -Path $LogFile -Raw
        Write-LogBuffer
        $ContentAfter = Get-Content -Path $LogFile -Raw
        $ContentAfter | Should -Not -Match 'Before re-init'
    }
}

Describe 'Write-Log' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_WriteLog_$([guid]::NewGuid().ToString('N'))"
        Initialize-WriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Basic Logging' {

        It 'Should write a message without error' {
            { Write-Log -Message 'Test message' -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should accept null messages' {
            { Write-Log -Message $null -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should accept empty string messages' {
            { Write-Log -Message '' -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should accept array of string messages' {
            { Write-Log -Message @('Line 1', 'Line 2') -SkipLogFormatting } | Should -Not -Throw
        }
    }

    Context 'Severity Levels' {

        It 'Should accept Information severity' {
            { Write-Log -Severity 'Information' -Message 'Info test' -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should accept Warning severity' {
            { Write-Log -Severity 'Warning' -Message 'Warning test' -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should accept Error severity' {
            { Write-Log -Severity 'Error' -Message 'Error test' -SkipLogFormatting } | Should -Not -Throw
        }

        It 'Should default to Information severity' {
            Write-Log -Message 'Default severity' -SkipLogFormatting
            Write-LogBuffer
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '\[Information\] Default severity'
        }
    }

    Context 'Buffer and Flush' {

        It 'Should write buffered entries to file on flush' {
            Write-Log -Message 'Flush test entry' -SkipLogFormatting
            Write-LogBuffer

            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Flush test entry'
        }

        It 'Should include timestamp in log entries' {
            Write-Log -Message 'Timestamp test' -SkipLogFormatting
            Write-LogBuffer

            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[Information\] Timestamp test'
        }

        It 'Should auto-flush when buffer reaches threshold of 20' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            # Clear the log file first
            Set-Content -Path $LogFile -Value '' -Force
            for ($i = 1; $i -le 21; $i++) {
                Write-Log -Message "Auto-flush line $i" -SkipLogFormatting
            }
            # The buffer should have auto-flushed at 20
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Auto-flush line 1'
        }

        It 'Should auto-flush on Error severity' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Severity 'Error' -Message 'Error auto-flush' -SkipLogFormatting
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Error auto-flush'
        }
    }

    Context 'Debug Messages' {

        It 'Should not log debug messages when LogDebugMessages is disabled' {
            Initialize-WriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false -LogDebugMessages $false
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Message 'Debug only' -DebugMessage -SkipLogFormatting
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Not -Match 'Debug only'
        }

        It 'Should log debug messages when LogDebugMessages is enabled' {
            Initialize-WriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false -LogDebugMessages $true
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Message 'Debug visible' -DebugMessage -SkipLogFormatting
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Debug visible'
        }

        It 'Should include source in debug log entry when provided' {
            Initialize-WriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false -LogDebugMessages $true
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Message 'Source test' -Source 'MyFunction' -DebugMessage -SkipLogFormatting
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '\[MyFunction\].*Source test'
        }
    }

    Context 'Formatting Integration' {

        BeforeAll {
            Initialize-WriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false
        }

        It 'Should default to Timeline format when no FormatOptions provided' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Message 'Timeline default'
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '- Timeline default'
        }

        It 'Should apply InlineHeader format via FormatOptions' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-Log -Message 'HEADER' -FormatOptions @{ Mode = 'InlineHeader' }
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '===\[ HEADER \]==='
        }
    }
}

Describe 'Write-LogBuffer' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_Buffer_$([guid]::NewGuid().ToString('N'))"
        Initialize-WriteLog -LogName 'BufferTest' -LogPath $TestLogPath -LogToConsole $false
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should not error when buffer is empty' {
        Write-LogBuffer  # Flush any existing entries
        { Write-LogBuffer } | Should -Not -Throw
    }

    It 'Should clear the buffer after flushing' {
        Write-Log -Message 'Buffer clear test' -SkipLogFormatting
        Write-LogBuffer
        # Second flush should not write anything new
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'BufferTest.log'
        $LinesBefore = @(Get-Content -Path $LogFile).Count
        Write-LogBuffer
        $LinesAfter = @(Get-Content -Path $LogFile).Count
        $LinesAfter | Should -Be $LinesBefore
    }

    It 'Should append multiple entries at once' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'BufferTest.log'
        Set-Content -Path $LogFile -Value '' -Force
        Write-Log -Message 'Entry A' -SkipLogFormatting
        Write-Log -Message 'Entry B' -SkipLogFormatting
        Write-Log -Message 'Entry C' -SkipLogFormatting
        Write-LogBuffer
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Entry A'
        $Content | Should -Match 'Entry B'
        $Content | Should -Match 'Entry C'
    }
}

Describe 'Format-Message' {

    Context 'Line Mode' {

        It 'Should return a separator line' {
            $Result = Format-Message -Message '' -FormatData @{ Mode = 'Line' }
            $Result | Should -Match '^=+$'
        }

        It 'Should return exactly 80 characters' {
            $Result = Format-Message -Message '' -FormatData @{ Mode = 'Line' }
            $Result[0].Length | Should -Be 80
        }
    }

    Context 'Block Mode' {

        It 'Should return 3 lines (separator, message, separator)' {
            $Result = Format-Message -Message 'Hello' -FormatData @{ Mode = 'Block' }
            $Result.Count | Should -Be 3
        }

        It 'Should include the message with arrow prefix' {
            $Result = Format-Message -Message 'Hello' -FormatData @{ Mode = 'Block' }
            $Result[1] | Should -Match 'Hello'
        }

        It 'Should truncate long messages with ellipsis' {
            $LongMessage = 'A' * 200
            $Result = Format-Message -Message $LongMessage -FormatData @{ Mode = 'Block' }
            $Result[1] | Should -Match '\.\.\.$'
            $Result[1].Length | Should -BeLessOrEqual 80
        }
    }

    Context 'CenteredBlock Mode' {

        It 'Should return 3 lines' {
            $Result = Format-Message -Message 'Center Me' -FormatData @{ Mode = 'CenteredBlock' }
            $Result.Count | Should -Be 3
        }

        It 'Should center the text' {
            $Result = Format-Message -Message 'Center Me' -FormatData @{ Mode = 'CenteredBlock' }
            $Result[1].Trim() | Should -Be 'Center Me'
            # The leading spaces should be roughly half of (80 - message length)
            $LeadingSpaces = $Result[1].Length - $Result[1].TrimStart().Length
            $LeadingSpaces | Should -BeGreaterThan 0
        }

        It 'Should truncate long messages' {
            $LongMessage = 'B' * 200
            $Result = Format-Message -Message $LongMessage -FormatData @{ Mode = 'CenteredBlock' }
            $Result[1].Trim() | Should -Match '\.\.\.$'
        }
    }

    Context 'InlineHeader Mode' {

        It 'Should format with === delimiters' {
            $Result = Format-Message -Message 'SECTION' -FormatData @{ Mode = 'InlineHeader' }
            $Result[0] | Should -BeLike '===*SECTION*==='
        }

        It 'Should truncate long headers' {
            $LongHeader = 'X' * 60
            $Result = Format-Message -Message $LongHeader -FormatData @{ Mode = 'InlineHeader' }
            $Result[0] | Should -Match '\.\.\.'
        }
    }

    Context 'InlineSubHeader Mode' {

        It 'Should format with --- delimiters' {
            $Result = Format-Message -Message 'subsection' -FormatData @{ Mode = 'InlineSubHeader' }
            $Result[0] | Should -BeLike '---*subsection*---'
        }
    }

    Context 'Timeline Mode' {

        It 'Should format with indented bullet' {
            $Result = Format-Message -Message 'Step done' -FormatData @{ Mode = 'Timeline' }
            $Result[0] | Should -Be '    - Step done'
        }
    }

    Context 'TimelineHeader Mode' {

        It 'Should format with indent but no bullet' {
            $Result = Format-Message -Message 'Header text' -FormatData @{ Mode = 'TimelineHeader' }
            $Result[0] | Should -Be '    Header text'
        }
    }

    Context 'List Mode' {

        It 'Should format ordered dictionary as key-value pairs' {
            $Data = [ordered]@{ Key1 = 'Value1'; Key2 = 'Value2' }
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'List' }
            ($Result -join "`n") | Should -Match 'Key1'
            ($Result -join "`n") | Should -Match 'Value1'
            ($Result -join "`n") | Should -Match 'Key2'
            ($Result -join "`n") | Should -Match 'Value2'
        }

        It 'Should format PSCustomObject as key-value pairs' {
            $Data = [PSCustomObject]@{ Name = 'Alice'; Age = 30 }
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'List' }
            ($Result -join "`n") | Should -Match 'Name'
            ($Result -join "`n") | Should -Match 'Alice'
        }

        It 'Should align keys with consistent padding' {
            $Data = [ordered]@{ ShortKey = 'A'; VeryLongKeyName = 'B' }
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'List' }
            # Both lines should have the colon at the same position
            $ColonPositions = $Result | ForEach-Object { $PSItem.IndexOf(':') }
            $ColonPositions[0] | Should -Be $ColonPositions[1]
        }

        It 'Should format array items as indented lines' {
            $Data = @('Item1', 'Item2', 'Item3')
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'List' }
            $Result.Count | Should -Be 3
            $Result[0] | Should -Match '^\s+Item1$'
        }
    }

    Context 'Table Mode' {

        It 'Should format a table from object data' {
            $Data = @(
                [PSCustomObject]@{ Name = 'Alice'; Age = 30 }
                [PSCustomObject]@{ Name = 'Bob';   Age = 25 }
            )
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; Title = 'People' }
            $Result | Should -Not -BeNullOrEmpty
            ($Result -join "`n") | Should -Match 'Alice'
            ($Result -join "`n") | Should -Match 'Bob'
        }

        It 'Should include the table title' {
            $Data = @([PSCustomObject]@{ Col = 'Val' })
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; Title = 'My Title' }
            ($Result -join "`n") | Should -Match 'My Title'
        }

        It 'Should show row numbers by default' {
            $Data = @(
                [PSCustomObject]@{ Name = 'Alice' }
                [PSCustomObject]@{ Name = 'Bob' }
            )
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'Table' }
            ($Result -join "`n") | Should -Match '#'
            ($Result -join "`n") | Should -Match '1'
            ($Result -join "`n") | Should -Match '2'
        }

        It 'Should hide row numbers when ShowRowNumbers is false' {
            $Data = @([PSCustomObject]@{ Name = 'Alice' })
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; ShowRowNumbers = $false }
            $HeaderLine = $Result | Where-Object { $PSItem -match '\| Name' }
            $HeaderLine | Should -Not -Match '\| #'
        }

        It 'Should apply cell padding' {
            $Data = @([PSCustomObject]@{ Name = 'Alice' })
            $NoPad = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; CellPadding = 0 }
            $WithPad = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; CellPadding = 2 }
            $NoPadWidth = ($NoPad | Where-Object { $PSItem -match '\| ' } | Select-Object -First 1).TrimEnd().Length
            $WithPadWidth = ($WithPad | Where-Object { $PSItem -match '\| ' } | Select-Object -First 1).TrimEnd().Length
            $WithPadWidth | Should -BeGreaterThan $NoPadWidth
        }

        It 'Should use custom headers via NewHeaders' {
            $Data = @([PSCustomObject]@{ FirstName = 'Alice'; LastName = 'Smith' })
            $Result = Format-Message -Message $Data -FormatData @{
                Mode       = 'Table'
                NewHeaders = [ordered]@{ 'Name' = 'FirstName'; 'Surname' = 'LastName' }
            }
            ($Result -join "`n") | Should -Match 'Name'
            ($Result -join "`n") | Should -Match 'Surname'
            ($Result -join "`n") | Should -Match 'Alice'
            ($Result -join "`n") | Should -Match 'Smith'
        }

        It 'Should display footer when specified' {
            $Data = @([PSCustomObject]@{ Name = 'Alice' })
            $Result = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; Footer = 'End of data' }
            ($Result -join "`n") | Should -Match 'End of data'
        }

        It 'Should add vertical padding' {
            $Data = @([PSCustomObject]@{ Name = 'Alice' })
            $NoPad = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; VerticalPadding = 0 }
            $WithPad = Format-Message -Message $Data -FormatData @{ Mode = 'Table'; VerticalPadding = 2 }
            $WithPad.Count | Should -BeGreaterThan $NoPad.Count
        }

        It 'Should handle null or empty data gracefully' {
            { Format-Message -Message $null -FormatData @{ Mode = 'Table' } } | Should -Not -Throw
            { Format-Message -Message @() -FormatData @{ Mode = 'Table' } } | Should -Not -Throw
        }
    }

    Context 'Default Mode' {

        It 'Should return trimmed message' {
            $Result = Format-Message -Message '  Hello World  ' -FormatData @{ Mode = 'Default' }
            $Result[0] | Should -Be 'Hello World'
        }

        It 'Should use Default mode when no mode specified' {
            $Result = Format-Message -Message 'No mode'
            $Result[0] | Should -Be 'No mode'
        }
    }

    Context 'AddEmptyRow' {

        It 'Should add empty row before' {
            $Result = Format-Message -Message 'Test' -FormatData @{ Mode = 'Timeline'; AddEmptyRow = 'Before' }
            $Result[0] | Should -Be ''
            $Result[1] | Should -Match 'Test'
        }

        It 'Should add empty row after' {
            $Result = Format-Message -Message 'Test' -FormatData @{ Mode = 'Timeline'; AddEmptyRow = 'After' }
            $Result[-1] | Should -Be ''
        }

        It 'Should add empty rows before and after' {
            $Result = Format-Message -Message 'Test' -FormatData @{ Mode = 'Timeline'; AddEmptyRow = 'BeforeAndAfter' }
            $Result[0] | Should -Be ''
            $Result[-1] | Should -Be ''
        }

        It 'Should not add empty rows for No' {
            $Result = Format-Message -Message 'Test' -FormatData @{ Mode = 'Timeline'; AddEmptyRow = 'No' }
            $Result[0] | Should -Not -Be ''
        }
    }

    Context 'Null Message Handling' {

        It 'Should handle null message without error' {
            { Format-Message -Message $null -FormatData @{ Mode = 'Timeline' } } | Should -Not -Throw
        }
    }
}

Describe 'Test-LogFile' {

    BeforeAll {
        $TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_TestLogFile_$([guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        if (Test-Path -Path $TestDir) {
            Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Directory and File Creation' {

        It 'Should create directory and file if they do not exist' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'test.log'
            Test-LogFile -LogFile $LogFile -MaxSizeMB 5
            Test-Path -Path $LogFile | Should -BeTrue
        }

        It 'Should not error when directory already exists' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'test.log'
            { Test-LogFile -LogFile $LogFile -MaxSizeMB 5 } | Should -Not -Throw
        }

        It 'Should not error when file already exists' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'existing.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            { Test-LogFile -LogFile $LogFile -MaxSizeMB 5 } | Should -Not -Throw
        }
    }

    Context 'Log Rotation' {

        It 'Should rotate log file when it exceeds max size' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'rotate.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            $LargeContent = 'x' * (6MB)
            Set-Content -Path $LogFile -Value $LargeContent -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'rotated'
        }

        It 'Should archive the old log file on rotation' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'archive.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            $LargeContent = 'x' * (6MB)
            Set-Content -Path $LogFile -Value $LargeContent -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            $ArchivedFiles = Get-ChildItem -Path $TestDir -Filter 'archive_*.log'
            $ArchivedFiles | Should -Not -BeNullOrEmpty
        }

        It 'Should preserve archived file content' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'preserve.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            $OriginalContent = 'Original log content' + ('x' * (6MB))
            Set-Content -Path $LogFile -Value $OriginalContent -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            $ArchivedFile = Get-ChildItem -Path $TestDir -Filter 'preserve_*.log' | Select-Object -First 1
            $ArchivedFile | Should -Not -BeNullOrEmpty
            $ArchivedContent = Get-Content -Path $ArchivedFile.FullName -Raw
            $ArchivedContent | Should -Match 'Original log content'
        }

        It 'Should create a fresh log file after rotation' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'fresh.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            $LargeContent = 'x' * (6MB)
            Set-Content -Path $LogFile -Value $LargeContent -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            Test-Path -Path $LogFile | Should -BeTrue
            $NewContent = Get-Content -Path $LogFile -Raw
            $NewContent | Should -Match 'rotated'
            # The fresh file should be much smaller than the original
            (Get-Item -Path $LogFile).Length | Should -BeLessThan 1MB
        }

        It 'Should include archive filename in rotation message' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'refmsg.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            Set-Content -Path $LogFile -Value ('x' * (6MB)) -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'archived to \[refmsg_\d{8}-\d{6}\.log\]'
        }

        It 'Should not rotate when file is under size limit' {
            $LogFile = Join-Path -Path $TestDir -ChildPath 'small.log'
            $null = New-Item -Path $LogFile -ItemType File -Force
            Set-Content -Path $LogFile -Value 'Small content' -Encoding UTF8

            Test-LogFile -LogFile $LogFile -MaxSizeMB 5

            $ArchivedFiles = Get-ChildItem -Path $TestDir -Filter 'small_*.log' -ErrorAction SilentlyContinue
            $ArchivedFiles | Should -BeNullOrEmpty
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Small content'
        }
    }
}

Describe 'Write-FunctionHeaderOrFooter' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_FHF_$([guid]::NewGuid().ToString('N'))"
        Initialize-WriteLog -LogName 'FHFTest' -LogPath $TestLogPath -LogToConsole $false -LogDebugMessages $true
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Header' {

        It 'Should write header without error' {
            { Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{} -Header } | Should -Not -Throw
        }

        It 'Should log Function Start message' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{} -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Function Start'
        }

        It 'Should log bound parameters' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{ Name = 'TestValue'; Count = 42 } -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'bound parameter'
            $Content | Should -Match 'Name'
            $Content | Should -Match 'TestValue'
        }

        It 'Should indicate when no parameters are bound' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{} -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'without any bound parameters'
        }

        It 'Should handle array parameter values' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{ Items = @('A', 'B', 'C') } -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Items'
            $Content | Should -Match 'A'
        }

        It 'Should handle hashtable parameter values' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{ Options = @{ Key1 = 'Val1' } } -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '@\{Key1\}'
        }

        It 'Should mask SecureString values' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            $Secure = ConvertTo-SecureString 'Secret123' -AsPlainText -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{ Password = $Secure } -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '<SecureString>'
            $Content | Should -Not -Match 'Secret123'
        }

        It 'Should truncate long string values' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            $LongValue = 'A' * 200
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{ Data = $LongValue } -Header
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match '\.\.\.'
        }
    }

    Context 'Footer' {

        It 'Should write footer without error' {
            { Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -Footer } | Should -Not -Throw
        }

        It 'Should log Function End message' {
            $LogFile = Join-Path -Path $TestLogPath -ChildPath 'FHFTest.log'
            Set-Content -Path $LogFile -Value '' -Force
            Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -Footer
            Write-LogBuffer
            $Content = Get-Content -Path $LogFile -Raw
            $Content | Should -Match 'Function End'
        }
    }
}

Describe 'Invoke-WithAnimation' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_Anim_$([guid]::NewGuid().ToString('N'))"
        Initialize-WriteLog -LogName 'AnimTest' -LogPath $TestLogPath -LogToConsole $false
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should execute scriptblock and return result (no console)' {
        $Result = Invoke-WithAnimation -Message 'Test' -ScriptBlock { 42 }
        $Result | Should -Be 42
    }

    It 'Should return complex objects' {
        $Result = Invoke-WithAnimation -Message 'Test' -ScriptBlock {
            [PSCustomObject]@{ Name = 'Alice'; Age = 30 }
        }
        $Result.Name | Should -Be 'Alice'
    }

    It 'Should throw on scriptblock failure' {
        { Invoke-WithAnimation -Message 'Fail' -ScriptBlock { throw 'Test error' } } | Should -Throw
    }

    It 'Should log successful operations' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'AnimTest.log'
        Set-Content -Path $LogFile -Value '' -Force
        Invoke-WithAnimation -Message 'Success op' -ScriptBlock { 'done' }
        Write-LogBuffer
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Success op'
    }

    It 'Should log message even when operation fails' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'AnimTest.log'
        Set-Content -Path $LogFile -Value '' -Force
        try { Invoke-WithAnimation -Message 'Fail op' -ScriptBlock { throw 'boom' } } catch { }
        Write-LogBuffer
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Fail op'
    }

    It 'Should accept all animation styles without error' {
        foreach ($Style in @('Spinner', 'Dots', 'Braille', 'Bounce', 'Box')) {
            { Invoke-WithAnimation -Message "Test $Style" -ScriptBlock { 1 } -Animation $Style } | Should -Not -Throw
        }
    }
}

Describe 'Invoke-WithStatus' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "WriteLog_Status_$([guid]::NewGuid().ToString('N'))"
        Initialize-WriteLog -LogName 'StatusTest' -LogPath $TestLogPath -LogToConsole $false
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should execute scriptblock and return result' {
        $Result = Invoke-WithStatus -Message 'Test' -ScriptBlock { 'hello' }
        $Result | Should -Be 'hello'
    }

    It 'Should return complex objects' {
        $Result = Invoke-WithStatus -Message 'Test' -ScriptBlock {
            @(1, 2, 3)
        }
        $Result.Count | Should -Be 3
    }

    It 'Should throw on scriptblock failure' {
        { Invoke-WithStatus -Message 'Fail' -ScriptBlock { throw 'Test error' } } | Should -Throw
    }

    It 'Should log successful operations' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'StatusTest.log'
        Set-Content -Path $LogFile -Value '' -Force
        Invoke-WithStatus -Message 'Status success' -ScriptBlock { 'ok' }
        Write-LogBuffer
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Status success'
    }

    It 'Should log message even when operation fails' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'StatusTest.log'
        Set-Content -Path $LogFile -Value '' -Force
        try { Invoke-WithStatus -Message 'Status fail' -ScriptBlock { throw 'kaboom' } } catch { }
        Write-LogBuffer
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Status fail'
    }

    It 'Should execute in the current session (not a runspace)' {
        # Set a variable in current scope, verify the scriptblock can access it
        $TestVar = 'CurrentSessionValue'
        $Result = Invoke-WithStatus -Message 'Session test' -ScriptBlock { $TestVar }
        $Result | Should -Be 'CurrentSessionValue'
    }
}
