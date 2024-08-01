@{
    RootModule              = 'MfaOnDemand.psm1'
    ModuleVersion           = '0.10.0'
    GUID                    = '79e0551c-4c1e-4486-90fc-cedf93bd5e67'
    Author                  = 'lestoilfante'
    CompanyName             = 'lestoilfante'
    Copyright               = '(c) 2024 lestoilfante. All rights reserved.'
    Description             = @'
MfaOnDemand is a PowerShell module designed to send custom and arbitrary MFA requests to Entra ID users.
Useful for quickly confirming user identities for Service Desk usage or for any automation purposes.
'@
    CompatiblePSEditions    = @('Desktop')
    PowerShellVersion       = '5.1'
    FunctionsToExport       = @(
        'Invoke-MoDMfa'
        'Get-MoDCredentials'
        'Add-MoDCredentials'
    )
    CmdletsToExport         = @()
    VariablesToExport       = @()
    AliasesToExport         = @()
    RequiredModules         = @()
    RequiredAssemblies      = @()
    PrivateData             = @{
        PSData = @{
            ProjectUri                 = 'https://github.com/lestoilfante/MfaOnDemand'
            LicenseUri                 = 'https://github.com/lestoilfante/MfaOnDemand/blob/master/LICENSE.txt'
            Tags                       = @('MFA', 'Microsoft', 'Entra', 'AAD', 'Identity', 'WatchGuard')
        }
    }
    HelpInfoURI = 'https://github.com/lestoilfante/MfaOnDemand/blob/master/README.md'
}