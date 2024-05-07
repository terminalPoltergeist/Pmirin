# REGION source public and private functions
$dotSourceParams = @{
    Filter      = '*.ps1'
    Recurse     = $true
    ErrorAction = 'Continue'
}

$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'public/*.ps1') @dotSourceParams )
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'private/*.ps1') @dotSourceParams)

foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to source [$($import.FullName)]"
    }
}
