$ModuleRoot = $PSScriptRoot
# REGION source public and private functions
$dotSourceParams = @{
    Filter      = '*.ps1'
    Recurse     = $true
    ErrorAction = 'Continue'
}

$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1') @dotSourceParams )
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1') @dotSourceParams)

foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to source [$($import.FullName)]"
    }
}
# ENDREGION

