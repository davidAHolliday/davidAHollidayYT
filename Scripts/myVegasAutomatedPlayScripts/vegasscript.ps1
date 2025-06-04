$spinLogs = @()

# Load config JSON from the same folder
$configPath = Join-Path $PSScriptRoot "token.txt"
if (-not (Test-Path $configPath)) {
    Write-Host " Config file not found: $configPath"
    exit 1
}

$configJson = Get-Content $configPath -Raw | ConvertFrom-Json
$token = $configJson.token
$spinUrl = $configJson.spinUrl
$payload = $configJson.payload | ConvertTo-Json -Compress

for ($i = 1; $i -le 100; $i++) {

    Write-Host "`n--- Starting Cycle $i of 100 ---"

    # --- Define Headers ---
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "*/*")
    $headers.Add("Accept-Encoding", "gzip, deflate, br, zstd")
    $headers.Add("Accept-Language", "en-US,en;q=0.9")
    $headers.Add("Accept-Type", "application/json")
    $headers.Add("Authorization", "$token")
    $headers.Add("Content-Type", "application/json")
    $headers.Add("DNT", "1")
    $headers.Add("Host", "mvmx.playstudios.com")
    $headers.Add("Origin", "https://www.myvegas.com")
    $headers.Add("Referer", "https://www.myvegas.com/")
    $headers.Add("Sec-Fetch-Dest", "empty")
    $headers.Add("Sec-Fetch-Mode", "cors")
    $headers.Add("Sec-Fetch-Site", "cross-site")
    $headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36")
    $headers.Add("X-AVA-DAB", "3_63_0")
    $headers.Add("X-PSA-ID", "642920")
    $headers.Add("sec-ch-ua", "`"Chromium`";v=`"136`", `"Google Chrome`";v=`"136`", `"Not.A/Brand`";v=`"99`"")
    $headers.Add("sec-ch-ua-mobile", "?0")
    $headers.Add("sec-ch-ua-platform", "`"Windows`"")
    $headers.Add("traceparent", "00-8b8efe8a6db0ca6c72165e63e159f0a1-b08b52323657ce96-00")

    $bodyFreeCoins = '{}'

    $credit = 0

    # --- Ensure enough credit before spinning ---
    do {
        try {
            $response = Invoke-RestMethod 'https://mvmx.playstudios.com/api/triggeredaward/FreeCoins' `
                -Method 'POST' -Headers $headers -Body $bodyFreeCoins -ContentType 'application/json'
            $credit = $response.Common.Balances.Credits
            Write-Host "FreeCoins: Current Credit = $credit"

            if ($credit -lt 5000000) {
                Write-Host "Waiting for enough credits..."
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Host "FreeCoins error: $_.Exception.Message"
            Start-Sleep -Seconds 2
        }
    } while ($credit -lt 5000000)

    # --- Spin as long as credit ≥ 5M ---
    do {
        try {
	$creditBefore = $credit
            $spinResponse = Invoke-RestMethod -Uri $spinUrl -Method 'POST' -Headers $headers -Body $payload -ContentType 'application/json'

            $credit = $spinResponse.Common.Balances.Credits
            Write-Host "SPIN SUCCESS: New Credit = $credit"
$creditAfter = $spinResponse.Common.Balances.Credits
$creditsWon = $creditAfter - $creditBefore
$rtp = if ($creditsWon -eq 0) { 0 } else { [math]::Round($creditsWon / 5000000, 4) }

$spinLogs += [PSCustomObject]@{
    Timestamp      = (Get-Date).ToString("s")
    Cycle          = $i
    BeforeCredits  = $creditBefore
    AfterCredits   = $creditAfter
    CreditsWon     = $creditsWon
    RTP            = $rtp
}

            if ($credit -ge 5000000) {
                Write-Host "Spinning again..."
                Start-Sleep -Seconds 2
            } else {
                Write-Host "Credit dropped below 5M. Going back to FreeCoins."
            }

        } catch {
            Write-Host "Spin Error: $_.Exception.Message"
$csvPath = Join-Path $PSScriptRoot "spin-log.csv"
$spinLogs | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "✅ Log saved to $csvPath"
	    exit 1


        }
    } while ($credit -ge 5000000)
}
$csvPath = Join-Path $PSScriptRoot "spin-log.csv"
$spinLogs | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "✅ Log saved to $csvPath"

