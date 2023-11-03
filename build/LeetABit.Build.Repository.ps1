if (LeetABit.Build.Arguments\Find-CommandArgument "UnloadModules" -IsSwitch) {
    if (Get-Module 'LeetABit.Build.PowerShell') {
        Remove-Module 'LeetABit.Build.PowerShell' -ErrorAction SilentlyContinue
    }
}

Import-Module (Join-Path $PSScriptRoot ..\src\LeetABit.Build.PowerShell)
