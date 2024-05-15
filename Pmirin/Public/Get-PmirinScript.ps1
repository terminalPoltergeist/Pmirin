function Get-PmirinScript {
    <#
    .SYNOPSIS
        Get dependency types and associated scripts

    .DESCRIPTION
        Get dependency types and associated scripts

        Checks PmirinMap.psd1,
        verifies dependency scripts exist,
        returns a hashtable of these.

    .PARAMETER Path
        Path to PmirinMap.psd1 defining dependency types

        Defaults to PmirinMap.psd1 in the module root

    .EXAMPLE
        Get-PmirinScript

        # List Pmirin scripts available in the PmirinMap.psd1 in the Pmirin module root

    .EXAMPLE
        Get-PmirinScript -Path \\Path\To\Central.DependencyMap.psd1

        # List dependency types defined in a centralized dependency map

    .LINK
        about_Pmirin

    .LINK
        about_Pmirin_Definitions

    .LINK
        Get-Dependency

    .LINK
        Get-PmirinType

    .LINK
        Install-Dependency

    .LINK
        Invoke-Pmirin

    .LINK
        https://github.com/RamblingCookieMonster/Pmirin
    #>
    [cmdletbinding()]
    param(
        [validatescript({Test-Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$Path = $(Join-Path $ModuleRoot PmirinMap.psd1)
    )

    # Read the file
    $Base = Split-Path $Path -Parent
    $File = Split-Path $Path -Leaf
    $DependencyDefinitions = Import-LocalizedData -BaseDirectory $Base -FileName $File

    $DependHash = @{}
    foreach($DependencyType in $DependencyDefinitions.Keys) {
        #Determine the path to this script
        $Script =  $DependencyDefinitions.$DependencyType.Script
        if(Test-Path $Script -ErrorAction SilentlyContinue) {
            $ScriptPath = $Script
        } else {
            # account for missing ps1
            $ScriptPath = Join-Path $ModuleRoot "PmirinScripts\$($Script -replace ".ps1$").ps1"
        }

        if(test-path $ScriptPath) {
            $DependHash.$DependencyType = $ScriptPath
        } else {
            Write-Error "Could not find path '$ScriptPath' for dependency $DependencyType. Origin: $($DependencyDefinitions.$DependencyType.Script)"
        }
    }

    $DependHash
}



