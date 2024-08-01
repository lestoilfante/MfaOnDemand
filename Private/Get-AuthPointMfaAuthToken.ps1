function Get-AuthPointMfaAuthToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,
        [Parameter(Mandatory = $true)]
        [string] $Region
    )

    try {
        if ($Credential -is [PSCredential]) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Credential.UserName + ":" + [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)))
            $clientSecret = [System.Convert]::ToBase64String($bytes)
            $headers = @{
                Authorization = "Basic " + $clientSecret
            }
            $body = @{
                scope         = "api-access"
                grant_type    = "client_credentials"
            }
        }
        else {
            throw "Invalid -Credential type, [PSCredential] required"
        }
        $tokenEndpoint = $Providers.AuthPoint.TokenEndpoint.Replace('_region_',$Region)
        $response = Invoke-ApiRequest -Uri $tokenEndpoint -Method Post -Headers $headers -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 10
        if (-not $response.Body.access_token) {
            throw "Got '$($response.Body)'"
        }
        $response.Body
    }
    catch {
        throw "Failed to get access token - $_"
    }
}
