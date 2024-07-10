function Invoke-MoDMfa {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("EntraId")]
        [string] $Provider = "EntraId",
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $false, ValueFromPipeline=$true)]
        [PSObject] $Credential,
        [Parameter(Mandatory = $true)]
        [string] $User,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Push","OTP")]
        [string] $Mode = "OTP"
    )
    Process {
        try {
            switch ($Provider) {
                "EntraId" {
                    $now = (Get-Date).ToUniversalTime()
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
                        $mfaOTP = Read-Host "Enter OTP"
                        if ($mfaOTP -notmatch "^[0-9]{2,8}$") {
                            Write-Warning "Invalid input"
                            Write-Error "Failure"
                            return
                        }
                        $challengeData = $mfaResult
                        Add-Member -InputObject $challengeData -NotePropertyName "OTP" -NotePropertyValue $mfaOTP
                        $mfaChallenge = Invoke-EntraMfa -TenantId $TenantId -User $User -Mode Challenge -Challenge $challengeData
                        if ($mfaChallenge.Result -eq "OK") {
                            Write-Output "Success"
                        }
                        elseif ($mfaChallenge.Result -eq "KO"){
                            Write-Error "Failure"
                        }
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