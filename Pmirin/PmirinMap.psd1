# This file maps dependency types to the script that resolves them. Feel free to create your own
# Top level members are the dependency names
#   Script is the script to run. These are stored in \Pmirin\PmirinScripts
#   Description is a quick description of the dependency script
#   Supports is a way to filter supported platforms:  core, windows, macos, linux

# In some cases, it may be beneficial to include 'aliases'.  Just add nodes for these.
@{
    GitHub = @{
        Script = 'GitHub.ps1'
        Description = 'Download and extract a GitHub repo'
        Supports = 'windows', 'core', 'macos', 'linux'
    }
    PSGalleryModule = @{
        Script= 'PSGalleryModule.ps1'
        Description = 'Install a PowerShell module from the PowerShell Gallery'
        Supports = 'windows', 'core', 'macos', 'linux'
    }
}
