function Invoke-MoDMfa {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("EntraId", "AuthPoint")]
        [string] $Provider = "EntraId",
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $false, ValueFromPipeline=$true)]
        [PSObject] $Credential,
        [Parameter(Mandatory = $true)]
        [string] $User,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Push","OTP")]
        [string] $Mode = "OTP",
        [Parameter(Mandatory = $false)]
        [string] $Otp,
        [Parameter(Mandatory = $false)]
        [PSObject] $ProviderArgs
    )
    Process {
        try {
            $now = (Get-Date).ToUniversalTime()
            switch ($Provider) {
                "EntraId" {
                    if (-not $script:ModuleSessionData.EntraIdSessions[$TenantId] -or $script:ModuleSessionData.EntraIdSessions[$TenantId].ExpiresAt -lt $now) {
                        if (-not $Credential) {
                            Write-Warning "No active session found, use -Credential [?|X509Certificate|X509Certificate.Thumbprint|SecureString]"
                            return
                        }
                        $auth = Get-EntraMfaAuthToken -TenantId $TenantId -Credential $Credential
                        $script:ModuleSessionData.EntraIdSessions[$TenantId] = @{
                            Token     = $auth.access_token
                            ExpiresAt = $now.AddSeconds($auth.expires_in)
                        }
                    }
                    if ($Mode -eq "OTP") {
                        $mfaResult = Invoke-EntraMfa -TenantId $TenantId -User $User -Mode OTP
                    }
                    else {
                        $mfaResult = Invoke-EntraMfa -TenantId $TenantId -User $User -Mode Push
                    }
                    if ($mfaResult.Result -eq "OK") {
                        Write-Output "Success"
                    }
                    elseif ($mfaResult.Result -eq "KO"){
                        Write-Error "Failure"
                    }
                    elseif ($mfaResult.Result -eq "CHALLENGE") {
                        $Otp = Test-Otp -Otp $Otp
                        $challengeData = $mfaResult
                        Add-Member -InputObject $challengeData -NotePropertyName "OTP" -NotePropertyValue $Otp
                        $mfaChallenge = Invoke-EntraMfa -TenantId $TenantId -User $User -Mode Challenge -Challenge $challengeData
                        if ($mfaChallenge.Result -eq "OK") {
                            Write-Output "Success"
                        }
                        elseif ($mfaChallenge.Result -eq "KO"){
                            Write-Error "Failure"
                        }
                    }
                }
                "AuthPoint" {
                    if (-not $script:ModuleSessionData.AuthPointSessions[$TenantId] -or $script:ModuleSessionData.AuthPointSessions[$TenantId].ExpiresAt -lt $now) {
                        if (-not $Credential) {
                            Write-Warning "No active session found, use the -Credential parameter with a PSCredential object where user is <AuthPoint_rw_access_ID> and password is <AuthPoint_rw_password>."
                            return
                        }
                        $accountId, $resourceId = $TenantId -split ":"
                        if (-not $accountId -or -not $resourceId) {
                            Write-Warning "TenantId format must be <AccountId>:<ResourceId>"
                            return
                        }
                        if (-not $ProviderArgs -or -not $ProviderArgs.Region -or -not $ProviderArgs.ApiKey) {
                            Write-Warning "One or more required properties (Region, ApiKey) on the ProviderArgs object are missing or empty."
                            return
                        }
                        if ($ProviderArgs.Region.Length -ne 3) {
                            Write-Warning "Region format must be xxx where xxx is among AuthPoint region (deu, usa, ...)"
                            return
                        }
                        $auth = Get-AuthPointMfaAuthToken -Credential $Credential -Region $ProviderArgs.Region
                        $script:ModuleSessionData.AuthPointSessions[$TenantId] = @{
                            Token     = $auth.access_token
                            ExpiresAt = $now.AddSeconds($auth.expires_in)
                            ProviderData = @{
                                Region = $ProviderArgs.Region
                                ApiKey = $ProviderArgs.ApiKey
                                AccountId = $accountId
                                ResourceId = $resourceId
                            }
                        }
                    }
                    if ($Mode -eq "OTP") {
                        $Otp = Test-Otp -Otp $Otp
                        $mfaResult = Invoke-AuthPointMfa -TenantId $TenantId -User $User -Mode OTP -OTP $Otp
                    }
                    else {
                        $mfaResult = Invoke-AuthPointMfa -TenantId $TenantId -User $User -Mode Push
                    }
                    if ($mfaResult.Result -eq "OK") {
                        Write-Output "Success"
                    }
                    elseif ($mfaResult.Result -eq "KO"){
                        Write-Error "Failure"
                    }
                }
            }
            return
        }
        catch {
            Write-Error $_.Exception.Message
            return
        }
    }
}