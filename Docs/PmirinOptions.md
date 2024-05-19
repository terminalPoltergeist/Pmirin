# PmirinOptions

**Related:**
- [Get-Dependency.ps1](../Pmirin/Public/Get-Dependency.ps1)
- [Dependency-Files](./Dependency-Files.md)

*PmirinOptions* are configurable values that change the default behaviour and actions taken by Pmirin when resolving a dependency. PmirinOptions can be defined in a dependency file or passed to `Invoke-Pmirin` in a hashtable along with the dependencies in the `-InputObject` parameter.

Options are set as a hashtable of `@{[OptionName] = [OptionValue]}`.

Supported options are:

- Parameters
    - Parameters to pass to the dependency script.
    - ex. `Credentials`
- Source
    - Upstream source for the dependency.
    - ex. an NFS mount where a file lives
- Target
    - Local path to place the dependency.
- AddToPath
    - Whether to add the dependency to the path for its dependency type.
    - ex. PSModulePath for Powershell module dependencies
- Tags
    - Collection of tags to categorize dependencies.
    - ex. 'prod', 'test'
- DependsOn
    - Name of dependencies that must be installed before this one.
- PreScripts
    - Collection of paths to Powershell scripts to run before resolving this dependency.
- PostScripts
    - Collection of paths to Powershell scripts to run after resolving this dependency.

*See scripts in [PmirinScripts](../Pmirin/PmirinScripts/) for default values for each dependency type.*
