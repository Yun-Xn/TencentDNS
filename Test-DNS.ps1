# Test NRPT DNS Rules
$ConfirmPreference = 'None'

Write-Host "`n=== Cleanup existing rules ===" -ForegroundColor Cyan
Get-DnsClientNrptRule | Remove-DnsClientNrptRule -Force
Write-Host "Cleaned all NRPT rules"

Write-Host "`n=== Creating Tencent DNS rules ===" -ForegroundColor Cyan
$dnsServers = @("119.29.29.29", "182.254.116.116")
$domains = @("qq.com", "*.qq.com", "tencent.com", "v.qq.com")

foreach ($domain in $domains) {
    try {
        Add-DnsClientNrptRule -Namespace $domain -NameServers $dnsServers -Comment "Test Rule" -ErrorAction Stop | Out-Null
        Write-Host "Created: $domain" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: $domain - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Verify rules ===" -ForegroundColor Cyan
Get-DnsClientNrptRule | Format-Table Namespace, @{N='NameServers';E={$_.NameServers -join ', '}}, Enabled -AutoSize

Write-Host "`n=== Test DNS resolution ===" -ForegroundColor Cyan
Clear-DnsClientCache
Write-Host "DNS cache cleared"

Write-Host "`nResolving qq.com:" -ForegroundColor Yellow
$result = Resolve-DnsName qq.com -Type A | Select-Object -First 1
Write-Host "  IP: $($result.IPAddress)" -ForegroundColor White

Write-Host "`nDirect query to Tencent DNS:" -ForegroundColor Yellow
$directResult = Resolve-DnsName qq.com -Server 119.29.29.29 -Type A | Select-Object -First 1
Write-Host "  IP: $($directResult.IPAddress)" -ForegroundColor White

if ($result.IPAddress -eq $directResult.IPAddress) {
    Write-Host "`nNRPT rules are working! Using Tencent DNS" -ForegroundColor Green
} else {
    Write-Host "`nIP mismatch, NRPT may not be working" -ForegroundColor Yellow
}

Write-Host "`n=== Cleanup test rules ===" -ForegroundColor Cyan
Get-DnsClientNrptRule | Where-Object { $_.Comment -eq "Test Rule" } | Remove-DnsClientNrptRule -Force
Write-Host "Test complete, cleaned up" -ForegroundColor Green
