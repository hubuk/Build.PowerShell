#!/usr/bin/env pwsh
#requires -version 6

using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation

<#
.SYNOPSIS
Defines tests for run.ps1 script.
#>
[CmdletBinding()]

param (
    # The path to the project's repository root directory. If not specified the current script root directory will be used.
    [Parameter(Position = 1,
               Mandatory = $True,
               ValueFromPipeline = $False,
               ValueFromPipelineByPropertyName = $True)]
    [String]
    $ArtifactsRoot,
    [Parameter(Position = 2,
               Mandatory = $True,
               ValueFromPipeline = $False,
               ValueFromPipelineByPropertyName = $True)]
    [String]
    $TestRoot)

Set-StrictMode -Version 3.0

$relativePath = Resolve-RelativePath (Split-Path $PSCommandPath) $TestRoot
$artifactPath = Join-Path $ArtifactsRoot $relativePath
#Import-Module "$artifactPath"

#$testBase = [System.IO.Path]::GetFullPath($TestRoot)
#$offset = 1
#if ($testBase[$testBase.Length - 1] -eq [System.IO.Path]::DirectorySeparatorChar) {
#    $offset = 0
#}
#
#$testPath = Split-Path -Parent $MyInvocation.MyCommand.Path
#$relativePath = $testPath.Substring($testBase.Length + $offset)
#$testName = Split-Path -Leaf $MyInvocation.MyCommand.Path
#$scriptName = $testName -replace '\.Tests\.', '.'
#$scriptPath = Join-Path $ArtifactsRoot $relativePath
#$scriptFullName = Join-Path $scriptPath $scriptName
#
#. "$scriptFullName"

Describe "LeetABit.Build.PowerShell" {
    It "Should register resolver on initialization." {
        $extension = LeetABit.Build.Extensibility\Get-BuildExtension -Name LeetABit.Build.PowerShell
        $extension | Should -Not -BeNullOrEmpty
    }
}
