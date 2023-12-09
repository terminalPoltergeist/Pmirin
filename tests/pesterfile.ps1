param(
    [switch]$Verbose
)

$config = New-PesterConfiguration

$config.Run.Path = "$($PSScriptRoot)/*.Test.ps1"

$config.CodeCoverage.Enabled = $true

$config.CodeCoverage.Path = "../src"

$config.CodeCoverage.CoveragePercentTarget = 80

if ($Verbose) {$config.Output.Verbosity = "Detailed"}

Import-Module "../src/*"

Invoke-Pester -Configuration $config
