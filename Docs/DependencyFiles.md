# Dependecny Files

**Related:**
- [PmirinOptions](./PmirinOptions.md)
- [Get-Dependency.ps1](../Pmirin/Public/Get-Dependency.ps1)

Dependency files are where dependencies are defined and configured. Define a dependency file by creating a `requirements.psd1` file.

It is recommended to place your `requirements.psd1` file at your project root. Pmirin will resolve dependency files in the directory the command is run from. An optional `-Recurse` flag will make Pmirin recurse into subdirectories, searching for a dependency file. You can provide a path to a dependency file with the `-Path` option.

Dependency files are Powershell Datafiles. They must have the `.psd1` extension and the contents must be a single hash-table of data.

A dependency file can contain zero or one entry of [PmirinOptions](./PmirinOptions.md) and one or more dependency definition.

Dependency definitions can use a few different syntaxes:

- Simple, implicit
  - The key specifies the dependency name.
    - Dependencies with a single / (ex. user/repo) will default to GitHub for a dependency type.
    - Dependencies with multiple / (ex. https://gitlab.fqdn/org/repo.git) will default to Git for a dependency type.
    - All other formats will default to PSGalleryModule for a dependency type.
  - The value specifies the dependency version. Dependency versions are resolved differently for each dependency type. See [PmirinScripts](../Pmirin/PmirinScripts) for how each dependency type resolves versions.
  - ex.
    ```Powershell
    @{
      'myDependency' = '1.0.0' #download 'myDependency' version 1.0.0 from PSGallery
      'myOrg/anotherDependency' = 'main' #download 'anotherDependency' from the main branch on GitHub
    }
    ```
- Simple, explicit
  - The key specifies the dependency name AND the dependency type.
  - The value still specifies the version for the dependency.
  - ex.
    ```Powershell
    @{
      'PSGalleryModule:Pmirin' = '1.0.0'
    }
    ```
- Advanced, explicit
  - The key still specifies the dependency name and resolves to the same default types unless `DependencyType` is specified as well.
  - The value is a hash-table of options for explicitly defining a dependency.
    - `DependencyType` is the type of dependency. See [Get-Pmirintype.ps1](../Pmirin/Public/Get-PmirinType.ps1).
    - `Name` is the local name to give the dependency. (ex. if specifying a GitHub dependency, 'user/repo' would be the dependency key and the name option could then be 'repo').
    - `Version` specifies the dependency version.
    - `Parameters` is a hash-table of Parameters to pass to the PmirinScript for resolving the dependency. See [PmirinScripts](../Pmirin/PmirinScripts) for available Parameters for each dependency type.
    - `Source` is used by some dependency resolver scripts for locating the dependency. ex. for dependencies on a file share you would provide the path to the file share.
    - `Target` is the local target to install the dependency to; a path.
    - `AddToPath` boolean for whether to add the dependency to the PSModulePath.
    - `Tags` collection of strings giving tags to label the dependency with. ex. 'prod', 'text', etc.
    - `DependsOn` specifies dependencies that need to run before resolving this one.
    - `PreScripts` path(s) to script(s) to run before the dependency is resolved.
    - `PostScripts` path(s) to script(s) to run after the dependency is resolved.
  - ex.
    ```powershell
    @{
      'myOrg/myDependency' = @{
        DependencyType = "GitHub"
        Version = '1.0.0'
        Parameters = @{
          Credentials = @{'Bearer' = "access_token_here"}
        }
        Target = 'path/to/my/project'
        AddToPath = $true
        Tags = 'development', 'local'

        #not all options shown here
      }
    }
    ```

These syntaxes can be mixed-and-matched in a sinlge Pmirin file.
