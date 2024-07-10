$public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction Stop)
$private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction Stop)

foreach ($import in @(($public + $private))) {
    try {
        . $import.FullName
    } catch {
        throw "Failed to import functions from [$($import.FullName)]"
    }
}
Export-ModuleMember -Function $public.Basename -Alias '*'

$Providers = @{
    EntraId         = @{
        MfaAppId            = '981f26a1-7f43-403b-a875-f8b09b8cd720'
        TokenEndpoint       = 'https://login.microsoftonline.com/_tenantId_/oauth2/v2.0/token'
        MfaEndpoint         = 'https://strongauthenticationservice.auth.microsoft.com/StrongAuthenticationService.svc/Connector/BeginTwoWayAuthentication'
        PasswordExpiration  = 1
        CertificateExpiration = 365
    }
}
New-Variable -Name Providers -Value $Providers -Scope Script -Force

if (-not $script:ModuleSessionData) {
    $moduleData = @{
        EntraIdSessions = @{}
    }
    $script:ModuleSessionData = $moduleData
}

