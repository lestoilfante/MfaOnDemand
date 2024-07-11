# MfaOnDemand

## Description

MfaOnDemand is a PowerShell module designed to send custom and arbitrary MFA requests to Entra ID users.  
Useful for quickly confirming user identities for Service Desk usage or for any automation purposes.

## Features

* Supports both OTP or Push verification modes
* Integration-ready, quick and straightforward inclusion into existing scripts and workflows
* Utilizes Client Credentials in the form of a Certificate or Secret Key
* Includes helper functions to add, list, and delete Client Credentials
* No need for additional App Registration

## Installation

```powershell
# From local path
Import-Module .\MfaOnDemand.psd1

# From PowerShell Gallery
Install-Module -Name MfaOnDemand
#
```

## Quick Start

In order to trigger *Entra ID* native MFA you'll first need to register a *secret* within your *Tenant*:
```powershell
$secret = Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Password
```
This *secret* will then be used for subsequent MfaOnDemand requests:
```powershell
Invoke-MoDMfa -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Credential ($secret | ConvertTo-SecureString -AsPlainText -Force) -User user@something.onmicrosoft.com -Mode Push
```

## Usage

First, you must have some type of credential registered on *Entra ID* MFA App. MfaOnDemand provides the helper function `Add-MoDCredentials` for convenience:
```powershell
# Register a new Password credential, valid for 1 day, and output as plain text
Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Password
<#
Register a new X509 Certificate credential, valid for 1 year, and output its Thumbprint,
The certificate is stored on CurrentUser Certificates Store
#>
Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Certificate -MyCertificate New

# Alternatively you can also register an existing X509 certificate
[X509Certificate]$cert | Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Certificate
# or
Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Certificate -MyCertificate <X509Certificate.Thumbprint>
```

The actual MFA request is sent by `Invoke-MoDMfa`. At least on the first iteration, a `-Credential` parameter is required to authenticate MfaOnDemand against the MFA Provider. Subsequent calls to `Invoke-MoDMfa` 
can omit it as long as original session is valid.
```powershell
# Send MFA OTP request, -Credential is a Thumbprint string from an X509Certificate stored in the CurrentUser Certificates Store (Cert:\CurrentUser\My)
Invoke-MoDMfa -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Credential <X509Certificate.Thumbprint> -User user@something.onmicrosoft.com -Mode OTP

# Send MFA OTP request reading -Credential input from Pipeline
[X509Certificate]$cert | Invoke-MoDMfa -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -User user@something.onmicrosoft.com -Mode OTP

# Using Pipeline is also possible to register any supported credential type and feed it to Invoke-MoDMfa
Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Certificate -MyCertificate New | Invoke-MoDMfa -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -User user@something.onmicrosoft.com -Mode OTP
# or
Add-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Type Password | ConvertTo-SecureString -AsPlainText -Force | Invoke-MoDMfa -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -User user@something.onmicrosoft.com -Mode OTP
```

Retrieving all registered credentials is straightforward with `Get-MoDCredentials`:
```powershell
# Output both Passwords and Certificates
Get-MoDCredentials -Provider EntraId -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```
Using `Get-MoDCredentials` will also display *suggested* commands to remove credentials by *KeyId*:
```powershell
#----- USE WITH CAUTION -----
#** Command for password removal
    Connect-MgGraph -NoWelcome -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Scopes 'Application.ReadWrite.All'; Remove-MgServicePrincipalPassword -ServicePrincipalId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -KeyId <KeyId>

#** Command for certificate removal
    Connect-MgGraph -NoWelcome -TenantId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -Scopes 'Application.ReadWrite.All'; $keyCreds=(Get-MgServicePrincipal -ServicePrincipalId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx').KeyCredentials; Update-MgServicePrincipal -ServicePrincipalId xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -KeyCredentials ($keyCreds|Where-Object { $_.KeyId -ne '<KeyId>' }) -Confirm
```

## Notes

* `Invoke-MoDMfa -Credential <password>` requires an input of type **SecureString**, mind that the output of `Add-MoDCredentials -Type Password` is in plain text  
* The use of `Password` credentials is considered less secure than `Certificate`. Therefore, credentials generated by `Add-MoDCredentials -Type Password` will have a lifespan of **1 day** while those generated by `Add-MoDCredentials -Type Certificate` will have a lifespan of **1 year**
* The proper cleanup of registered credentials, regardless of their active or expired state, is your responsibility. **MfaOnDemand will not clean up any credentials** but you might use `Get-MoDCredentials` to monitor them.
* Microsoft Authenticator's *Number Matching* feature is NOT supported

## Disclaimer

**MfaOnDemand** leverages undocumented *Entra ID* MFA APIs! Use at your own risk!  
The current functionality is the result of piecing together information from official Microsoft documentation regarding NPS extension/MFA Server/AD FS and similar solutions like these:  
https://www.cyberdrain.com/automating-with-powershell-sending-mfa-push-messages-to-users/  
https://lolware.net/blog/using-azure-mfa-onprem-ad/  
https://www.entraneer.com/blog/entra/authentication/transactional-mfa-entra-id

## Dependencies

`Invoke-MoDMfa` does not have any dependencies.
`Add-MoDCredentials` and `Get-MoDCredentials` require **Microsoft.Graph** module and `Application.ReadWrite.All` permissions on Entra ID Tenant.

## License & Copyright

[Copyright 2024 lestoilfante](https://github.com/lestoilfante)

GNU General Public License version 3 (GPLv3)

