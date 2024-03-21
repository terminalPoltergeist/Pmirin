# This file defines the automation, configuration, testing, building, and deploying of the pmirin module

FormatTaskName "-------- {0} --------"

Properties {
    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    if (-not $ProjectRoot) {
        $ProjectRoot = Resolve-Path "$PSScriptRoot\.."
    }

    $commitMsg = (& git show -s --format=%B)
}

Task Default -Depends Init, Test

Task Init {
    Set-Location $ProjectRoot
    "Build System Details:"
    #Get all the BuildHelper variables (prefixed with BH)
    #Piping to Out-Host to get the formatter to output properly
    Get-Item Env:BH* | Out-Host

    Import-Module "$($ProjectRoot)/src/pmirin.psd1"

    $commitMsg
}

Task Test {
    $config = New-PesterConfiguration

    $config.Run.Path = $ENV:BHTestPath

    $config.CodeCoverage.Enabled = $true

    $config.CodeCoverage.Path = (Get-ChildItem -Path "$($ProjectRoot)/src/" | Where-Object { $_.Name –ne "pmirin.psm1" })

    $config.CodeCoverage.CoveragePercentTarget = 80

    if ($Verbose) {$config.Output.Verbosity = "Detailed"}

    Invoke-Pester -Configuration $config

    Move-Item -Path ./coverage.xml -Destination ./tests/ -Force
}
