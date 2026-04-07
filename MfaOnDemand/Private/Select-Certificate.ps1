function Select-Certificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $CertificateThumbprint
    )
    try {
        $certs = Get-ChildItem -Path Cert:\CurrentUser\My
        if ($CertificateThumbprint) {
            if ($CertificateThumbprint -match "^[0-9a-fA-F]{5,}$") {
                $certsLookup = $certs | Where-Object {$_.Thumbprint -match "^$CertificateThumbprint"}
                if ($certsLookup.Count -eq 0) {
                    Write-Warning "Unable to locate a certificate with the specified thumbprint"
                    return $null
                }
                if ($certsLookup.Count -gt 1) {
                    Write-Warning "Multiple certificates with the specified thumbprint found"
                    return $null
                }
                $selectedCert = $certsLookup[0]
            }
            elseif ($CertificateThumbprint -eq "?") {
                $i = 1
                $certs | ForEach-Object {
                    [PSCustomObject]@{
                        Id           = $i++
                        Thumbprint   = ($_.Thumbprint).Substring(0,10)
                        Subject      = $_.Subject
                        FriendlyName = $_.FriendlyName
                    }
                } | Format-Table | Out-String | Write-Host

                if ($certs.Count -eq 0) {
                    Write-Warning "No certificate found on CurrentUser Store"
                    return $null
                }

                $selection = Read-Host "Enter the Id of the certificate you want to use"
                if ($selection -notmatch "^\d{1,}$" -or [int]$selection -le 0 -or [int]$selection -gt $certs.Count) {
                    Write-Warning "Invalid selection"
                    return $null
                }

                $selectedCert = $certs | Select-Object -Index ([int]$selection - 1)
            }
            else {
                Write-Warning "Invalid selection"
            }
        }
        return $selectedCert
    }
    catch {
        throw "Error processing CurrentUser Certificates - $_"
    }
}