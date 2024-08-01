function Invoke-ApiRequest {
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        [Parameter(Mandatory = $true)]
        [string] $Method,
        [Parameter(Mandatory = $false)]
        [PSObject] $Headers,
        [Parameter(Mandatory = $false)]
        [string] $ContentType = 'application/json',
        [Parameter(Mandatory = $false)]
        [PSObject] $Body,
        [Parameter(Mandatory = $false)]
        [int] $TimeoutSec = 10
    )
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $request = try { Invoke-WebRequest -UseBasicParsing -Uri $Uri -Method $Method -Headers $Headers -ContentType $ContentType -TimeoutSec $TimeoutSec -Body $Body} catch { $_.Exception.Response }
    }
    else {
        $request = Invoke-WebRequest -UseBasicParsing -Uri $Uri -Method $Method -Headers $Headers -ContentType $ContentType -TimeoutSec $TimeoutSec -Body $Body -SkipHttpErrorCheck
    }
    $r = @{
        Body = $null
        StatusCode = 0
        IsJson = $false
    }
    if ($request -is [System.Net.HttpWebResponse]) {
        $sr = New-Object System.IO.StreamReader($request.GetResponseStream())
        $sr.BaseStream.Position = 0
        $sr.DiscardBufferedData()
        $r.Body = $sr.ReadToEnd()
        $r.StatusCode = [int][System.Net.HttpStatusCode]::($request.StatusCode)
        $sr.Close()
    }
    else {
        $r.Body = $request
        $r.StatusCode = $request.StatusCode
    }
    try {
        $jsonObject = $r.Body | ConvertFrom-Json
        $r.Body = $jsonObject
        $r.IsJson = $true
    }
    catch {
        Write-Debug "Failed Json conversion"
    }
    return $r
}
