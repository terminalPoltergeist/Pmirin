function Invoke-DependencyScript {
    <#
    .SYNOPSIS
        Invoke a dependency script

    .DESCRIPTION
        Invoke a dependency script

        See Get-Help about_Pmirin for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PmirinTypePath
        Specify a PmirinMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PmirinMap.psd1 in the Pmirin module folder

    .PARAMETER Tags
        Only test dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER PmirinAction
        PmirinAction to run.  Test, Install, and Import are the most common.

        Test can only be run by itself.

    .PARAMETER Quiet
        If PmirinAction is Test, and Quiet is specified, we return $true or $false based on whether a dependency exists

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Import-Dependency

        Get dependencies from C:\requirements.psd1 and import them

    .LINK
        about_Pmirin

    .LINK
        about_Pmirin_Definitions

    .LINK
        Get-Dependency

    .LINK
        Get-PmirinType

    .LINK
        Invoke-Pmirin

    .LINK
        https://github.com/RamblingCookieMonster/Pmirin
    #>
    [cmdletbinding()]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ParameterSetName='Map',
                    Mandatory = $True)]
        [PSTypeName('Pmirin.Dependency')]
        [psobject]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PmirinTypePath = $(Join-Path $ModuleRoot PmirinMap.psd1),

        [string[]]$PmirinAction,

        [string[]]$Tags,

        [switch]$Quiet
    )
    Begin {
        # This script reads a depend.psd1, installs dependencies as defined
        Write-Verbose "Running Invoke-DependencyScript with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"
        $PmirinTypes = Get-PmirinType -SkipHelp
    } Process {
        Write-Verbose "Dependencies:`n$($Dependency | Select-Object -Property * | Out-String)"

        #Get definitions, and dependencies in this particular psd1
        $DependencyDefs = Get-PmirinScript
        $TheseDependencyTypes = @( $Dependency.DependencyType | Sort-Object -Unique )

        #Build up hash, we call each dependencytype script for applicable dependencies
        foreach($DependencyType in $TheseDependencyTypes) {
            $PmirinType = ($PmirinTypes | Where-Object {$_.DependencyType -eq $DependencyType})
            if(-not $PmirinType.Supported) {
                Write-Warning "Skipping dependency type [$DependencyType]`nThis dependency does not support your platform`nSupported platforms: [$($PmirinType.Supports)]"
                continue
            }
            $DependencyScript = $DependencyDefs.$DependencyType
            if(-not $DependencyScript) {
                Write-Error "DependencyType $DependencyType is not defined in PmirinMap.psd1"
                continue
            }
            $TheseDependencies = @( $Dependency | Where-Object {$_.DependencyType -eq $DependencyType})

            #Define params for the script
            #Each dependency type can have a hashtable to splat.
            $RawParameters = Get-Parameter -Command $DependencyScript
            $ValidParamNames = $RawParameters.Name
            Write-Verbose "Found parameters [$ValidParamNames]"

            if($ValidParamNames -notcontains 'PmirinAction') {
                Write-Error "No PmirinAction found on PmirinScript [$DependencyScript]. Skipping [$($Dependency.DependencyName)]"
                continue
            }
            [string[]]$ValidPmirinActions = $RawParameters |
                Where-Object {$_.Name -like 'PmirinAction'} |
                Select-Object -ExpandProperty ValidateSetValues -ErrorAction SilentlyContinue
            [string[]]$PmirinActions = foreach($Action in $PmirinAction) {
                if($ValidPmirinActions -contains $Action) {$Action}
                else {
                    Write-Warning "Skipping PmirinAction [$Action] for dependency [$($Dependency.DependencyName)]. Valid actions: [$ValidPmirinActions]"
                }
            }

            if($PmirinActions.count -like 0) {
                Write-Verbose "Skipped dependency [$($Dependency.DependencyName)] due to filtered PmirinAction.  See Warnings above."
                continue
            }

            if($PmirinActions -contains 'Test' -and
                ( $PmirinActions -contains 'Import' -or
                $PmirinActions -contains 'Install')
            ) {
                Write-Error "Removing [Test] from PmirinActions.  The Test action must run on its own."
                $PmirinActions = $PmirinActions | Where-Object {$_ -ne 'Test'}
            }

            foreach($ThisDependency in $TheseDependencies) {
                #Parameters for dependency types.  Only accept valid params...
                if($ThisDependency.Parameters.keys.count -gt 0) {
                    $splat = @{}
                    foreach($key in $ThisDependency.Parameters.keys) {
                        if($ValidParamNames -contains $key) {
                            $splat.Add($key, $ThisDependency.Parameters.$key)
                        } else {
                            Write-Warning "Parameter [$Key] with value [$($ThisDependency.Parameters.$Key)] is not a valid parameter for [$DependencyType], ignoring.  Valid params:`n[$ValidParamNames]"
                        }
                    }

                    if($ThisDependency.Parameters.Import -and $PmirinActions -notcontains 'Test') {
                        $PmirinActions += 'Import'
                        $PmirinActions = $PmirinActions | Sort-Object -Unique
                    } 

                    if($splat.ContainsKey('PmirinAction')) {
                        $Splat['PmirinAction'] = $PmirinActions
                    } else {
                        $Splat.add('PmirinAction', $PmirinActions)
                    }
                } else {
                    $splat = @{PmirinAction = $PmirinActions}
                }

                #Define params for the script
                $splat.add('Dependency', $ThisDependency)

                # PITA, but tasks can run two ways, each different than typical dependency scripts
                if($PmirinActions -contains 'Install' -and $DependencyType -eq 'Task') {
                    foreach($TaskScript in $ThisDependency.Target) {
                        if( Test-Path $TaskScript -PathType Leaf) {
                            . $TaskScript @splat
                        } else {
                            Write-Error "Could not process task [$TaskScript].`nAre connectivity, privileges, and other needs met to access it?"
                        }
                    }
                } else {
                    Write-Verbose "Invoking '$DependencyScript' with parameters $($Splat | Out-String)"
                    $Output = . $DependencyScript @splat
                    if($PmirinActions -contains 'Test' -and -not $Quiet) {
                        Add-Member -InputObject $ThisDependency -MemberType NoteProperty -Name DependencyExists -Value $Output -Force -PassThru
                    } else {
                        $Output
                    }
                }
            }
        }
    }
}
