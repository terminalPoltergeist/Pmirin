Import-Module BuildHelpers

Set-BuildEnvironment -BuildOutput '$ProjectPath/dist' -Force

$ENV:BHTestPath = "$($ENV:BHProjectPath)/tests"

Invoke-Psake $ENV:BHProjectPath/build/psakefile.ps1
