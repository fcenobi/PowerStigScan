#
# Module manifest for module 'PowerStigScan'
#
# Generated by: Matt Preston
#
# Generated on: 8/7/2018
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'PowerStigScan.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0.0'
    
    # Supported PSEditions
    # CompatiblePSEditions = @()
    
    # ID used to uniquely identify this module
    GUID = '453265f6-5529-4e29-9918-7aca081ca986'
    
    # Author of this module
    Author = 'Matt Preston'
    
    # Company or vendor of this module
    CompanyName = 'Microsoft'
    
    # Copyright statement for this module
    Copyright = '(c) 2018 Matt Preston. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Module to Audit systems using the PowerStig engine. 
PowerStigScan Repo: https://github.com/mapresto/PowerStigScan.
PowerStig Repo: https://github.com/Microsoft/PowerStig'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''
    
    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''
    
    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''
    
    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''
    
    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ModuleName = 'AuditPolicyDsc'; ModuleVersion = '1.2.0.0'},
        @{ModuleName = 'AccessControlDsc'; ModuleVersion = '1.1.0.0'},
        @{ModuleName = 'FileContentDsc'; ModuleVersion = '1.1.0.108'},
        @{ModuleName = 'PolicyFileEditor'; ModuleVersion = '3.0.1'},
        @{ModuleName = 'SecurityPolicyDsc'; ModuleVersion = '2.4.0.0'},
        @{ModuleName = 'SqlServerDsc'; ModuleVersion = '12.1.0.0'},
        @{ModuleName = 'WindowsDefenderDsc'; ModuleVersion = '1.0.0.0'},
        @{ModuleName = 'xDnsServer'; ModuleVersion = '1.11.0.0'},
        @{ModuleName = 'xPSDesiredStateConfiguration'; ModuleVersion = '8.3.0.0'},
        @{ModuleName = 'xWebAdministration'; ModuleVersion = '2.3.0.0'},
        @{ModuleName = 'xWinEventLog'; ModuleVersion = '1.2.0.0'},
        @{ModuleName = 'PowerStig'; ModuleVersion = '2.3.2.0'}
    
    )
    
    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Invoke-PowerStigScan', 
        'New-PowerStigCkl', 
        'Add-PowerStigComputer', 
        'Get-PowerStigSqlConfig', 
        'Set-PowerStigSqlConfig',
        'Get-PowerStigConfig',
        'Set-PowerStigConfig',
        'Invoke-PowerStigBatch',
        'Get-PowerStigComputer',
        'Set-PowerStigComputer',
        'Remove-PowerStigComputer'
        )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = '*'
    
    # DSC resources to export from this module
    # DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    # ModuleList = @()
    
    # List of all files packaged with this module
    # FileList = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # A URL to the main website for this project.
            # ProjectUri = ''
    
            # A URL to an icon representing this module.
            # IconUri = ''
    
            # ReleaseNotes of this module
            ReleaseNotes = 'Removed dependencies on DSCEA.
                            Added support for PowerStig 2.3.2.0
                            Added Support for Win10, Office, Firefox, IIS site and server, .Net, SqlServer Composites'
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
    
    # HelpInfo URI of this module
    # HelpInfoURI = ''
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
    
    }