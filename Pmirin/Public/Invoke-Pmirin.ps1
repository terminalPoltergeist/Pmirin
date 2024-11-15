function Invoke-Pmirin {
    <#
    .SYNOPSIS
        Invoke Pmirin

    .DESCRIPTION
        Invoke Pmirin

        Searches for and runs requirements.psd1 files in the current and nested paths

        See Get-Help about_Pmirin for more information.

    .PARAMETER Path
        Path to a specific requirements.psd1 file, or to a directory that we recursively search for a requirements.psd1 file

        Defaults to the current directory

    .PARAMETER Recurse
        If path is a directory, whether to recursively search for requirements.psd1 files under that directory

        Defaults to $True

    .PARAMETER InputObject
        If specified instead of Path, treat this hashtable as the contents of a dependency file.

        For example:

            -InputObject @{
                BuildHelpers = 'latest'
                PSDeploy = 'latest'
                InvokeBuild = 'latest'
            }

    .PARAMETER Tags
        Only invoke dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER PmirinTypePath
        Specify a PmirinMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PmirinMap.psd1 in the Pmirin module folder

    .PARAMETER Force
        Force dependency, skipping prompts and confirmation

    .PARAMETER Test
        Run tests for dependencies we find.

        Appends a 'DependencyExists' property indicating whether the dependency exists by default
        Specify Quiet to simply return $true or $false depending on whether all dependencies exist

    .PARAMETER Quiet
        If specified along with Test, we return $true, or $false depending on whether all dependencies were met

    .PARAMETER Install
        Run the install for a dependency

        Default behavior

    .PARAMETER Target
        If specified, override the target in the PmirinOptions or Dependency.

    .PARAMETER Import
        If the dependency supports it, import it

    .PARAMETER Credentials
        Specifies a hashtable of PSCredentials to use for each dependency that is served from a private feed. The key of the hashtable must match the Credential property value in the dependency.

        For example:

        @{
            dependency_name = @{
                ...
                Credential = 'PrivatePackage'
                ...
            }
        }

        -Credentials @{
                PrivatePackage = $privateCredentials
                AnotherPrivatePackage = $morePrivateCredenials
        }

    .EXAMPLE
        Invoke-Pmirin

        # Search for and run requirements.psd1 files under the current directory

    .EXAMPLE
        Invoke-Pmirin -Path C:\Path\To\require.psd1

        # Install dependencies from require.psd1

    .EXAMPLE
        Invoke-Pmirin -Path C:\Requirements -Recurse $False

        # Find and run requirements.psd1 files under C\Requirements (but not subfolders)

    .LINK
        about_Pmirin

    .LINK
        about_Pmirin_Definitions

    .LINK
        Get-Dependency

    .LINK
        Install-Dependency

    .LINK
        https://github.com/terminalPoltergeist/Pmirin
    #>

    [cmdletbinding( DefaultParameterSetName = 'installimport-file',
                    SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [validatescript({Test-Path -Path $_ -ErrorAction Stop})]
        [parameter( ParameterSetName = 'installimport-file',
                    Position = 0,
                    ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [parameter( ParameterSetName = 'test-file',
                    Position = 0,
                    ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [string[]]$Path = '.',

        [parameter( ParameterSetName = 'installimport-hashtable',
                    Position = 0,
                    ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [parameter( ParameterSetName = 'test-hashtable',
                    Position = 0,
                    ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [hashtable[]]$InputObject,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PmirinTypePath = $(Join-Path $ModuleRoot PmirinMap.psd1),

        [string[]]$Tags,

        [parameter(ParameterSetName = 'installimport-file')]
        [parameter(ParameterSetName = 'test-file')]
        [bool]$Recurse = $True,

        [parameter(ParameterSetName = 'test-file')]
        [parameter(ParameterSetName = 'test-hashtable')]
        [switch]$Test,

        [parameter(ParameterSetName = 'test-file')]
        [parameter(ParameterSetName = 'test-hashtable')]
        [switch]$Quiet,

        [parameter(ParameterSetName = 'installimport-file')]
        [parameter(ParameterSetName = 'installimport-hashtable')]
        [switch]$Import,

        [parameter(ParameterSetName = 'installimport-file')]
        [parameter(ParameterSetName = 'installimport-hashtable')]
        [switch]$Install,

        [switch]$Force,

        [String]$Target,

        [parameter(ParameterSetName = 'installimport-file')]
        [parameter(ParameterSetName = 'installimport-hashtable')]
        [hashtable]$Credentials
    )
    begin {
        # Build parameters
        $InvokeParams = @{
            PmirinAction = @()
            PmirinTypePath = $PmirinTypePath
        }
        $DoInstall = $PSCmdlet.ParameterSetName -like 'installimport-*' -and $Install
        $DoImport = $PSCmdlet.ParameterSetName -like 'installimport-*' -and $Import
        $DoTest = $PSCmdlet.ParameterSetName -like 'test-*' -and $Test
        if($DoInstall){$InvokeParams.PmirinAction += 'Install'}
        if($DoImport){$InvokeParams.PmirinAction += 'Import'}
        if($DoTest){$InvokeParams.PmirinAction += 'Test'}
        if($InvokeParams.PmirinAction.count -like 0) {
            $InvokeParams.PmirinAction += 'Install'
        }

        $plainTextCreds = $Credentials.Keys | Where-Object {$Credentials[$_].GetType().Name -ne 'SecureString'}
        foreach ($name in $plainTextCreds) {
            Write-Verbose "Converting $name credential to SecureString"
            $Credentials[$name] = (ConvertTo-SecureString -String $Credentials[$name] -AsPlainText -Force)
        }
        Write-Verbose "Running Invoke-Pmirin with ParameterSetName $($PSCmdlet.ParameterSetName), PmirinAction $($InvokeParams.PmirinAction), and params: $($PSBoundParameters | Out-String)"

        $DependencyFiles = New-Object System.Collections.ArrayList
        $PmirinTypes = Get-PmirinType -Path $PmirinTypePath -SkipHelp
    } process {
        $GetPmirinParams = @{}

        if($PSCmdlet.ParameterSetName -like '*-file') {
            foreach( $PathItem in $Path ) {
                # Create a map for dependencies
                [void]$DependencyFiles.AddRange( @( Resolve-RequirementsFile -Path $PathItem -Recurse $Recurse ) )
                if ($DependencyFiles.count -gt 0) {
                    Write-Verbose "Working with [$($DependencyFiles.Count)] dependency files from [$PathItem]:`n$($DependencyFiles | Out-String)"
                } else {
                    Write-Warning "No requirements.psd1 files found under [$PathItem]"
                }
            }
            $GetPmirinParams.add('Path',$DependencyFiles)
        } elseif($PSCmdlet.ParameterSetName -like '*-hashtable') {
            $GetPmirinParams.add('InputObject',$InputObject)
        }

        # Parse
        if($PSBoundParameters.ContainsKey('Tags')) {
            $GetPmirinParams.Add('Tags',$Tags)
        }

        if ($null -ne $Credentials) {
            $GetPmirinParams.Add('Credentials', $Credentials)
        }

        # Handle Dependencies
        $Dependencies = Get-Dependency @GetPmirinParams
        $Unsupported = ( $PmirinTypes | Where-Object {-not $_.Supported} ).DependencyType
        $Dependencies = foreach($Dependency in $Dependencies) {
            if($Unsupported -contains $Dependency.DependencyType) {
                $Supports = $PmirinTypes | Where-Object {$_.DependencyType -eq $Dependency.DependencyType} | Select -ExpandProperty Supports
                Write-Warning "Skipping unsupported dependency:`n$( $Dependency | Out-String)`nSupported platforms:`n$($Supports | Out-String)"
            } else {
                $Dependency
            }
        }

        if($DoTest -and $Quiet) {
            $TestResult = [System.Collections.ArrayList]@()
        }

        #TODO: Add ShouldProcess here if install is specified...
        foreach($Dependency in $Dependencies) {
            if($PSBoundParameters.ContainsKey('Target')) {
                Write-Verbose "Overriding Dependency target [$($Dependency.Target)] with target parameter value [$Target]"
                $Dependency.Target = $Target
            }

            if( ($Force -and -not $WhatIf) -or
                ($DoTest) -or
                $PSCmdlet.ShouldProcess( "Processed the dependency '$($Dependency.DependencyName -join ", ")'",
                                        "Process the dependency '$($Dependency.DependencyName -join ", ")'?",
                                        "Processing dependency" ))
            {
                $PreScriptSuccess = $True #anti pattern! Best I could come up with to handle both prescript fail and dependencies
                if($DoInstall -and $Dependency.PreScripts.Count -gt 0) {
                    $ExistingEA = $ErrorActionPreference
                    $ErrorActionPreference = 'Stop'
                    foreach($script in $Dependency.PreScripts) {
                        Try {
                            Write-Verbose "Invoking pre script: [$script]"
                            . $script
                        } Catch {
                            $PreScriptSuccess = $False
                            "Skipping installation due to failed pre script: [$script]"
                            Write-Error $_
                        }
                    }
                    $ErrorActionPreference = $ExistingEA
                }

                if($PreScriptSuccess) {
                    if($DoTest -and $Quiet) {
                        $null = $TestResult.Add( (Invoke-DependencyScript @InvokeParams -Dependency $Dependency -Quiet ) )
                    } else {
                        Invoke-DependencyScript @InvokeParams -Dependency $Dependency
                    }
                }

                if($DoInstall -and $Dependency.PostScripts.Count -gt 0) {
                    foreach($script in $Dependency.PostScripts) {
                        Write-Verbose "Invoking post script: $($script)"
                        . $script
                    }
                }
            }
        }
        if($DoTest -and $Quiet) {
            if($TestResult -contains $false) {
                $false
            } else {
                $true
            }
        }
    }
}
