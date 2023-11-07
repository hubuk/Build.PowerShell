#requires -version 6
using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Security.Cryptography.X509Certificates
using namespace Microsoft.PowerShell.Commands
using module LeetABit.Build.Common

Set-StrictMode -Version 3.0
Import-LocalizedData -BindingVariable LocalizedData -FileName LeetABit.Build.PowerShell.Resources.psd1

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if (Get-Module 'LeetABit.Build.Extensibility') {
        LeetABit.Build.Extensibility\Unregister-BuildExtension "LeetABit.Build.PowerShell" -ErrorAction SilentlyContinue
    }
}

. (Join-Path $PSScriptRoot 'LeetABit.Build.PowerShell.AnalysisRules.ps1')

##################################################################################################################
# Extension Registration
##################################################################################################################


LeetABit.Build.Extensibility\Register-BuildExtension -Resolver {
    param (
        [String]
        $ResolutionRoot
    )

    process {
        Find-ProjectPath -LiteralPath $ResolutionRoot
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "clean" {
    <#
    .SYNOPSIS
        Cleans artifacts produced for the specified project.
    #>

    param (
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot
    )

    process {
        Clear-Project -LiteralPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "codegen" -Initialization {
    param(
        [String]
        $SourceRoot
    )

    process {
        Initialize-CodeGenTask -SourceRoot $SourceRoot
    }
} {
    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $Version,

        [String]
        $PrereleaseVersion,

        [String[]]
        $ReleaseNotes
    )

    process {
        Write-ProjectProperties -ProjectPath $ProjectPath -SourceRoot $SourceRoot -Version $Version -PrereleaseVersion $PrereleaseVersion -ReleaseNotes $ReleaseNotes
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "build" "codegen", {
    <#
    .SYNOPSIS
        Builds artifacts for the specified project.
    #>

    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot
    )

    process {
        Build-Project -LiteralPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "rebuild" ("clean", "build")

LeetABit.Build.Extensibility\Register-BuildTask "analyze" "rebuild", {
    <#
    .SYNOPSIS
        Analyzes artifacts of the specified project.
    #>

    param(
        [String]
        $ProjectPath,

        [String]
        $ArtifactsRoot
    )

    process {
        Invoke-ProjectAnalysis -ProjectPath $ProjectPath -ArtifactsRoot $ArtifactsRoot
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "test" "analyze", {
    <#
    .SYNOPSIS
        Tests specified project.
    #>

    param(
        [String]
        $ProjectPath,

        [String]
        $TestRoot,

        [String]
        $ArtifactsRoot
    )

    process {
        Test-Project -ProjectPath $ProjectPath -TestRoot $TestRoot -ArtifactsRoot $ArtifactsRoot
    }
}


LeetABit.Build.Extensibility\Register-BuildTask "sign" "test", {
    <#
    .SYNOPSIS
        Digitally signs the artifacts of the specified project.
    .PARAMETER Certificate
        Code Sign certificate to be used.
    .PARAMETER CertificatePath
        PowerShell Certificate Store path to the Code Sign certificate.
    .PARAMETER TimestampServer
        Code Sign Timestamp Server to be used.
    #>

    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot,

        [Parameter(Position = 2,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'Certificate')]
        [X509Certificate2]
        $Certificate,

        [Parameter(Position = 2,
                   Mandatory = $False,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'CertificatePath')]
        [String]
        $CertificatePath,

        [Parameter(Position = 3,
                   Mandatory = $False,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $TimestampServer
    )

    process {
        $certificateParameters = @{}

        if ($PSCmdlet.ParameterSetName -eq 'Certificate') {
            $certificateParameters['Certificate'] = $Certificate
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'CertificatePath') {
            $certificateParameters['CertificatePath'] = $CertificatePath
        }

        Set-CodeSignature -ProjectPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot -TimestampServer $TimestampServer @certificateParameters
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "pack" -IsDefault "sign", {
    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot
    )

    process {
        Save-ProjectPackage -ProjectPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "publish" "pack", {
    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot,

        [String]
        $NugetApiKey)

    process {
        Publish-Project -ProjectPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot -NugetApiKey $NugetApiKey
    }
}

LeetABit.Build.Extensibility\Register-BuildTask "docgen" {
    param(
        [String]
        $ProjectPath,

        [String]
        $SourceRoot,

        [String]
        $ArtifactsRoot,

        [String]
        $ReferenceDocsRoot
    )

    process {
        Write-ReferenceDocumentation -ProjectPath $ProjectPath -SourceRoot $SourceRoot -ArtifactsRoot $ArtifactsRoot -ReferenceDocsRoot $ReferenceDocsRoot
    }
}

##################################################################################################################
# Public Commands
##################################################################################################################


function Get-ContainingModule {
    param (
        [ScriptBlock]
        $ScriptBlock
    )

    process {
        if ($ScriptBlock.Module) {
            return $ScriptBlock.Module
        }

        $candidatePath = Split-Path $ScriptBlock.File
        while ($candidatePath) {
            $modules = Find-ModulePath $candidatePath
            if ($modules) {
                foreach ($module in $modules) {
                    $moduleInfo = Get-Module $module -ListAvailable
                    if (Test-ModuleContainsFile -Module $moduleInfo -File $ScriptBlock.File) {
                        return $moduleInfo
                    }
                }
            }

            $candidatePath = Split-Path $candidatePath
        }
    }
}

function Test-ModuleContainsFile
{
    param (
        [PSModuleInfo]
        $Module,

        [String]
        $FilePath
    )

    begin {
        $normalizedFilePAth = (LeetABit.Build.Common\ConvertTo-NormalizedPath $FilePath)
    }

    process {
        $moduleDirPath = Split-Path (LeetABit.Build.Common\ConvertTo-NormalizedPath $Module.Path)

        foreach ($file in ($Module.FileList + (LeetABit.Build.Common\ConvertTo-NormalizedPath (Join-Path $moduleDirPath $Module.RootModule)))) {
            if ($normalizedFilePAth -eq $file) {
                return $true
            }
        }

        return $false
    }
}

function Find-ModulePath {
    <#
    .SYNOPSIS
        Finds paths to all PowerShell module directories in the specified path.
    .DESCRIPTION
        The Find-ModulePath cmdlet searches for a PowerShell modules in the specified location and returns a path to each module's directory found.
    .PARAMETER Path
        Path to the search directory.
    .PARAMETER LiteralPath
        Literal path to the search directory.
    .EXAMPLE
        PS > Find-ModulePath -Path "C:\Modules"

        Returns paths to all PowerShell module directories located in the specified location.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   SupportsShouldProcess = $False,
                   DefaultParameterSetName = 'Path')]
    [OutputType([String])]

    param (
        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'Path')]
        [String[]]
        $Path,

        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'LiteralPath')]
        [String[]]
        $LiteralPath,

        [Switch]
        $Recurse)

    begin {
        Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $SelectedPath = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $LiteralPath }
        $parameters = @{ "$($PSCmdlet.ParameterSetName)" = $SelectedPath }
        if (-not $Recurse) {
            $parameters.Depth = 0
        }
    }

    process {
        Get-ChildItem @parameters -Filter "*.psd1" -Exclude "*.Resources.psd1" -Recurse | Where-Object {
            Test-Path -Path $_.FullName -PathType Leaf
        } | Split-Path | Convert-Path | Select-Object -Unique
    }
}


function Find-ScriptPath {
    <#
    .SYNOPSIS
        Finds paths to all script files in the specified path.
    .DESCRIPTION
        The Find-ScriptPath cmdlet searches for a script in the specified location and returns a path to each file found.
    .PARAMETER Path
        Path to the search directory.
    .PARAMETER LiteralPath
        Literal path to the search directory.
    .EXAMPLE
        PS > Find-ScriptPath -Path "C:\Modules"

        Returns paths to all scripts located in the specified directory.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   SupportsShouldProcess = $False,
                   DefaultParameterSetName = 'Path')]
    [OutputType([String])]

    param (
        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'Path')]
        [String[]]
        $Path,

        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'LiteralPath')]
        [String[]]
        $LiteralPath)

    begin {
        Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $SelectedPath = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $LiteralPath }
        $parameters = @{ "$($PSCmdlet.ParameterSetName)" = $SelectedPath }
    }

    process {

        ("*.sh", "*.cmd", "*.ps1") | ForEach-Object {
            Get-ChildItem @parameters -Filter $_ -Recurse
        }
    }
}


