function Import-PmirinModule {
    [cmdletbinding()]
    param (
        [string[]]$Name = $ModulePath,
        $Action = $PmirinAction,
        [string] $Version
    )
    if($PmirinAction -contains 'Import') {
        foreach($Mod in $Name) {
            Write-Verbose "Importing [$Mod]"
            $importParams = @{
                Name = $Mod
                Scope = 'Global'
                Force = $true
            }
            if ($Version -and $Version -ne 'latest') {
                $importParams.add('RequiredVersion',$Version)
            }
            Import-Module @importParams
        }
    }
}
