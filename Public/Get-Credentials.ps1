function Get-Credentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("EntraId")]
        [string] $Provider,
        [Parameter(Mandatory = $true)]
        [string] $TenantId
    )

    try {
        switch ($Provider) {
            "EntraId" {
                $creds = Get-EntraMfaCredentials -TenantId $TenantId
                $svcId = $creds.ServicePrincipalId
                Write-Output "** $Provider Passwords:"
                $creds.Passwords | Select-Object DisplayName,EndDateTime,KeyId,StartDateTime | Format-Table | Out-String | Write-Output
                Write-Output "** $Provider Certificates:"
                $creds.Certificates | Select-Object DisplayName,EndDateTime,KeyId,StartDateTime | Format-Table | Out-String | Write-Output
                $help = @"
----- USE WITH CAUTION -----
** Command for password removal
    Connect-MgGraph -NoWelcome -TenantId $TenantId -Scopes 'Application.ReadWrite.All'; Remove-MgServicePrincipalPassword -ServicePrincipalId $svcId -KeyId <KeyId>

** Command for certificate removal
    Connect-MgGraph -NoWelcome -TenantId $TenantId -Scopes 'Application.ReadWrite.All'; `$keyCreds=(Get-MgServicePrincipal -ServicePrincipalId '$svcId').KeyCredentials; Update-MgServicePrincipal -ServicePrincipalId $svcId -KeyCredentials (`$keyCreds|Where-Object { `$_.KeyId -ne '<KeyId>' }) -Confirm
"@
                Write-Output $help
            }
        }
    }
    catch {
        Write-Error $_.Exception.Message
        return
    }
}
