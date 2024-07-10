function Invoke-EntraMfa {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $true)]
        [string] $User,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Push","OTP","Challenge")]
        [string] $Mode,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Challenge
    )

    try {
        $headers = @{ "Authorization" = "Bearer $($script:ModuleSessionData.EntraIdSessions[$TenantId].Token)" }

        $result = [PSCustomObject]@{
            Result = "KO"
            ChallengeId = $null
            ChallengeUri = $null
        }

        if ($Mode -eq "Push" -or $Mode -eq "OTP") {
            $xml = '<BeginTwoWayAuthenticationRequest><Version>1.0</Version><UserPrincipalName>__UPN__</UserPrincipalName><Lcid>en-us</Lcid><AuthenticationMethodProperties xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays"><a:KeyValueOfstringstring><a:Key>OverrideVoiceOtp</a:Key><a:Value>false</a:Value></a:KeyValueOfstringstring><a:KeyValueOfstringstring><a:Key>OverrideNumberMatchingWithOTP</a:Key><a:Value>__USE_OTP__</a:Value></a:KeyValueOfstringstring></AuthenticationMethodProperties><ContextId>__GUID__</ContextId><SyncCall>true</SyncCall><RequireUserMatch>true</RequireUserMatch><CallerName>radius</CallerName><CallerIP>UNKNOWN:</CallerIP></BeginTwoWayAuthenticationRequest>'

            if ($Mode -eq "Push") {
                $body = $xml.Replace("__UPN__", $User).Replace("__USE_OTP__", "false").Replace("__GUID__", (New-Guid).Guid)
            }
            elseif ($Mode -eq "OTP") {
                $body = $xml.Replace("__UPN__", $User).Replace("__USE_OTP__", "true").Replace("__GUID__", (New-Guid).Guid)
            }

            $response = Invoke-RestMethod -Uri $Providers.EntraId.MfaEndpoint -Method POST -Headers $headers -Body $body -ContentType 'application/xml' -TimeoutSec 60

            if (-not $response.BeginTwoWayAuthenticationResponse) {
                throw "Unexpected reply message"
            }
            switch ($response.BeginTwoWayAuthenticationResponse.AuthenticationResult) {
                "false" {
                    $e = $response.BeginTwoWayAuthenticationResponse.Result.Value
                    Write-Warning "MFA failed - '$e'"
                }
                "true" {
                    $result.Result = "OK"
                }
                "challenge" {
                    $result.Result = "CHALLENGE"
                    $result.ChallengeId = $response.BeginTwoWayAuthenticationResponse.SessionId
                    $result.ChallengeUri = $response.BeginTwoWayAuthenticationResponse.AffinityUrl
                }
                default {
                    Write-Warning "MFA failed - Unexpected response"
                }
            }
        }
        elseif ($Mode -eq "Challenge") {
            if (-not $Challenge) {
                throw "Missing challenge data"
            }
            $xml = '<EndTwoWayAuthenticationRequest><Version>1.0</Version><SessionId>__CHALLENGE_ID__</SessionId><ContextId>__GUID__</ContextId><AdditionalAuthData>__OTP__</AdditionalAuthData><UserPrincipalName>__UPN__</UserPrincipalName></EndTwoWayAuthenticationRequest>'
            $body = $xml.Replace("__UPN__", $User).Replace("__OTP__", $Challenge.OTP).Replace("__GUID__", (New-Guid).Guid).Replace("__CHALLENGE_ID__", $Challenge.ChallengeId)
            $response = Invoke-RestMethod -Uri $Challenge.ChallengeUri -Method POST -Headers $headers -Body $body -ContentType 'application/xml' -TimeoutSec 60
            if (-not $response.EndTwoWayAuthenticationResponse) {
                throw "Unexpected challenge reply message"
            }
            switch ($response.EndTwoWayAuthenticationResponse.AuthenticationResult) {
                "false" {
                    $e = $response.EndTwoWayAuthenticationResponse.Result.Value
                    Write-Warning "MFA failed - '$e'"
                }
                "true" {
                    $result.Result = "OK"
                }
                default {
                    Write-Warning "MFA failed - Unexpected challenge response"
                }
            }
        }
        return $result
    }
    catch {
        throw "Error processing MFA request - $_"
    }
}

