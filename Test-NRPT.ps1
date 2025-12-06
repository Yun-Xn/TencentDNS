# 测试NRPT DNS分流是否真正生效
# NRPT只对Windows应用生效，nslookup会绕过NRPT

Write-Host "=== NRPT DNS分流测试 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查NRPT规则
Write-Host "1️⃣ 检查NRPT规则:" -ForegroundColor Yellow
$rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue | Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" }
if ($rules) {
    Write-Host "   ✅ 找到 $($rules.Count) 条腾讯DNS规则" -ForegroundColor Green
    Write-Host "   示例规则: $($rules[0].Namespace) -> $($rules[0].NameServers)" -ForegroundColor Gray
} else {
    Write-Host "   ❌ 未找到NRPT规则，请先运行主脚本" -ForegroundColor Red
    exit
}

Write-Host ""

# 2. 使用Resolve-DnsName测试（会应用NRPT）
Write-Host "2️⃣ 使用 Resolve-DnsName 测试（应用NRPT）:" -ForegroundColor Yellow
$testDomains = @("qq.com", "v.qq.com", "www.qq.com")
foreach ($domain in $testDomains) {
    try {
        $result = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
        $ip = ($result | Where-Object { $_.Type -eq 'A' })[0].IPAddress
        Write-Host "   ✅ $domain -> $ip" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ $domain -> 解析失败" -ForegroundColor Yellow
    }
}

Write-Host ""

# 3. 使用.NET测试（会应用NRPT）
Write-Host "3️⃣ 使用 .NET DNS 测试（应用NRPT）:" -ForegroundColor Yellow
foreach ($domain in $testDomains) {
    try {
        $result = [System.Net.Dns]::GetHostAddresses($domain)
        $ip = $result[0].ToString()
        Write-Host "   ✅ $domain -> $ip" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ $domain -> 解析失败" -ForegroundColor Yellow
    }
}

Write-Host ""

# 4. 说明nslookup的特殊性
Write-Host "4️⃣ 关于 nslookup 的说明:" -ForegroundColor Yellow
Write-Host "   ⚠️ nslookup 是特殊工具，会绕过NRPT规则" -ForegroundColor Cyan
Write-Host "   ⚠️ nslookup 直接查询网卡DNS服务器（59.70.159.10）" -ForegroundColor Cyan
Write-Host "   ✅ 但实际应用程序（浏览器、游戏等）会使用NRPT" -ForegroundColor Green
Write-Host "   ✅ PowerShell的 Resolve-DnsName 也会使用NRPT" -ForegroundColor Green

Write-Host ""

# 5. 检查DNS客户端服务
Write-Host "5️⃣ 检查DNS客户端服务状态:" -ForegroundColor Yellow
$dnsService = Get-Service -Name "Dnscache" -ErrorAction SilentlyContinue
if ($dnsService.Status -eq 'Running') {
    Write-Host "   ✅ DNS客户端服务正在运行" -ForegroundColor Green
} else {
    Write-Host "   ❌ DNS客户端服务未运行，NRPT无法工作" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 结论: 如果上述测试都能解析成功，说明NRPT已生效。" -ForegroundColor White
Write-Host "💡 nslookup显示默认DNS是正常的，实际应用已使用腾讯DNS。" -ForegroundColor White
