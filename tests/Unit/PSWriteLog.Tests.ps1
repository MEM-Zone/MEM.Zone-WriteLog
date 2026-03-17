#Requires -Module Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '../../src/PSWriteLog/PSWriteLog.psd1'
    Import-Module -Name $ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name PSWriteLog -Force -ErrorAction SilentlyContinue
}

Describe 'Module: PSWriteLog' {

    Context 'Module Import' {

        It 'Should import without errors' {
            { Import-Module -Name (Join-Path $PSScriptRoot '../../src/PSWriteLog/PSWriteLog.psd1') -Force } | Should -Not -Throw
        }

        It 'Should be loaded' {
            Get-Module -Name PSWriteLog | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Exported Functions' {

        $ExpectedFunctions = @(
            'Initialize-PSWriteLog'
            'Test-LogFile'
            'Write-LogBuffer'
            'Write-Log'
            'Format-Message'
            'Write-FunctionHeaderOrFooter'
            'Invoke-WithAnimation'
            'Invoke-WithStatus'
        )

        foreach ($FunctionName in $ExpectedFunctions) {
            It "Should export '$FunctionName'" {
                (Get-Command -Module PSWriteLog -Name $FunctionName -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should not export unexpected functions' {
            $ExportedCount = (Get-Command -Module PSWriteLog).Count
            $ExportedCount | Should -Be $ExpectedFunctions.Count
        }
    }

    Context 'Function Help' {

        $ExportedFunctions = Get-Command -Module PSWriteLog -CommandType Function

        foreach ($Function in $ExportedFunctions) {
            It "Should have help for '$($Function.Name)'" {
                $Help = Get-Help -Name $Function.Name -Full
                $Help.Synopsis | Should -Not -BeNullOrEmpty
                $Help.Description | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Initialize-PSWriteLog' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSWriteLog_Test_$([guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should initialize without errors' {
        { Initialize-PSWriteLog -LogName 'TestLog' -LogPath $TestLogPath } | Should -Not -Throw
    }

    It 'Should create the log directory' {
        Test-Path -Path $TestLogPath -PathType Container | Should -BeTrue
    }

    It 'Should create the log file' {
        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'TestLog.log'
        Test-Path -Path $LogFile -PathType Leaf | Should -BeTrue
    }
}

Describe 'Write-Log' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSWriteLog_Test_$([guid]::NewGuid().ToString('N'))"
        Initialize-PSWriteLog -LogName 'WriteLogTest' -LogPath $TestLogPath -LogToConsole $false
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should write a message without error' {
        { Write-Log -Message 'Test message' -SkipLogFormatting } | Should -Not -Throw
    }

    It 'Should accept null messages' {
        { Write-Log -Message $null -SkipLogFormatting } | Should -Not -Throw
    }

    It 'Should accept severity levels' {
        { Write-Log -Severity 'Warning' -Message 'Warning test' -SkipLogFormatting } | Should -Not -Throw
    }

    It 'Should write buffered entries to file on flush' {
        Write-Log -Message 'Flush test' -SkipLogFormatting
        Write-LogBuffer

        $LogFile = Join-Path -Path $TestLogPath -ChildPath 'WriteLogTest.log'
        $Content = Get-Content -Path $LogFile -Raw
        $Content | Should -Match 'Flush test'
    }
}

Describe 'Format-Message' {

    It 'Should return a separator line for Line mode' {
        $Result = Format-Message -Message '' -FormatData @{ Mode = 'Line' }
        $Result | Should -Match '^=+$'
    }

    It 'Should return a block for Block mode' {
        $Result = Format-Message -Message 'Hello' -FormatData @{ Mode = 'Block' }
        $Result.Count | Should -Be 3
    }

    It 'Should center text for CenteredBlock mode' {
        $Result = Format-Message -Message 'Center Me' -FormatData @{ Mode = 'CenteredBlock' }
        $Result.Count | Should -Be 3
        $Result[1].Trim() | Should -Be 'Center Me'
    }

    It 'Should format InlineHeader' {
        $Result = Format-Message -Message 'SECTION' -FormatData @{ Mode = 'InlineHeader' }
        $Result[0] | Should -BeLike '===*SECTION*==='
    }

    It 'Should format Timeline' {
        $Result = Format-Message -Message 'Step done' -FormatData @{ Mode = 'Timeline' }
        $Result[0] | Should -BeLike '*- Step done'
    }

    It 'Should add empty row before when requested' {
        $Result = Format-Message -Message 'Test' -FormatData @{ Mode = 'Timeline'; AddEmptyRow = 'Before' }
        $Result[0] | Should -Be ''
    }

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

    It 'Should format a List from hashtable' {
        $Data = [ordered]@{ Key1 = 'Value1'; Key2 = 'Value2' }
        $Result = Format-Message -Message $Data -FormatData @{ Mode = 'List' }
        ($Result -join "`n") | Should -Match 'Key1'
        ($Result -join "`n") | Should -Match 'Value1'
    }
}

Describe 'Test-LogFile' {

    BeforeAll {
        $TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSWriteLog_TestLogFile_$([guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        if (Test-Path -Path $TestDir) {
            Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should create directory and file if they do not exist' {
        $LogFile = Join-Path -Path $TestDir -ChildPath 'test.log'
        Test-LogFile -LogFile $LogFile -MaxSizeMB 5
        Test-Path -Path $LogFile | Should -BeTrue
    }

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
}

Describe 'Write-FunctionHeaderOrFooter' {

    BeforeAll {
        $TestLogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSWriteLog_FHF_$([guid]::NewGuid().ToString('N'))"
        Initialize-PSWriteLog -LogName 'FHFTest' -LogPath $TestLogPath -LogToConsole $false -LogDebugMessages $true
    }

    AfterAll {
        if (Test-Path -Path $TestLogPath) {
            Remove-Item -Path $TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should write header without error' {
        { Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -CmdletBoundParameters @{} -Header } | Should -Not -Throw
    }

    It 'Should write footer without error' {
        { Write-FunctionHeaderOrFooter -CmdletName 'Test-Function' -Footer } | Should -Not -Throw
    }
}
