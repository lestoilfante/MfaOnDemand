function Test-Otp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $Otp
    )
    if (-not $Otp) {
        $Otp = Read-Host "Enter OTP"
    }
    if ($Otp -notmatch "^[0-9]{2,8}$") {
        throw "Invalid OTP format"
    }
    $Otp
}
