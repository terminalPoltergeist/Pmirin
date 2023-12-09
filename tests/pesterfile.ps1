Import-Module Pester

$config = New-PesterConfiguration

$config.Run.Path = "$($PSScriptRoot)/*.Test.ps1"

$config.CodeCoverage.Enabled = $true

$config.CodeCoverage.Path = "../src"

$config.CodeCoverage.CoveragePercentTarget = 100

$config.Output.Verbosity = "Detailed"

Invoke-Pester -Configuration $config
