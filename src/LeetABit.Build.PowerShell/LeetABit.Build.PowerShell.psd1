#########################################################################################
# Copyright (c) Hubert Bukowski. All rights reserved.
# Licensed under the MIT License.
# See License.txt in the project root for full license information.
#
# Manifest file for LeetABit.Build.PowerShell module.
#########################################################################################

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'LeetABit.Build.PowerShell.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.1'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = '03e3f780-4cfe-4ec9-b1c5-6c2bb61f6c3a'

    # Author of this module
    Author = 'Hubert Bukowski'

    # Company or vendor of this module
    CompanyName = 'Leet'

    # Copyright statement for this module
    Copyright = 'Copyright (c) Hubert Bukowski. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Provides basic checks and deployment for PowerShell projects.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '6.0'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ModuleName = 'LeetABit.Build.Common'; ModuleVersion = '0.0.5'; },
        @{ModuleName = 'LeetABit.Build.Logging'; ModuleVersion = '0.0.5'; }
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @('LeetABit.Build.PowerShell.Types.ps1xml')

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @('LeetABit.Build.PowerShell.Format.ps1xml')

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Find-ModulePath',
        'Find-ProjectPath',
        'Find-ScriptPath',
        'Get-Markdown',
        'Read-ReferenceDocumentation',
        'Publish-Project',
        'Save-ProjectPackage',
        'Test-Project',
        'Invoke-ProjectAnalysis',
        'Set-CodeSignature',
        'Build-Project',
        'Clear-Project',
        'Measure-UseCommentBasedHelp',
        'Get-ContainingModule',
        'Find-ModulePath'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList = @(
        'LeetABit.Build.PowerShell.AnalysisRules.ps1'
        'LeetABit.Build.PowerShell.Format.ps1xml'
        'LeetABit.Build.PowerShell.psm1'
        'LeetABit.Build.PowerShell.Resources.psd1'
        'LeetABit.Build.PowerShell.Types.ps1xml'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Prerelease version information.
            Prerelease = '-alpha40'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('LeetABit', 'Build', 'PowerShell')

            # A URL to the license for this module.
            LicenseUri = 'https://raw.githubusercontent.com/Leet/Build/master/LICENSE.txt'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Leet/Build'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @"
# 0.1.1 - 2023-11-04

    wip
    Initial commit.

"@

            # External dependencies.
            ExternalModuleDependencies = @(
                'LeetABit.Build.Common',
                'LeetABit.Build.Logging'
            )

        } # End of PSData hashtable

        AnalyzeDependencies = @(
            @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.21.0'; }
        )

        TestDependencies = @(
            @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; }
        )

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

    }
