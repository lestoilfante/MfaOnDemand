function Invoke-AuthPointMfa {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $true)]
        [string] $User,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Push","OTP")]
        [string] $Mode,
        [Parameter(Mandatory = $false)]
        [string] $OTP
    )

    try {
        $uri = $Providers.AuthPoint.MfaEndpoint.Replace("_region_", $script:ModuleSessionData.AuthPointSessions[$TenantId].ProviderData.Region).Replace("_accountId_", $script:ModuleSessionData.AuthPointSessions[$TenantId].ProviderData.AccountId).Replace("_resourceId_", $script:ModuleSessionData.AuthPointSessions[$TenantId].ProviderData.ResourceId)
        $headers = @{
            "Authorization" = "Bearer " + $script:ModuleSessionData.AuthPointSessions[$TenantId].Token
            "WatchGuard-API-Key" = $script:ModuleSessionData.AuthPointSessions[$TenantId].ProviderData.ApiKey
        }
        $result = [PSCustomObject]@{
            Result = "KO"
        }

        if ($Mode -eq "Push") {
            $uri += "/transactions"
            $body = @{
                login = $User
                type = "PUSH"
                clientInfoRequest = @{
                    machineName = $MyInvocation.MyCommand.Module.Name
                }
            } | ConvertTo-Json
        }
        elseif ($Mode -eq "OTP") {
            $uri += "/otp"
            $body = @{
                login = $User
                otp = $OTP
            } | ConvertTo-Json
        }

        $response = Invoke-ApiRequest -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json' -TimeoutSec 10
        if (-not $response.IsJson) {
            throw $response.Body
        }
        if ($Mode -eq "Push") {
            if (-not $response.Body.transactionId) {
                throw "Unexpected reply message '$($response.Body)'"
            }
            $uri += "/" + $response.Body.transactionId
            $waitUntil = (Get-Date).AddSeconds(60)
            $pending = $true
            while ($pending) {
                try {
                    Start-Sleep -Seconds 5
                    if ((Get-Date) -gt $waitUntil) {
                        throw "Timeout"
                    }
                    $mfaTransaction = Invoke-ApiRequest -Uri $uri -Method Get -Headers $headers -ContentType 'application/json' -TimeoutSec 10
                    switch ($mfaTransaction.StatusCode) {
                        200 {
                            if ($mfaTransaction.IsJson -and (($mfaTransaction.Body.authenticationResult -and $mfaTransaction.Body.authenticationResult -eq "AUTHORIZED") -or ($mfaTransaction.Body.pushResult -and $mfaTransaction.Body.pushResult -eq "AUTHORIZED"))) {
                                $result.Result = "OK"
                            }
                            else {
                                throw "Unexpected reply message '$($mfaTransaction.Body)'"
                            }
                            $pending = $false
                        }
                        202 {
                            #Still pending
                        }
                        default {
                            if ($mfaTransaction.IsJson -and $mfaTransaction.Body.title -and $mfaTransaction.Body.detail) {
                                Write-Warning "MFA failed - '$($mfaTransaction.Body.title) ($($mfaTransaction.Body.detail))'"
                            }
                            else {
                                throw "Unexpected reply message '$($mfaTransaction.Body)'"
                            }
                            $pending = $false
                        }
                    }
                }
                catch {
                    if ($_.Exception.Message -eq "Timeout") {
                        Write-Warning "MFA failed - Timeout"
                        $pending = $false
                    }
                    throw $_.Exception.Message
                }
            }
        }
        elseif ($Mode -eq "OTP") {
            if ($response.StatusCode -eq 200) {
                if ($response.Body.authenticationResult -and $response.Body.authenticationResult -eq "AUTHORIZED") {
                    $result.Result = "OK"
                }
                else {
                    throw "Unexpected reply message '$($response.Body)'"
                }
            }
            else {
                if ($response.Body.title -and $response.Body.detail) {
                    Write-Warning "MFA failed - '$($response.Body.title) ($($response.Body.detail))'"
                }
                else {
                    throw "Unexpected reply message '$($response.Body)'"
                }
            }
        }
        return $result
    }
    catch {
        throw "Error processing MFA request - $_"
    }
}

