# Find-ModulePath

Finds paths to all PowerShell module directories in the specified path.

```Find-ModulePath [-Path] <String[]>```

```Find-ModulePath [-LiteralPath] <String[]>```

## Description

The Find-ModulePath cmdlet searches for a PowerShell modules in the specified location and returns a path to each module's directory found.

## Examples

### Example 1:

```PS > Find-ModulePath -Path "C:\Modules"```

Returns paths to all PowerShell module directories located in the specified location.

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
