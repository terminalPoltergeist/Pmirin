BeforeAll {
    $test = Split-Path -Parent $PSScriptRoot
    Import-Module $test/src/AutomationWithLogs.psm1
}

Describe 'Initialize-Automation' {
    It 'creates empty $Automation from no inputs' {
        Initialize-Automation
        $Automation | Should -Not -BeNullOrEmpty
        $Automation.inputs | Should -BeNullOrEmpty
        $Automation.results | Should -BeNullOrEmpty
        $Automation.action | Should -BeNullOrEmpty
        $Automation.done | Should -Not -BeTrue
        $Automation.logs | Should -BeNullOrEmpty
    }
    It 'accepts single value [<value.GetType()>]' -ForEach @(
        @{value = 'Hello world'}
        @{value = 42}
        @{value = 0.7}
        @{value = $false}
    ){
        Initialize-Automation -inputs $value
        $Automation.inputs | Should -Be $value
    }
    It 'accepts enums [<value.GetType()>]' -ForEach @(
        @{value = @('Hello', 'World')}
        @{value = @{name = 'World'; message = 'Hello'}}
    ){
        Initialize-Automation -inputs $value
        $Automation.inputs | Should -Be $value
    }
}
