function Get-EntraMfaCredentials {
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId
    )
    $moduleName = "Microsoft.Graph"
    $g = Get-Module -ListAvailable -Name $moduleName
    if ($null -eq $g) {
        throw "Module '$moduleName' is not available."
    }
    try {
        $appId = $Providers.EntraId.MfaAppId
        Connect-MgGraph -NoWelcome -TenantId $TenantId -Scopes 'Application.ReadWrite.All'
        $mfaSvcPrincipal = Get-MgServicePrincipal -Filter "appid eq '$appId'"
        $out = @{
            Passwords = @{}
            Certificates = @{}
            ServicePrincipalId = $null
        }
        $out.ServicePrincipalId = $mfaSvcPrincipal.Id
        $out.Passwords = $mfaSvcPrincipal.PasswordCredentials
        $out.Certificates = $mfaSvcPrincipal.KeyCredentials
        Disconnect-MgGraph
        return $out
    }
    catch {
        throw "Error getting ServicePrincipal credentials - $_"
    }
}

