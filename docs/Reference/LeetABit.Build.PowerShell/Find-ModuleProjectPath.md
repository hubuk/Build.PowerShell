# Find-ModuleProjectPath

Finds paths to all PowerShell module project directories in the specified path.

```Find-ModuleProjectPath [-Path] <String[]>```

```Find-ModuleProjectPath [-LiteralPath] <String[]>```

## Description

The Find-ModuleProjectPath cmdlet searches for a PowerShell module project in the specified location and returns a path to each project directory found.

## Examples

### Example 1:

```PS > Find-ModuleProjectPath -Path "C:\Modules"```

Returns paths to all PowerShell module projects located in the specified directory.

## Parameters

### ```-Path```

*Path to the search directory.*

<table>
  <tr><td>Type:</td><td>String[]</td></tr>
  <tr><td>Required:</td><td>true</td></tr>
  <tr><td>Position:</td><td>1</td></tr>
  <tr><td>Default value:</td><td></td></tr>
  <tr><td>Accept pipeline input:</td><td>true (ByValue, ByPropertyName)</td></tr>
  <tr><td>Accept wildcard characters:</td><td>false</td></tr>
</table>

### ```-LiteralPath```

*Path to the search directory.*

<table>
  <tr><td>Type:</td><td>String[]</td></tr>
  <tr><td>Required:</td><td>true</td></tr>
  <tr><td>Position:</td><td>1</td></tr>
  <tr><td>Default value:</td><td></td></tr>
  <tr><td>Accept pipeline input:</td><td>true (ByValue, ByPropertyName)</td></tr>
  <tr><td>Accept wildcard characters:</td><td>false</td></tr>
</table>

## Input

None

## Output

```[System.String]```