function Find-ProjectPath {
    <#
    .SYNOPSIS
        Finds paths to all script files and PowerShell module directories in the specified path.
    .DESCRIPTION
        The Find-ProjectPath cmdlet searches for a script or module in the specified location and returns a path to each item found.
    .PARAMETER Path
        Path to the search directory.
    .PARAMETER LiteralPath
        Literal path to the search directory.
    .EXAMPLE
        PS > Find-ProjectPath -Path "C:\Modules"

        Returns paths to all scripts and modules located in the specified directory.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   SupportsShouldProcess = $False,
                   DefaultParameterSetName = 'Path')]
    [OutputType([String])]

    param (
        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'Path')]
        [String[]]
        $Path,

        [Parameter(HelpMessage = 'Provide path to the search directory.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'LiteralPath')]
        [String[]]
        $LiteralPath)

    begin {
        Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $SelectedPath = if ($PSCmdlet.ParameterSetName -eq 'Path') { $Path } else { $LiteralPath }
        $parameters = @{ "$($PSCmdlet.ParameterSetName)" = $SelectedPath }
    }

    process {
        $directories = Find-ModulePath @parameters -Recurse

        $directories | ForEach-Object {
            Write-Verbose -Message "Found PowerShell module directory: '$_'"
            $_
        }

        Find-ScriptPath @parameters | Where-Object {
            -not (Test-PathInContainer -Path $_.FullName -Container $directories)
        } | ForEach-Object {
            Write-Verbose -Message "Found script file: '$_'"
            $_.FullName
        }
    }
}


