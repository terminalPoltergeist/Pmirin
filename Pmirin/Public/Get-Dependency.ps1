function Get-Dependency {
    <#
    .SYNOPSIS
        Read a dependency psd1 file

    .DESCRIPTION
        Read a dependency psd1 file

        The resulting object contains these properties
            DependencyFile : Path to psd1 file this dependency is defined in
            DependencyName : Unique dependency name (the key in the psd1 file).  We reserve PmirinOptions for global options.
            DependencyType : Type of dependency.  See Get-PmirinType
            Name           : Name for the dependency
            Version        : Version for the dependency
            Parameters     : Hash table of parameters to pass to dependency script
            Source         : Source for the dependency
            Target         : Target for the dependency
            AddToPath      : If specified and dependency type supports it, add dependency to path (e.g. a module is added to PSModulePath)
            Tags           : One or more tags to categorize or filter dependencies
            DependsOn      : Dependency that must be installed before this
            PreScripts     : One or more paths to PowerShell scripts to run before the dependency
            PostScripts    : One or more paths to PowerShell scripts to run after the dependency
            PmirinOptions  : Hash table of global Pmirin options
            Raw            : Raw output for this dependency from the PSD1. May include data outside of standard items above.

        These are parsed from dependency PSD1 files as follows:

        Simple syntax, intepreted:
            @{
                DependencyName = 'Version'
            }

            With the simple syntax using interpretation:
               * The DependencyName (key) is used as the Name
               * If no DependencyType is specified, we parse the DependencyName to pick a default:
                 * We default to GitHub if the DependencyName has a single / (e.g. aaa/bbb)
                 * We default to git if the DependencyName has more than one / (e.g. https://gitlab.fqdn/org/some.git)
                 * We default to PSGalleryModule in all other cases
               * The Version (value) is a string, and is used as the Version
               * Other properties are set to $null

        Simple syntax, with helpers:
            @{
                DependencyType::DependencyName = 'Version'
            }

            With the simple syntax using helpers:
               * The dependency type and dependency name are included in the key (DependencyType::DependencyName, e.g. PSGalleryModule::Pester)
               * The version (value) is a string, and is used as the Version
               * Other properties are set to $null

        Advanced syntax:
            @{
                DependencyName = @{
                    DependencyType = 'TypeOfDependency'.  # See Get-PmirinType
                    Name = 'NameForThisDependency'
                    Version = '0.1.0'
                    Parameters = @{ Example = 'Value' }  # Optional parameters for the dependency script.
                    Source = 'Some source' # Usually optional
                    Target = 'Some target' # Usually optional
                    AddToPath = $True # Whether to add new dependency to path, if dependency type supports it.
                    Tags = 'prod', 'local' # One or more tags to categorize or filter dependencies
                    DependsOn = 'Some_Other_DependencyName' # DependencyName that must run before this
                    PreScripts = 'C:\script.ps1' # Script(s) to run before this dependency
                    PostScripts = 'C:\script2.ps1' # Script(s) to run after this dependency
                }
            }

        We use the same default DependencyTypes for this advanced syntax

        Global options:
           @{
               PmirinOptions = @{
                   Target = 'C:\temp'
               }
               # Supported for:
               #    Parameters
               #    Source
               #    Target
               #    AddToPath
               #    Tags
               #    DependsOn
               #    PreScripts
               #    PostScripts

               # Dependencies use these values as a default, unless you specify them explicitly for a dependency
           }

        Note that you can mix these syntax together in the same psd1.

    .PARAMETER Path
        Path to project root or dependency file.

        If a directory is specified, we search for and process requirements.psd1 files.

    .PARAMETER Tags
        Limit results to one or more tags defined in the Dependencies

    .PARAMETER Recurse
        If specified and path is a directory, search for requirements.psd1 files recursively under $Path

    .PARAMETER InputObject
        If specified instead of Path, treat this hashtable as the contents of a dependency file.

        For example:

            -InputObject @{
                BuildHelpers = 'latest'
                PSDeploy = 'latest'
                InvokeBuild = 'latest'
			}

	.PARAMETER Credentials
		Specifies a hashtable of PSCredentials to use for each dependency that is served from a private feed.

		For example:

			-Credentials @{
				PrivatePackage = $privateCredentials
				AnotherPrivatePackage = $morePrivateCredenials
			}

    .LINK
        about_Pmirin

    .LINK
        about_Pmirin_Definitions

    .LINK
        Get-PmirinScript

    .LINK
        Get-PmirinType

    .LINK
        Install-Dependency

    .LINK
        Invoke-Pmirin

    .LINK
        https://github.com/terminalPoltergeist/Pmirin
    #>
    [cmdletbinding(DefaultParameterSetName = 'File')]
    param(
        [parameter(ParameterSetName='File')]
        [string[]]$Path = $PWD.Path,

        [string[]]$Tags,

        [parameter(ParameterSetName='File')]
        [switch]$Recurse,

        [parameter(ParameterSetName='Hashtable')]
        [hashtable[]]$InputObject,

		[parameter(ParameterSetName='File')]
		[parameter(ParameterSetName='Hashtable')]
		[hashtable]$Credentials
    )

# REGION functions{{{
    # Helper to pick from global pmirinoptions, or return a default
    function Get-GlobalOption {
        param(
			$Options = $PmirinOptions,
            $Name,
            $Prefer,
            $Default = $null
        )
        # Check for preferred value, otherwise try to get value from key, otherwise use default....
        $Output = $Default
        if($Prefer) {
            $Output = $Prefer
        } else {
            try {
                $Output = $Options[$Name]
            } catch {
                $Output = $Default
            }
        }

        # Inject variables
        if( $Name -eq 'Target' -or
            $Name -eq 'Source' -or
            $Name -eq 'PreScripts' -or
			$Name -eq 'PostScripts')
        {
            $Output = Inject-Variable $Output
        }
        $Output
    }

    function Inject-Variable {
        [cmdletbinding()]
        param( $Value )
        $Output = $Value
        switch($Value) {
            {$_ -match '^\.$|^\.\\|^\./'}{
                $Output = $Output -replace '^\.', $PWD.Path
            }

            {$_ -Match '\$PWD'} {
                $Output = $Output -replace '\$PWD', $PWD.Path
            }

            {$_ -Match '\$ENV:ProgramData'} {
                $Output = $Output -replace '\$ENV:ProgramData', $ENV:ProgramData
            }
            {$_ -Match '\$ENV:USERPROFILE'} {
                $Output = $Output -replace '\$ENV:USERPROFILE', $ENV:USERPROFILE
            }
            {$_ -Match '\$ENV:APPDATA'} {
                $Output = $Output -replace '\$ENV:APPDATA', $ENV:APPDATA
            }
            {$_ -Match '\$ENV:TEMP'} {
                $Output = $Output -replace '\$ENV:TEMP', $ENV:TEMP
            }

            {$_ -Match '\$DependencyFolder|\$DependencyPath'} {
                $DependencyFolder = Split-Path $DependencyFile -Parent
                $Output = $Output -replace '\$DependencyFolder|\$DependencyPath', $DependencyFolder
            }
        }
        $Output
    }

    # Helper to take in a dependency hash and output Dependency objects
    function Parse-Dependency {
        [cmdletbinding()]
        param(
            $ParamSet = $PSCmdlet.ParameterSetName
        )

        # Global settings....
        $PmirinOptions = $null
        if($Dependencies.Containskey('PmirinOptions')) {
            $PmirinOptions = $Dependencies.PmirinOptions
            $Dependencies.Remove('PmirinOptions')
        }

        foreach($Dependency in $Dependencies.keys) {
            $DependencyHash = $Dependencies.$Dependency
            $DependencyType = Get-GlobalOption -Name DependencyType

			$CredentialName = Get-GlobalOption -Name Credential

            # Look simple syntax with helpers in the key first
            If( $DependencyHash -is [string] -and
                $Dependency -match '::' -and
                ($Dependency -split '::').count -eq 2
            ) {
                [pscustomobject]@{
                    PSTypeName = 'Pmirin.Dependency'
                    DependencyFile = $DependencyFile
                    DependencyName = ($Dependency -split '::')[1]
                    DependencyType = ($Dependency -split '::')[0]
                    Name = ($Dependency -split '::')[1]
                    Version = $DependencyHash
                    Parameters = Get-GlobalOption -Name Parameters
                    Source = Get-GlobalOption -Name Source
                    Target = Get-GlobalOption -Name Target
                    AddToPath = Get-GlobalOption -Name AddToPath
                    Tags = Get-GlobalOption -Name Tags
                    DependsOn = Get-GlobalOption -Name DependsOn
                    PreScripts =  Get-GlobalOption -Name PreScripts
					PostScripts =  Get-GlobalOption -Name PostScripts
					PmirinOptions = $PmirinOptions
                    Raw = $null
                }
            }
            #Parse simple key=name, value=version format
            # It doesn't look like a git repo, and simple syntax: PSGalleryModule
            elseif( $DependencyHash -is [string] -and
                $Dependency -notmatch '/' -and
                -not $DependencyType -or
                $DependencyType -eq 'PSGalleryModule'
            ) {
                [pscustomobject]@{
                    PSTypeName = 'Pmirin.Dependency'
                    DependencyFile = $DependencyFile
                    DependencyName = $Dependency
                    DependencyType = 'PSGalleryModule'
                    Name = $Dependency
                    Version = $DependencyHash
                    Parameters = Get-GlobalOption -Name Parameters
                    Source = Get-GlobalOption -Name Source
                    Target = Get-GlobalOption -Name Target
                    AddToPath = Get-GlobalOption -Name AddToPath
                    Tags = Get-GlobalOption -Name Tags
                    DependsOn = Get-GlobalOption -Name DependsOn
                    PreScripts =  Get-GlobalOption -Name PreScripts
                    PostScripts =  Get-GlobalOption -Name PostScripts
					Credential = Resolve-Credential -Name $CredentialName
                    PmirinOptions = $PmirinOptions
                    Raw = $null
                }
            }
            # It looks like a git repo, simple syntax, and not a full URI
            elseif($DependencyHash -is [string] -and
                   $Dependency -match '/' -and
                   $Dependency.split('/').count -eq 2 -and
                   -not $DependencyType -or
                   $DependencyType -eq 'GitHub'
            ) {
                [pscustomobject]@{
                    PSTypeName = 'Pmirin.Dependency'
                    DependencyFile = $DependencyFile
                    DependencyName = $Dependency
                    DependencyType = 'GitHub'
                    Name = $Dependency
                    Version = $DependencyHash
                    Parameters = Get-GlobalOption -Name Parameters
                    Source = Get-GlobalOption -Name Source
                    Target = Get-GlobalOption -Name Target
                    AddToPath = Get-GlobalOption -Name AddToPath
                    Tags = Get-GlobalOption -Name Tags
                    DependsOn = Get-GlobalOption -Name DependsOn
                    PreScripts = Get-GlobalOption -Name PreScripts
                    PostScripts = Get-GlobalOption -Name PostScripts
                    PmirinOptions = $PmirinOptions
                    Raw = $null
                }
            }
            # It looks like a git repo, and simple syntax: Git
            elseif($DependencyHash -is [string] -and
                   $Dependency -match '/' -and
                   -not $DependencyType -or
                   $DependencyType -eq 'Git' 
            ) {
                [pscustomobject]@{
                    PSTypeName = 'Pmirin.Dependency'
                    DependencyFile = $DependencyFile
                    DependencyName = $Dependency
                    DependencyType = 'Git'
                    Name = $Dependency
                    Version = $DependencyHash
                    Parameters = Get-GlobalOption -Name Parameters
                    Source = Get-GlobalOption -Name Source
                    Target = Get-GlobalOption -Name Target
                    AddToPath = Get-GlobalOption -Name AddToPath
                    Tags = Get-GlobalOption -Name Tags
                    DependsOn = Get-GlobalOption -Name DependsOn
                    PreScripts = Get-GlobalOption -Name PreScripts
                    PostScripts = Get-GlobalOption -Name PostScripts
                    PmirinOptions = $PmirinOptions
                    Raw = $null
                }
            } else {
                # Parse dependency hash format
                # Default type is module, unless it's in a git-style format
                if(-not $DependencyHash.DependencyType) {
                    # Is it a global option?
                    if($DependencyType) {}
                    # GitHub first
                    elseif(
                        # Ugly right? Watch out for split called on hashtable...
                        ($Dependency -match '/' -and -not $Dependency.Name -and
                            ($Dependency -is [string] -and $Dependency.split('/').count -eq 2)
                        ) -or
                        ($DependencyHash.Name -match '/' -and
                            ($DependencyHash -is [string] -and $DependencyHash.split('/').count -eq 2)
                        )
                    ) {
                        $DependencyType = 'GitHub'
                    } elseif( # Now git...
                        ($Dependency -match '/' -and -not $Dependency.Name) -or
                        $DependencyHash.Name -match '/'
                    ) {
                        $DependencyType = 'Git'
                    } else { # finally, psgallerymodule 
                        $DependencyType = 'PSGalleryModule'
                    }
                } else {
                    $DependencyType = $DependencyHash.DependencyType
                }

				$CredentialName = Get-GlobalOption -Name Credential -Prefer $DependencyHash.Credential
                [pscustomobject]@{
                    PSTypeName = 'Pmirin.Dependency'
                    DependencyFile = $DependencyFile
                    DependencyName = $Dependency
                    DependencyType = $DependencyType
                    Name = $DependencyHash.Name
                    Version = $DependencyHash.Version
                    Parameters = Get-GlobalOption -Name Parameters -Prefer $DependencyHash.Parameters
                    Source = Get-GlobalOption -Name Source -Prefer $DependencyHash.Source
                    Target = Get-GlobalOption -Name Target -Prefer $DependencyHash.Target
                    AddToPath = Get-GlobalOption -Name AddToPath -Prefer $DependencyHash.AddToPath
                    Tags = Get-GlobalOption -Name Tags -Prefer $DependencyHash.Tags
                    DependsOn = Get-GlobalOption -Name DependsOn -Prefer $DependencyHash.DependsOn
                    PreScripts = Get-GlobalOption -Name PreScripts -Prefer $DependencyHash.PreScripts
                    PostScripts = Get-GlobalOption -Name PostScripts -Prefer $DependencyHash.PostScripts
					Credential = Resolve-Credential -Name $CredentialName
					PmirinOptions = $PmirinOptions
                    Raw = $DependencyHash
                }
            }
        }
	}

	# Heleper to retrieve the credential for a dependency
	function Resolve-Credential  {
		[CmdletBinding()]
		param (
			[string]$Name
		)

		$credential = $null
		if (($null -ne $Name) -and ($null -ne $Credentials)) {

			if ($Credentials.ContainsKey($Name)) {
				$credential = $Credentials[$Name]
			} else {
				Write-Warning "No credential found for the specified name $Name. Was the dependency misconfigured?"
			}
		}

		return $credential
	}
# ENDREGION functions}}}

    if($PSCmdlet.ParameterSetName -eq 'File') {
        $ParsedDependencies = foreach($DependencyPath in $Path) {
            #Resolve relative paths... Thanks Oisin! http://stackoverflow.com/a/3040982/3067642
            $DependencyPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DependencyPath)

            if(Test-Path $DependencyPath -PathType Container) {
                $DependencyFiles = @( Resolve-RequirementsFile -Path $DependencyPath -Recurse $Recurse )
            } else {
                $DependencyFiles = @( $DependencyPath )
            }
            $DependencyFiles = $DependencyFiles | Select-Object -Unique

            foreach($DependencyFile in $DependencyFiles) {
                # Read the file
                $Base = Split-Path $DependencyFile -Parent
                $File = Split-Path $DependencyFile -Leaf
                $Dependencies = Import-LocalizedData -BaseDirectory $Base -FileName $File

                Parse-Dependency -ParamSet $PSCmdlet.ParameterSetName
            }
        }
    } elseif($PSCmdlet.ParameterSetName -eq 'Hashtable') {
        $DependencyFile = 'Hashtable'
        $ParsedDependencies = foreach($InputDependency in $InputObject) {
            $Dependencies = $InputDependency

            Parse-Dependency -ParamSet $PSCmdlet.ParameterSetName
        }
    }

    If($PSBoundParameters.ContainsKey('Tags')) {
        $ParsedDependencies = Get-TaggedDependency -Dependency $ParsedDependencies -Tags $Tags
        if(-not $ParsedDependencies) {
            Write-Warning "No dependencies found with tags '$tags'"
            return
        }
    }
    Sort-PmirinDependency -Dependencies $ParsedDependencies
}
