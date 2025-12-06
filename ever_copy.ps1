<#
.SYNOPSIS
Tencent DNS Permanent Configuration - Rules persist after system reboot
.DESCRIPTION
One-time configuration of Windows NRPT rules for Tencent domains
No monitoring service needed, rules automatically persist after reboot
.REQUIREMENTS
1. Run PowerShell as Administrator
2. Windows 10/11/Server 2016+ (NRPT native support)
.USAGE
Install: .\TencentDNS_ever.ps1 -Action Install
Uninstall: .\TencentDNS_ever.ps1 -Action Uninstall
Show: .\TencentDNS_ever.ps1 -Action Show
Test: .\TencentDNS_ever.ps1 -Action Test
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Install", "Uninstall", "Show", "Test")]
    [string]$Action = "Install"
)

# Force UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Disable confirmation prompts
$ConfirmPreference = 'None'

# ========================== Configuration ==========================
# Tencent DNS servers
$TencentDNS = @("119.29.29.29", "182.254.116.116")

# Tencent domain list
$TencentDomains = @(
    "qq.com",
    "*.qq.com",
    "weixin.qq.com",
    "*.weixin.qq.com",
    "tencent.com",
    "*.tencent.com",
    "wegame.com",
    "*.wegame.com",
    "*.tim.qq.com",
    "*.qzone.qq.com",
    "v.qq.com",
    "*.v.qq.com",
    "*.lol.qq.com",
    "*.cf.qq.com",
    "*.dnf.qq.com",
    "wechat.com",
    "*.wechat.com",
    "*.qqmusic.qq.com",
    "*.meeting.qq.com"
)

# Rule identifier
$RuleComment = "Tencent DNS Permanent Rule"
# ===================================================================

# Check administrator privileges
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "`nERROR: Administrator privileges required!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# ======================== Core Functions ========================

function Install-TencentDNSRules {
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Installing Tencent DNS Permanent Configuration..." -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    # 1. Clean old rules
    Write-Host "`n[1/4] Cleaning old rules..." -ForegroundColor Yellow
    $oldRules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
    Where-Object { $_.Comment -eq $RuleComment }
    
    if ($oldRules) {
        $oldRules | Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        Write-Host "   OK Cleaned $($oldRules.Count) old rules" -ForegroundColor Green
    }
    else {
        Write-Host "   OK No cleanup needed" -ForegroundColor Green
    }

    # 2. Test NRPT functionality
    Write-Host "`n[2/4] Testing NRPT functionality..." -ForegroundColor Yellow
    try {
        $testNamespace = "*.nrpt-test-$(Get-Random).local"
        Add-DnsClientNrptRule -Namespace $testNamespace -NameServers "1.1.1.1" -Comment "Test" -ErrorAction Stop | Out-Null
        Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq $testNamespace } | Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        Write-Host "   OK NRPT is functional" -ForegroundColor Green
    }
    catch {
        Write-Host "`n   ERROR: NRPT functionality unavailable!" -ForegroundColor Red
        Write-Host "   Details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "   1. Windows version not supported (need Win10/11 or Server 2016+)" -ForegroundColor Gray
        Write-Host "   2. Domain Group Policy restricts NRPT" -ForegroundColor Gray
        Write-Host "   3. DNS Client service not running" -ForegroundColor Gray
        return $false
    }

    # 3. Create rules in batch
    Write-Host "`n[3/4] Creating NRPT rules..." -ForegroundColor Yellow
    $successCount = 0
    $failedDomains = @()

    foreach ($domain in $TencentDomains) {
        try {
            Add-DnsClientNrptRule -Namespace $domain `
                -NameServers $TencentDNS `
                -Comment $RuleComment `
                -ErrorAction Stop | Out-Null
            $successCount++
            Write-Host "   OK $domain" -ForegroundColor Green
        }
        catch {
            $failedDomains += $domain
            Write-Host "   FAIL $domain - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # 4. Clear DNS cache
    Write-Host "`n[4/4] Clearing DNS cache..." -ForegroundColor Yellow
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Host "   OK DNS cache cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "   WARN Cache clear failed (does not affect rules)" -ForegroundColor Yellow
    }

    # 5. Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "="*70 -ForegroundColor Cyan
    Write-Host "`nStatistics:" -ForegroundColor Cyan
    Write-Host "   Success: $successCount rules" -ForegroundColor Green
    Write-Host "   Failed: $($failedDomains.Count) rules" -ForegroundColor $(if ($failedDomains.Count -gt 0) { "Red" }else { "Green" })
    Write-Host "   DNS Servers: $($TencentDNS -join ', ')" -ForegroundColor Gray
    Write-Host "   Rule ID: $RuleComment" -ForegroundColor Gray

    if ($failedDomains.Count -gt 0) {
        Write-Host "`nFailed domains:" -ForegroundColor Yellow
        $failedDomains | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
    }

    Write-Host "`nImportant Notes:" -ForegroundColor Cyan
    Write-Host "   1. Rules are permanent and persist after system reboot" -ForegroundColor White
    Write-Host "   2. Only affects Tencent domains, other sites use default DNS" -ForegroundColor White
    Write-Host "   3. To uninstall: .\TencentDNS_ever.ps1 -Action Uninstall" -ForegroundColor White
    Write-Host "   4. Use Resolve-DnsName to verify (nslookup bypasses NRPT)" -ForegroundColor Yellow

    return $true
}