function Get-Markdown {
    <#
    .SYNOPSIS
        Gets text that represents a markdown document for the specified PowerShell help object.
    .PARAMETER HelpObject
        Custom object that represents command help.
    #>

    [CmdletBinding(PositionalBinding = $False)]

    param (
        [Parameter(Position = 0,
                Mandatory = $True,
                ValueFromPipeline = $True,
                ValueFromPipelineByPropertyName = $True)]
        [PSCustomObject]
        $HelpObject
    )

    begin {
        LeetABit.Build.Common\Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        Set-StrictMode -Off
    }

    process {
        try {
            $name = $HelpObject.Name

            if ($name -and [System.IO.Path]::IsPathRooted($name)) {
                $name = Split-Path $name -Leaf
            }

            Write-Output "# $name"
            Write-Output ""
            Write-Output "$($HelpObject.Synopsis)"

            $HelpObject.Syntax.SyntaxItem | ForEach-Object {
                $syntax = $_.Name

                if ($syntax -and [System.IO.Path]::IsPathRooted($syntax)) {
                    $syntax = Split-Path $syntax -Leaf
                }

                $syntax = "``````$syntax"

                if ($_.psobject.Properties.name -match "Parameter") {
                    $_.Parameter | ForEach-Object {
                        $optional = $_.required -ne 'true'
                        $positional = (($_.position -ne $()) -and ($_.position -ne '') -and ($_.position -notmatch 'named') -and ([int]$_.position -ne $()))
                        $parameterValue = ''
                        if ($_.psobject) {
                            $parameterValue = if ($null -ne $_.psobject.Members['ParameterValueGroup']) {
                                " {$($_.ParameterValueGroup.ParameterValue -join ' | ')}"
                            } elseif ($null -ne $_.psobject.Members['ParameterValue']) {
                                " <$($_.ParameterValue)>"
                            }
                        }

                        $value = $(if ($optional -and $positional) { ' [[-{0}]{1}]' }
                        elseif ($optional)   { ' [-{0}{1}]' }
                        elseif ($positional) { ' [-{0}]{1}' }
                        else                 { ' -{0}{1}' }) -f $_.Name, $parameterValue

                        $syntax += $value
                    }
                }

                $syntax += "``````"
                Write-Output ""
                Write-Output $syntax
            }

            if ($HelpObject.psobject.Properties.name -match "Description" -and $HelpObject.Description) {
                Write-Output ""
                Write-Output "## Description"
                Write-Output ""
                Write-Output "$($HelpObject.Description.Text)"
            }

            $exampleNumber = 1;
            if ((Get-Member -InputObject $HelpObject -Name "Examples") -and ($HelpObject.Examples) -and (Get-Member -InputObject ($HelpObject.Examples) -Name "Example")) {
                Write-Output ""
                Write-Output "## Examples"
                $HelpObject.Examples.Example | ForEach-Object {
                    Write-Output ""
                    Write-Output "### Example $exampleNumber`:"
                    Write-Output ""
                    Write-Output "``````$($_.Introduction.Text) $($_.Code)``````"
                    Write-Output ""
                    Write-Output $($_.Remarks.Text -replace "#`>", "#>" -join [System.Environment]::NewLine).TrimEnd()
                    $exampleNumber += 1
                }
            }

            Write-Output ""
            Write-Output "## Parameters"
            if ($HelpObject.Parameters.psobject.Properties.name -match "Parameter") {
                $HelpObject.Parameters.Parameter | ForEach-Object {
                    Write-Output ""
                    Write-Output "### ``````-$($_.Name)``````"
                    $_ | Select-Object -Property Description | ForEach-Object {
                        if ($_.Description) {
                            Write-Output ""
                            Write-Output "*$($_.Description.Text)*"
                        }
                    }

                    Write-Output ""
                    Write-Output "<table>"
                    Write-Output "  <tr><td>Type:</td><td>$($_.Type.Name)</td></tr>"
                    Write-Output "  <tr><td>Required:</td><td>$($_.Required)</td></tr>"
                    Write-Output "  <tr><td>Position:</td><td>$((Get-Culture).TextInfo.ToTitleCase($_.Position))</td></tr>"
                    Write-Output "  <tr><td>Default value:</td><td>$($_.DefaultValue)</td></tr>"
                    Write-Output "  <tr><td>Accept pipeline input:</td><td>$($_.PipelineInput)</td></tr>"
                    Write-Output "  <tr><td>Accept wildcard characters:</td><td>$($_.Globbing)</td></tr>"
                    Write-Output "</table>"
                }
            }

            Write-Output ""
            Write-Output "## Input"
            if (Get-Member -InputObject $HelpObject -Name "InputTypes") {
                $HelpObject.InputTypes | ForEach-Object {
                    Write-Output ""
                    Write-Output "``````[$($_.InputType.Type.Name.Trim())]``````"
                }
            }
            else {
                Write-Output ""
                Write-Output "None"
            }

            Write-Output ""
            Write-Output "## Output"
            if (Get-Member -InputObject $HelpObject -Name "ReturnValues") {
                $HelpObject.ReturnValues | ForEach-Object {
                    Write-Output ""
                    Write-Output "``````[$($_.ReturnValue.Type.Name.Trim())]``````"
                }
            }
            else {
                Write-Output ""
                Write-Output "None"
            }

            if ((Get-Member -InputObject $HelpObject -Name "Notes") -or (Get-Member -InputObject $HelpObject -Name "AlertSet")) {
                Write-Output ""
                Write-Output "## Notes"
                if (Get-Member -InputObject $HelpObject -Name "Notes") {
                    Write-Output ""
                    Write-Output "$HelpObject.Notes"
                }

                if (Get-Member -InputObject $HelpObject -Name "AlertSet") {
                    foreach ($alert in $HelpObject.AlertSet) {
                        foreach ($alertItem in $alert.alert) {
                            Write-Output ""
                            Write-Output $alertItem.Text
                        }
                    }
                }
            }

            if (Get-Member -InputObject $HelpObject -Name "RelatedLinks") {
                Write-Output ""
                Write-Output "## Related Links"
                $HelpObject.RelatedLinks.NavigationLink | ForEach-Object {
                    Write-Output ""
                    if ($_.LinkText -notmatch "^about_") {
                        Write-Output "[$($_.LinkText)]($(($_.LinkText) -replace "\\", "/").md)"
                    }
                    else {
                        Write-Output "[$($_.LinkText)](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/$($_.LinkText))"
                    }
                }
            }
        }
        finally {
            Set-StrictMode -Version 3.0
        }
    }
}


