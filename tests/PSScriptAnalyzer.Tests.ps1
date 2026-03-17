#Requires -Module Pester
#Requires -Module PSScriptAnalyzer

Describe 'PSScriptAnalyzer: MEMZone.WriteLog' {

    BeforeAll {
        $ModuleSourcePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/MEMZone.WriteLog'
        $AnalyzerResults  = Invoke-ScriptAnalyzer -Path $ModuleSourcePath -Recurse -Settings PSGallery -Severity @('Error', 'Warning')
    }

    It 'Should pass all PSScriptAnalyzer rules (Error severity)' {
        $Errors = $AnalyzerResults | Where-Object { $PSItem.Severity -eq 'Error' }
        if ($Errors) {
            $ErrorDetails = $Errors | ForEach-Object { "  [$($PSItem.ScriptName):$($PSItem.Line)] $($PSItem.RuleName): $($PSItem.Message)" }
            $Errors.Count | Should -Be 0 -Because "PSScriptAnalyzer errors found:`n$($ErrorDetails -join "`n")"
        }
        else {
            $Errors | Should -BeNullOrEmpty
        }
    }

    It 'Should pass all PSScriptAnalyzer rules (Warning severity)' {
        $Warnings = $AnalyzerResults | Where-Object { $PSItem.Severity -eq 'Warning' }
        if ($Warnings) {
            $WarningDetails = $Warnings | ForEach-Object { "  [$($PSItem.ScriptName):$($PSItem.Line)] $($PSItem.RuleName): $($PSItem.Message)" }
            $Warnings.Count | Should -Be 0 -Because "PSScriptAnalyzer warnings found:`n$($WarningDetails -join "`n")"
        }
        else {
            $Warnings | Should -BeNullOrEmpty
        }
    }
}