function Uninstall-TencentDNSRules {
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Uninstalling Tencent DNS Configuration..." -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
    Where-Object { $_.Comment -eq $RuleComment }

    if (-not $rules) {
        Write-Host "`nNo rules found to uninstall" -ForegroundColor Yellow
        return
    }

    Write-Host "`nFound $($rules.Count) rules, removing..." -ForegroundColor Yellow
    
    try {
        $rules | Remove-DnsClientNrptRule -Force -ErrorAction Stop
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        Write-Host "`nUninstallation Complete!" -ForegroundColor Green
        Write-Host "   Removed $($rules.Count) NRPT rules" -ForegroundColor Gray
        Write-Host "   DNS restored to system default" -ForegroundColor Gray
    }
    catch {
        Write-Host "`nUninstallation Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-TencentDNSRules {
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Current Tencent DNS Rules" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
    Where-Object { $_.Comment -eq $RuleComment }

    if (-not $rules) {
        Write-Host "`nNo Tencent DNS rules installed" -ForegroundColor Yellow
        Write-Host "To install, run:" -ForegroundColor Gray
        Write-Host "   .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor White
        return
    }

    Write-Host "`nFound $($rules.Count) rules:`n" -ForegroundColor Green

    $rules | Sort-Object Namespace | Format-Table -AutoSize `
    @{Label = "Domain"; Expression = { $_.Namespace -join ', ' } },
    @{Label = "DNS Servers"; Expression = { $_.NameServers -join ', ' } },
    @{Label = "Status"; Expression = { if ($_.Enabled) { "Enabled" }else { "Disabled" } } }

    Write-Host "`nRule Details:" -ForegroundColor Cyan
    Write-Host "   Rule Count: $($rules.Count)" -ForegroundColor Gray
    Write-Host "   DNS Servers: $($rules[0].NameServers -join ', ')" -ForegroundColor Gray
    Write-Host "   Status: $(if($rules[0].Enabled){'Enabled'}else{'Disabled'})" -ForegroundColor Gray
    Write-Host "   Rule ID: $($rules[0].Comment)" -ForegroundColor Gray
}

function Test-TencentDNSRules {
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Testing Tencent DNS Rules" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    # 1. Check rules exist
    Write-Host "`n[1/3] Checking NRPT rules..." -ForegroundColor Yellow
    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
    Where-Object { $_.Comment -eq $RuleComment }

    if (-not $rules) {
        Write-Host "   ERROR: No NRPT rules found!" -ForegroundColor Red
        Write-Host "   Please run: .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor Yellow
        return
    }

    Write-Host "   OK Found $($rules.Count) rules" -ForegroundColor Green

    # 2. Test DNS resolution
    Write-Host "`n[2/3] Testing DNS resolution..." -ForegroundColor Yellow
    $testDomains = @("qq.com", "v.qq.com", "weixin.qq.com")
    
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "   DNS cache cleared" -ForegroundColor Gray

    foreach ($domain in $testDomains) {
        try {
            Write-Host "`n   Testing: $domain" -ForegroundColor Cyan
            $result = Resolve-DnsName $domain -Type A -ErrorAction Stop | Select-Object -First 1
            Write-Host "      OK Resolved: $($result.IPAddress)" -ForegroundColor Green
            
            # Compare with direct Tencent DNS query
            $directResult = Resolve-DnsName $domain -Server $TencentDNS[0] -Type A -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($directResult -and $result.IPAddress -eq $directResult.IPAddress) {
                Write-Host "      OK IP matches, NRPT rule is working" -ForegroundColor Green
            }
            else {
                Write-Host "      WARN IP mismatch, rule may not be effective" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "      FAIL Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # 3. Verify DNS cache
    Write-Host "`n[3/3] Verifying DNS cache..." -ForegroundColor Yellow
    try {
        $cache = Get-DnsClientCache -ErrorAction Stop | Where-Object { $_.Entry -match "(qq|tencent|weixin)\.com" }
        if ($cache) {
            Write-Host "   OK Cache has $($cache.Count) Tencent domain entries" -ForegroundColor Green
            $cache | Select-Object -First 5 | Format-Table Entry, Data, TimeToLive -AutoSize
        }
        else {
            Write-Host "   INFO No Tencent domains in cache (normal, will populate after access)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   WARN Cannot read DNS cache" -ForegroundColor Yellow
    }

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Test Complete" -ForegroundColor Green
    Write-Host "="*70 -ForegroundColor Cyan
}

# ======================== Main Entry Point ========================

Write-Host @"

========================================================================
                                                                    
           Tencent DNS Permanent Configuration Tool v1.0                                
           Persistent NRPT Rules (Survives System Reboot)                
                                                                    
========================================================================

"@ -ForegroundColor Cyan

switch ($Action) {
    "Install" {
        $result = Install-TencentDNSRules
        if ($result) {
            Write-Host "`nSuccess! Rules are permanent and will persist after reboot." -ForegroundColor Green
        }
    }
    "Uninstall" {
        Uninstall-TencentDNSRules
    }
    "Show" {
        Show-TencentDNSRules
    }
    "Test" {
        Test-TencentDNSRules
    }
}

Write-Host "`nAvailable Commands:" -ForegroundColor Cyan
Write-Host "   Install:   .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor White
Write-Host "   Uninstall: .\TencentDNS_ever.ps1 -Action Uninstall" -ForegroundColor White
Write-Host "   Show:      .\TencentDNS_ever.ps1 -Action Show" -ForegroundColor White
Write-Host "   Test:      .\TencentDNS_ever.ps1 -Action Test" -ForegroundColor White

Read-Host "`nPress Enter to exit"