function Clear-Project {
    <#
    .SYNOPSIS
        Cleans artifacts produced for the specified project.
    .PARAMETER LiteralPath
        Path to the project which artifacts have to be cleaned.
    .PARAMETER SourceRoot
        Path to the source root directory.
    .PARAMETER ArtifactsRoot
        Path to the artifacts root directory.
    #>
    [CmdletBinding(PositionalBinding = $False)]

    param(
        [Parameter(HelpMessage = 'Provide path for the project which artifacts have to be cleaned.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $LiteralPath,

        [Parameter(HelpMessage = 'Provide path for the source root directory.',
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $SourceRoot,

        [Parameter(HelpMessage = 'Provide path for the artifacts root directory.',
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $ArtifactsRoot
    )

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $LiteralPath -Base $SourceRoot
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath

        if (Test-Path $LiteralPath -PathType Leaf) {
            $itemPath = Get-Item $LiteralPath
            $path = Join-Path $itemPath.DirectoryName "$($itemPath.BaseName).*.nupkg"
            if (Test-Path $path) {
                Remove-Item $path -Force
            }
        }

        if (Test-Path $artifactPath) {
            Remove-Item $artifactPath -Recurse -Force
        }

        if ((Test-Path $ArtifactsRoot) -and -not (Get-ChildItem $ArtifactsRoot -File -Recurse)) {
            Remove-Item $ArtifactsRoot -Force -Recurse
        }
    }
}


function Build-Project {
    <#
    .SYNOPSIS
        Build specified PowerShell project.
    .PARAMETER LiteralPath
        Path to the project which artifacts have to be built.
    .PARAMETER SourceRoot
        Path to the source root directory.
    .PARAMETER ArtifactsRoot
        Path to the artifacts root directory.
    #>
    [CmdletBinding(PositionalBinding = $False)]

    param(
        [Parameter(HelpMessage = 'Provide path for the project which artifacts have to be cleaned.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $LiteralPath,

        [Parameter(HelpMessage = 'Provide path for the source root directory.',
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $SourceRoot,

        [Parameter(HelpMessage = 'Provide path for the artifacts root directory.',
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $ArtifactsRoot
    )

    process {
        LeetABit.Build.Common\Copy-ItemWithStructure -Path $LiteralPath -Base $SourceRoot -Destination $ArtifactsRoot
    }
}


function Set-CodeSignature {
    <#
    .SYNOPSIS
        Handler for PowerShell 'sign' target.
    .PARAMETER ProjectPath
        Path to the project which output shall be signed.
    .PARAMETER ArtifactsRoot
        Location of the repository artifacts directory to which the PowerShell files shall be copied.
    .PARAMETER SourceRoot
        Path to the project source directory.
    .PARAMETER Certificate
        Code Sign certificate to be used.
    .PARAMETER CertificatePath
        Path to the Code Sign certificate to be used.
    .PARAMETER TimestampServer
        Code Sign Timestamp Server to be used.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   DefaultParameterSetName = 'CertificatePath',
                   SupportsShouldProcess = $True)]
    param (
        [String]
        $ProjectPath,

        [Parameter(HelpMessage = 'Provide path to the repository artifacts directory to which the PowerShell files shall be copied.',
                   Position = 1,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $ArtifactsRoot,

        [String]
        $SourceRoot,

        [Parameter(Position = 2,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Position = 2,
                   Mandatory = $False,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True,
                   ParameterSetName = 'CertificatePath')]
        [String]
        $CertificatePath,

        [Parameter(Position = 3,
                   Mandatory = $False,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $TimestampServer)

    begin {
        LeetABit.Build.Common\Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath

        $certificateParameters = @{}
        if ($PSCmdlet.ParameterSetName -eq 'Certificate') {
            $certificateParameters['Certificate'] = $Certificate
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'CertificatePath') {
            if (-not $CertificatePath) {
                return
            }

            $certificateParameters['CertificatePath'] = $CertificatePath
        }

        if (Test-Path -Path $artifactPath -PathType Container) {
            Get-ChildItem -Path $artifactPath -Include ('*.psd1', '*.ps1', '*.psm1', '*.ps1xml') -Recurse | ForEach-Object {
                if ($PSCmdlet.ShouldProcess($LocalizedData.Resource_DigitalSignatureOnFile -f $_,
                                            $LocalizedData.Operation_Set)) {
                    LeetABit.Build.Common\Set-DigitalSignature -Path $_ -TimestampServer $TimestampServer @certificateParameters
                }
            }

            $moduleName = Split-Path $artifactPath -Leaf
            $catalogFile = Join-Path $artifactPath "$moduleName.cat"
            if (Test-Path $catalogFile) {
                Remove-Item -Path $catalogFile -Force
            }

            $null = New-FileCatalog -CatalogFilePath $catalogFile -CatalogVersion 2.0 -Path $artifactPath
            if ($PSCmdlet.ShouldProcess($LocalizedData.Resource_DigitalSignatureOnFile -f $catalogFile,
                                        $LocalizedData.Operation_Set)) {
                LeetABit.Build.Common\Set-DigitalSignature -Path $catalogFile -TimestampServer $TimestampServer @certificateParameters
            }
        }
        elseif ($artifactPath.EndsWith(".ps1")) {
            if ($PSCmdlet.ShouldProcess($LocalizedData.Resource_DigitalSignatureOnFile -f $artifactPath,
                                        $LocalizedData.Operation_Set)) {
                LeetABit.Build.Common\Set-DigitalSignature -Path $artifactPath -TimestampServer $TimestampServer @certificateParameters
            }
        }
   }
}


function Invoke-ProjectAnalysis {
    param(
        [String]
        $ProjectPath,
        # Location of the repository artifacts directory to which the PowerShell files shall be copied.
        [Parameter(HelpMessage = 'Provide path to the repository artifacts directory to which the PowerShell files shall be copied.',
                   Position = 1,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $ArtifactsRoot,
        [String[]]
        $CustomRulePath
    )

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath

        $MyInvocation.MyCommand.Module.PrivateData.AnalyzeDependencies | LeetABit.Build.Common\New-PSObject | Install-DependencyModule

        Import-Module PSScriptAnalyzer -Force
        $violations = @()

        $violations += PSScriptAnalyzer\Invoke-ScriptAnalyzer $artifactPath
        $violations += PSScriptAnalyzer\Invoke-ScriptAnalyzer $artifactPath -CustomRulePath $PSScriptRoot

        if ($CustomRulePath) {
            $violations += $CustomRulePath | PSScriptAnalyzer\Invoke-ScriptAnalyzer $artifactPath -CustomRulePath $_
        }

        $violations | ForEach-Object { Write-Warning (($_ | Out-String).Trim() + [Environment]::NewLine) }
    }
}


function Test-Project {
    param(
        [String]
        $ProjectPath,

        # Location of the repository artifacts directory to which the PowerShell files shall be copied.
        [Parameter(HelpMessage = 'Provide path to the repository artifacts directory to which the PowerShell files shall be copied.',
                   Position = 1,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $TestRoot,

        [String]
        $ArtifactsRoot
    )

    process {
        $MyInvocation.MyCommand.Module.PrivateData.TestDependencies | LeetABit.Build.Common\New-PSObject | Install-DependencyModule

        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        $testPath = Join-Path $TestRoot $RelativeProjectPath
        if (-not (Test-Path $testPath)) {
            return;
        }

        $data = @{ ArtifactsRoot = $ArtifactsRoot; TestRoot = $TestRoot }

        Get-ChildItem -Path $testPath -Filter '*.Tests.ps1' -Recurse -File | ForEach-Object {
            $container = New-TestContainer -Path $_.FullName -Data $data
            $testResults = Invoke-Pester -Container $container -PassThru -Output None

            $describe = @{ "Name" = $Null }

            foreach ($testResult in $testResults.Tests) {
                if ($describe.Name -ne $testResult.Path[0]) {
                    if ($describe.Name) {
                        New-PSObject 'LeetABit.Build.PesterDescribeResult' $describe | Out-String | Write-Information
                    }

                    $describe = @{}
                    $describe.Name = $testResult.Path[0]
                    $describe.Failures = @()
                    $describe.TestsPassed = 0
                }

                if ($testResult.Passed) {
                    $describe.TestsPassed = $describe.TestsPassed + 1
                }
                else {
                    $failure = @{}
                    $failure.Name = $testResult.Name
                    $failure.Parameters = ConvertTo-ExpressionString $testResult.Data
                    $failure.Message = $testResult.FailureMessage.Replace('`r', [String]::Empty).Replace('`n', [String]::Empty)
                    $describe.Failures += New-PSObject 'LeetABit.Build.PesterTestFailure' $failure
                }
            }

            if ($describe) {
                New-PSObject 'LeetABit.Build.PesterDescribeResult' $describe | Out-String | Write-Information
            }
        }
    }
}


function Save-ProjectPackage {
    param(
        [String]
        $ProjectPath,
        [String]
        $SourceRoot,
        [String]
        $ArtifactsRoot
    )

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath | Convert-Path

        if (Test-Path $artifactPath -PathType Leaf -Exclude '*.ps1') {
            return
        }

        $guid = [String](New-Guid)

        $repositoryPath = "$artifactPath$guid"

        [void](New-Item $repositoryPath -ItemType Directory)

        try {
            [void](Register-PSRepository -Name $guid -SourceLocation $repositoryPath -ScriptSourceLocation $repositoryPath)
            try {
                if (Test-Path -Path $artifactPath -PathType Leaf) {
                    try {
                        if (-not (Test-ScriptFileInfo -Path $artifactPath -ErrorAction SilentlyContinue)) {
                            return
                        }
                    }
                    catch {
                        return
                    }

                    Publish-Script -Path $artifactPath -Repository $guid
                }
                else {
                    Publish-Module -Path $artifactPath -Repository $guid
                }
            }
            finally {
                Unregister-PSRepository -Name $guid
            }

            if (Test-Path -Path $artifactPath -PathType Leaf) {
                $archivePath = Join-Path (Split-Path $artifactPath) "$((Get-Item -Path $artifactPath).BaseName).zip"
                $contentPath = $artifactPath
            }
            else {
                $archivePath = Join-Path $artifactPath "$((Get-Item -Path $artifactPath).Name).zip"
                $contentPath = Resolve-Path "$artifactPath\*"
            }

            Compress-Archive -Path $contentPath -DestinationPath $archivePath -Update

            $nupkg = Join-Path $repositoryPath "*.nupkg"
            $nupkgPath = Get-Item $nupkg

            $destinationPath = if (Test-Path $artifactPath -PathType Leaf) {
                Join-Path (Get-Item $artifactPath).DirectoryName $nupkgPath.Name
            }
            else {
                $artifactPath
            }

            if (Test-Path -Path $artifactPath -PathType Container) {
                $moduleName = (Get-Item $ProjectPath).BaseName

                $nupkgDestinationDir = Join-Path $nupkgPath.DirectoryName $nupkgPath.BaseName
                $progressBackup = $global:ProgressPreference
                $global:ProgressPreference = 'SilentlyContinue'
                Expand-Archive -Path $nupkgPath.FullName -DestinationPath $nupkgDestinationDir
                $global:ProgressPreference = $progressBackup

                Remove-Item $nupkgPath.FullName -Recurse -Force

                $data = Import-PowerShellDataFile -Path (Join-Path $nupkgDestinationDir ($moduleName + ".psd1"))

                $xmlFile = Join-Path $nupkgDestinationDir ($moduleName + ".nuspec")
                [xml]$xmlDoc = Get-Content ($xmlFile)
                $dependencies = $xmlDoc.CreateElement("dependencies", $xmlDoc.package.xmlns)
                [void]$xmlDoc.package.metadata.AppendChild($dependencies)

                foreach ($d in $data.RequiredModules) {
                    $dep = $xmlDoc.CreateElement("dependency", $xmlDoc.package.xmlns)
                    $idAtt = $xmlDoc.CreateAttribute("id")
                    $idAtt.Value = $d.ModuleName
                    [void]$dep.Attributes.Append($idAtt)

                    $versionAtt = $xmlDoc.CreateAttribute("version")
                    $versionAtt.Value = $d.ModuleVersion
                    [void]$dep.Attributes.Append($versionAtt)

                    [void]$dependencies.AppendChild($dep)
                }

                $xmlDoc.Save($xmlFile)

                $progressBackup = $global:ProgressPreference
                $global:ProgressPreference = 'SilentlyContinue'
                Compress-Archive -Path (Join-Path $nupkgDestinationDir "*") -DestinationPath (Join-Path $artifactPath ($nupkgPath.BaseName + ".nupkg"))
                $global:ProgressPreference = $progressBackup
            }
            else {
                Move-Item -Path $nupkgPath.FullName -Destination $destinationPath
            }
        }
        finally {
            Remove-Item $repositoryPath -Recurse -Force
        }
    }
}


function Publish-Project {
    <#
    .SYNOPSIS
    Gets text that represents a markdown document for the specified PowerShell help object.
    #>

    [CmdletBinding(PositionalBinding = $False)]

    param(
        [String]
        $ProjectPath,
        [String]
        $SourceRoot,
        [String]
        $ArtifactsRoot,
        [String]
        $NugetApiKey
    )

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath

        $packages = if (Test-Path $artifactPath -PathType Leaf) {
            $itemPath = Get-Item $artifactPath
            Get-ChildItem -Path $itemPath.DirectoryName -Include (Join-Path $itemPath.DirectoryName "$($itemPath.BaseName).*.nupkg")
        }
        else {
            Get-ChildItem -Path $artifactPath -Include '*.nupkg' -Recurse
        }

        foreach ($package in $packages) {
            Invoke-WebRequest -Method "PUT" -Uri "https://www.powershellgallery.com/api/v2/package/" -SslProtocol Tls12 -Headers @{ "X-NuGet-ApiKey" =  $NugetApiKey; "X-NuGet-Client-Version" = "5.7.0"} -ContentType "multipart/form-data" -InFile $package
        }
    }
}

function Initialize-CodeGenTask {
    param(
        [String]
        $SourceRoot
    )

    process {
        # ? current task name?

        $version = Get-GitSemVer -Version1 -NoPreRelease
        $prereleaseVersion = (Get-GitSemVer -Version1).Substring($version.Length)
        $releaseNotes = Get-GitReleaseNotes
        LeetABit.Build.Arguments\Add-CommandArgument -ParameterName 'LeetABitBuildPowerShell_Version' -ParameterValue $version
        LeetABit.Build.Arguments\Add-CommandArgument -ParameterName 'LeetABitBuildPowerShell_PrereleaseVersion' -ParameterValue $prereleaseVersion
        LeetABit.Build.Arguments\Add-CommandArgument -ParameterName 'LeetABitBuildPowerShell_ReleaseNotes' -ParameterValue $releaseNotes
    }
}

function Write-ProjectProperties {
    param(
        [String]
        $ProjectPath,
        [String]
        $SourceRoot,
        [String]
        $Version,
        [String]
        $PrereleaseVersion,
        [String[]]
        $ReleaseNotes
    )

    process {
        $TaskName = LeetABit.Build.Arguments\Find-CommandArgument -ParameterName 'TaskName' -DefaultValue 'codegen'
        $projects = Resolve-Project $SourceRoot 'LeetABit.Build.Repository' $TaskName
        $modules = $projects | Where-Object { ($_[1] -eq 'LeetABit.Build.PowerShell') -and (Test-Path $_[0] -PathType Container)} | ForEach-Object { Split-Path $_[0] -Leaf }

        $projectItem = Get-Item $ProjectPath
        $manifestPath = Join-Path $projectItem.FullName "$($projectItem.BaseName).psd1"
        if (Test-Path $manifestPath -PathType Leaf) {
            $content = [List[String]](Get-Content $manifestPath)

            if (Test-Path $ProjectPath -PathType Container) {
                $scriptsPath = Join-Path $ProjectPath 'Scripts'
                $files = Get-ChildItem -Path $ProjectPath -File -Recurse |
                        Foreach-Object { $_.FullName } |
                        Where-Object { $_ -ne $manifestPath } |
                        ForEach-Object { "        '$(Resolve-RelativePath $_ $ProjectPath)'" }
                if ((Test-Path $scriptsPath -PathType Container) -and (Get-ChildItem -Path $scriptsPath -File)) {
                    $functions = @()
                    $lines = @()
                    $directories = [Stack]@($scriptsPath)

                    while ($directories.Count -gt 0) {
                        $directory = $directories.Pop()
                        $relative = Resolve-RelativePath $directory $scriptsPath
                        $depth = if ($relative -eq '.') { 0 } else { $relative.Split([Path]::DirectorySeparatorChar).Count }
                        $subdirectoryName = [Path]::GetFileName($directory)
                        $lines += "$("    " * ($depth + 2))# $subdirectoryName"

                        Get-ChildItem $directory -File | ForEach-Object {
                            $relaativePath = Resolve-RelativePath $_.FullName $ProjectPath
                            $lines += "$("    " * ($depth + 2))'.$([Path]::DirectorySeparatorChar)$relaativePath'"
                            $fileName = [Path]::GetFileNameWithoutExtension($relaativePath)
                            if ($subdirectoryName -ne 'Private' -and $fileName.Contains('-')) {
                                $functions += "        '$fileName'"
                            }
                        }

                        $subdirectories = @(Get-ChildItem $directory -Directory)
                        [array]::Reverse($subdirectories)
                        $subdirectories | ForEach-Object {
                            $directories.Push($_.FullName)
                        }
                    }

                    $content = Update-MultilineProperty -lines $content -BeginingPattern '    NestedModules = @(' -EndPattern '    )' -Content $lines

                    $content = Update-MultilineProperty -lines $content -BeginingPattern '    FunctionsToExport = @(' -EndPattern '    )' -Content $functions
                }

                $content = Update-MultilineProperty -lines $content -BeginingPattern '    FileList = @(' -EndPattern '    )' -Content $files

                $content = Update-MultilineProperty -lines $content -BeginingPattern '            ReleaseNotes = @"' -EndPattern '"@' -Content $ReleaseNotes

                for ($i = 0; $i -lt $content.Count; $i = $i + 1) {
                    if ($PrereleaseVersion) {
                        $content = $content -replace "^(\s+)Prerelease = '[^']*'", "`$1Prerelease = '$PrereleaseVersion'"
                    }
                    $content = $content -replace "^(\s+)ModuleVersion = '\d+\.\d+\.\d+'", "`$1ModuleVersion = '$Version'"
                    $modules | ForEach-Object {
                        $content = $content -replace "@{ModuleName = '$_'; ModuleVersion = '\d+.\d+.\d+'; }", "@{ModuleName = '$_'; ModuleVersion = '$Version'; }"
                    }
                }

                $content | Out-File $manifestPath
            }
        }
    }
}

function Update-MultilineProperty {
    param (
        [List[String]]
        $lines,

        [String]
        $BeginingPattern,

        [String]
        $EndPattern,

        [String[]]
        $Content
    )

    process {
        $start = $lines.IndexOf($BeginingPattern)
        if ($start -ge 0) {
            $end = $lines.IndexOf($EndPattern, $start)
            if ($end -ge 0) {
                $lines.RemoveRange($start + 1, $end - $start - 1)
                $lines.InsertRange($start + 1, $Content)
            }
        }

        $lines
    }
}

function Get-GitReleaseNotes {
    param(
        [String]
        $TagPattern = "()"
    )

    process {
        $TagPattern = $TagPattern -replace '\(\)', '([0-9]+)\.([0-9]+)\.([0-9]+)'
        $result = @()
        $commits = git rev-list HEAD
        $recent = $null

        foreach ($commit in $commits) {
            $tagName = Invoke-Expression "git describe --tags --abbrev=0 $commit --always"
            $version = if ($tagName -match $TagPattern) {
                $tagName
            } else {
                $version
            }

            $date = Invoke-Expression "git show -s --format=%cd --date=short $commit"
            $message = Invoke-Expression "git show -s --format=%s $commit"

            if (-not $recent -or -not $recent.ContainsKey('version') -or $recent.version -ne $version) {
                $recent = @{
                    version = $version
                    date = $date
                    message = @()
                }

                $result += $recent
            }

            $recent.message += $message
        }

        $result | ForEach-Object {
            "# $($_.version) - $($_.date)"
            ""
            $_.message | ForEach-Object {
                "    $_"
            }
            ""
        }
    }
}

function Get-GitSemVer {
    param(
        [Switch]
        $NoBranch,
        [Switch]
        $NoHash,
        [Switch]
        $NoTimestamp,
        [Switch]
        $NoLocal,
        [Switch]
        $NoPreRelease,
        [Switch]
        $SingleStep,
        [String]
        $TagPattern = "()",
        [String]
        $MajorPattern = "^Breaking:",
        [String]
        $MinorPattern = "^Feature:",
        [Switch]
        $Version1
    )

    process {
        $major = 0
	    $minor = 1
	    $patch = 0

        $lastVersionedCommit = git describe --tags --abbrev=0 --match '?*.?*.?*' --always
        $TagPattern = $TagPattern -replace '\(\)', '([0-9]+)\.([0-9]+)\.([0-9]+)'

        if ($lastVersionedCommit -match $TagPattern) {
            Write-Verbose "Version tag has been found: $lastVersionedCommit."
            $major=$matches[1]
            $minor=$matches[2]
            $patch=$matches[3]
        } else {
            Write-Verbose 'Version tag has not been found.'
            $lastVersionedCommit = git rev-list --max-parents=0 HEAD
        }

        Write-Verbose "Last versioned commit: $lastVersionedCommit"
        $commits = Invoke-Expression "git rev-list $lastVersionedCommit..HEAD --reverse"


        $commits | ForEach-Object {
            $changes = 0
            Write-Verbose "Analyzing commit $_"
            $show = Invoke-Expression "git show -s --format=%s $_"
            if ($show -match $MajorPattern) {
                $changes = 3
            } elseif ($show -match $MinorPattern) {
                if ($changes -lt 2) {
                    $changes = 2
                }
            } else {
                if ($changes -lt 1) {
                    $changes = 1
                }
            }

            if (-not $SingleStep) {
                if ($changes -eq 3) {
                    $major = [int]$major + 1
                    $minor = 0
                    $patch = 0
                } elseif ($changes -eq 2) {
                    $minor = [int]$minor + 1
                    $patch = 0
                } elseif ($changes -eq 1) {
                    $patch = [int]$patch + 1
                }

                $changes = 0
            }
        }

        if ($SingleStep) {
            if ($changes -eq 3) {
                $major = [int]$major + 1
                $minor = 0
                $patch = 0
            } elseif ($changes -eq 2) {
                $minor = [int]$minor + 1
                $patch = 0
            } elseif ($changes -eq 1) {
                $patch = [int]$patch + 1
            }
        }

        $result = "$major.$minor.$patch"

        if ($Version1) {
            if (-not $NoPreRelease) {
                $status = git status --porcelain
                if ($status) {
                    $result = "$result-alpha"
                    if ($commits) {
                        $result = "$result$($commits.Length)"
                    }
                } elseif ($commits) {
                    $result = "$result-beta$($commits.Length)"
                }
            }
        } else {
            if (-not $NoPreRelease -and $commits) {
                $result = "$result-beta.$($commits.Length)"
            }

            if (-not $NoLocal) {
                $status = git status --porcelain
                if ($status) {
                    $result = "$result-local"
                }
            }

            if (-not $NoBranch) {
                $result = "$result+Branch.$(git rev-parse --abbrev-ref HEAD)"
            }

            if (-not $NoHash) {
                $result="$result+Hash.$(git rev-parse HEAD)"
            }

            if (-not $NoTimestamp) {
                $result="$result+Timestamp.$(Get-Date -Format 'DyyyyMMddTHHmmss.fffffff')"
            }
        }

        $result
    }
}

function Write-ReferenceDocumentation {
    param(
        [String]
        $ProjectPath,
        [String]
        $SourceRoot,
        [String]
        $ArtifactsRoot,
        [String]
        $ReferenceDocsRoot
    )

    process {
        $RelativeProjectPath = Resolve-RelativePath -Path $ProjectPath -Base $SourceRoot
        if (-not $PSBoundParameters.Keys.Contains('ReferenceDocsRoot') -or -not $ReferenceDocsRoot) {
            $ReferenceDocsRoot = $ArtifactsRoot
        }

        $outputPath = Join-Path $ReferenceDocsRoot $RelativeProjectPath
        $artifactPath = Join-Path $ArtifactsRoot $RelativeProjectPath

        if (Test-Path $artifactPath -PathType Container) {
            $itemPath = Get-Item $artifactPath
            $definition = Import-PowerShellDataFile (Join-Path $itemPath.FullName "$($itemPath.BaseName).psd1")

            foreach ($function in $definition.FunctionsToExport) {

                Write-Message "Generating documentation for cmdlet: '$function'."
                $ParamList = @{
                    ArtifactPath = $artifactPath
                    PowerShellRoot = $PSScriptRoot
                    FunctionName = $function
                    OutputPath = $outputPath
                }

                $PowerShell = [powershell]::Create()
                [void]$PowerShell.AddScript({
                    Param ($ArtifactPath, $PowerShellRoot, $FunctionName, $OutputPath)

                    try {
                        $module = Import-Module $ArtifactPath -PassThru
                        if (-not (Get-Module -Name LeetABit.Build.PowerShell)) {
                            Import-Module $PowerShellRoot
                        }

                        $helpItem = Get-Help ($module.ExportedFunctions[$FunctionName]) -Full
                        LeetABit.Build.PowerShell\Get-Markdown $helpItem | ForEach-Object {
                            $_.Replace("`n", [Environment]::NewLine)
                        } | Set-Content -Path (Join-Path $OutputPath "$($FunctionName).md")
                    }
                    catch {
                        $_
                    }
                }).AddParameters($ParamList)
                try {
                    $errorItem = $PowerShell.Invoke()

                    if ($errorItem) {
                        throw ( New-Object RuntimeException( "Could not generate documentation for function '$function'.", $Null, $errorItem[0] ) )
                    }
                    elseif ($PowerShell.HadErrors) {
                        throw "Could not generate documentation for function '$function'."
                    }
                }
                finally {
                    $PowerShell.Dispose()
                }
            }
        }
        elseif ($artifactPath.EndsWith(".ps1")) {
            $helpItem = Get-Help $artifactPath -Full
            $itemPath = Get-Item $artifactPath
            $dir = Split-Path $outputPath
            if (-not (Test-Path $dir -PathType Container)) {
                if (Test-Path $dir -PathType Leaf) {
                    Remove-Item $dir -Force
                }

                [void](New-Item $dir -ItemType Directory -Force)
            }

            Get-Markdown $helpItem | ForEach-Object {
                $_.Replace("`n", [Environment]::NewLine)
            } | Set-Content -Path (Join-Path (Split-Path $outputPath) "$($itemPath.BaseName).md")
        }
    }
}

##################################################################################################################
# Private Commands
##################################################################################################################


function Join-Arguments ([OrderedDictionary] $arguments) {
    $firstArgumentAdded = $False
    $result = ''
    foreach ($parameterName in $arguments.Keys) {
        if ($firstArgumentAdded) { $result += "; " }
        $result += "$parameterName = '$($arguments[$parameterName])'"
        $firstArgumentAdded = $True
    }

    return $result
}


function Get-PowerShellProjectsPattern {
    <#
    .SYNOPSIS
        Gets a path pattern to all artifacts produced by PowerShell projects.
    #>
    [CmdletBinding(PositionalBinding = $False)]
    [OutputType([String])]

    param (
        # Specified whether only signable files shall be obtained.
        [Parameter(Position = 1,
                   Mandatory = $False,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [Switch]
        $SignableOnly)

    process {
        $extensions = ('^.*(?<!Resources)\.psd1', '^.+\.ps1$')

        if (-not $SignableOnly) {
            $extensions += ('^.+\.sh$', '^.+\.cmd$')
        }

        $extensions
    }
}


function New-ModuleFileCatalog {
    <#
    .SYNOPSIS
    Sets an Authenticode Signature for all powershell artifacts.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   SupportsShouldProcess = $True,
                   ConfirmImpact = "Low")]
    [OutputType([System.IO.FileInfo])]

    param (
        # Path to the module manifest file.
        [Parameter(HelpMessage = 'Provide path to the module manifest file.',
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $True,
                   ValueFromPipelineByPropertyName = $True)]
        [System.IO.FileInfo]
        $ModuleFile)

    process {
        $directoryPath = $ModuleFile.Directory.FullName
        $catalogFile = Join-Path $directoryPath "$($ModuleFile.BaseName).cat"
        if ($PSCmdlet.ShouldProcess($LocalizedData.Resource_FileCatalog,
                                    $LocalizedData.Operation_New)) {
            New-FileCatalog -CatalogFilePath $catalogFile -CatalogVersion 2.0 -Path $directoryPath
        }
    }
}


function Install-DependencyModule {
    <#
    .SYNOPSIS
    Installs specified dependency PowerShell module.
    #>
    [CmdletBinding(PositionalBinding = $False,
                   SupportsShouldProcess = $True,
                   ConfirmImpact = 'High')]

    param (
        # Name of the required external module dependency.
        [Parameter(HelpMessage = "Enter name of the module to install.",
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String]
        $ModuleName,

        # Required version of the external module dependency.
        [Parameter(HelpMessage = "Enter version of the module to install.",
                   Position = 1,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [SemanticVersion]
        $ModuleVersion)

    begin {
        LeetABit.Build.Common\Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        if (Get-Module -FullyQualifiedName @{ ModuleName=$ModuleName; ModuleVersion=$ModuleVersion }) {
            return
        }

        $moduleToUnload = Get-Module -Name $ModuleName
        $availableModules = Get-Module -FullyQualifiedName @{ ModuleName=$ModuleName; ModuleVersion=$ModuleVersion } -ListAvailable
        if (-not $availableModules) {
            if (-not (Find-Module -Name $ModuleName -RequiredVersion $ModuleVersion -AllowPrerelease)) {
                throw ("$LocalizedData.Install_DependencyModule_ModuleNotFound_ModuleName_ModuleVersion" -f ($ModuleName, $ModuleVersion))
            }

            if ($PSCmdlet.ShouldProcess("$LocalizedData.Install_DependencyModule_ShouldProcessPreferenceVariableResource",
                                        "$LocalizedData.Install_DependencyModule_ShouldProcessPreferenceVariableOperation")) {
                $backupProgressPreference = $global:ProgressPreference
                $global:ProgressPreference = 'SilentlyContinue'
            }

            try {
                $resource = "$LocalizedData.Install_DependencyModule_ShouldProcessModuleResource_ModuleName_ModuleVersion" -f ($ModuleName, $ModuleVersion)
                if ($PSCmdlet.ShouldProcess($resource,
                                            "$LocalizedData.Install_DependencyModule_ShouldProcessModuleInstallationOperation")) {
                    $message = "$LocalizedData.Install_DependencyModule_InstallModule_ModificationMessage_ModuleName_ModuleVersion" -f ($ModuleName, $ModuleVersion)
                    Write-Modification -Message $message
                    Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Scope CurrentUser -AllowPrerelease -Force -Confirm:$False
                }
            } finally {
                if ($backupProgressPreference) {
                    $global:ProgressPreference = $backupProgressPreference
                }
            }
        }

        if ($moduleToUnload) {
            $resource = "LocalizedData.Install_DependencyModule_ShouldProcessModuleResource_ModuleName_ModuleVersion -f ($moduleToUnload.ModuleName, $moduleToUnload.Version)"
            if ($PSCmdlet.ShouldProcess($resource,
                                        "$LocalizedData.Install_DependencyModule_ShouldProcessModuleInstallationOperation")) {
                $message = "$LocalizedData.Install_DependencyModule_RemoveModule_ModificationMessage_ModuleName -f $ModuleName"
                Write-Modification -Message $message
                Remove-Module $moduleToUnload -Confirm:$False -Force
            }
        }

        Import-Module -FullyQualifiedName @{ ModuleName=$ModuleName; ModuleVersion=$ModuleVersion }
    }
}


Export-ModuleMember -Function '*' -Variable '*' -Alias '*' -Cmdlet '*'
