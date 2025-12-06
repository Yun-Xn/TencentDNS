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
Install: .\TencentDNS_ever.ps1 -Action Install [-DebugMode]
Uninstall: .\TencentDNS_ever.ps1 -Action Uninstall [-DebugMode]
Show: .\TencentDNS_ever.ps1 -Action Show [-DebugMode]
Test: .\TencentDNS_ever.ps1 -Action Test [-DebugMode]
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Install", "Uninstall", "Show", "Test")]
    [string]$Action = "Install",

    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
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

# Detect Windows version for version-specific optimizations
$script:OSVersion = [System.Environment]::OSVersion.Version
$script:IsWindows11 = $script:OSVersion.Build -ge 22000
$script:IsWindows10 = $script:OSVersion.Major -eq 10 -and $script:OSVersion.Build -lt 22000 -and $script:OSVersion.Build -ge 10240

# ===================================================================

# Debug configuration
$script:DebugEnabled = $DebugMode.IsPresent
$script:StartTime = Get-Date
$script:DebugLog = @()

# Debug output function
function Write-DebugInfo {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = "Gray"
    )

    if (-not $script:DebugEnabled) { return }

    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $elapsed = [math]::Round(((Get-Date) - $script:StartTime).TotalMilliseconds, 0)
    $debugMessage = "[$timestamp +${elapsed}ms] [$Level] $Message"

    Write-Host $debugMessage -ForegroundColor $Color
    $script:DebugLog += $debugMessage
}

function Write-DebugVariable {
    param(
        [string]$Name,
        [object]$Value,
        [string]$Description = ""
    )

    if (-not $script:DebugEnabled) { return }

    $valueStr = if ($Value -is [array]) {
        "Array[$($Value.Count)]: $($Value -join ', ')"
    }
    elseif ($Value -is [string]) {
        "'$Value'"
    }
    else {
        $Value.ToString()
    }

    Write-DebugInfo "$Name = $valueStr $(if($Description){"($Description)"})" -Level "VAR"
}

function Write-DebugStep {
    param(
        [string]$Step,
        [string]$Details = ""
    )

    if (-not $script:DebugEnabled) { return }

    Write-DebugInfo "STEP: $Step $(if($Details){"- $Details"})" -Level "STEP" -Color "Cyan"
}

function Write-DebugError {
    param(
        [string]$Message,
        [object]$Exception = $null
    )

    if (-not $script:DebugEnabled) { return }

    Write-DebugInfo "ERROR: $Message" -Level "ERROR" -Color "Red"

    if ($Exception) {
        Write-DebugInfo "Exception Type: $($Exception.GetType().Name)" -Level "ERROR"
        Write-DebugInfo "Exception Message: $($Exception.Message)" -Level "ERROR"
        Write-DebugInfo "Stack Trace: $($Exception.StackTrace)" -Level "ERROR"
    }
}

function Write-DebugNetworkTest {
    param(
        [string]$Server,
        [int]$Port = 53
    )

    if (-not $script:DebugEnabled) { return }

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($Server, $Port)
        $timeout = 2000 # 2 seconds

        if ($connectTask.Wait($timeout)) {
            Write-DebugInfo "Network: $Server`:$Port - CONNECTED" -Level "NET" -Color "Green"
            $tcpClient.Close()
        }
        else {
            Write-DebugInfo "Network: $Server`:$Port - TIMEOUT" -Level "NET" -Color "Yellow"
        }
    }
    catch {
        Write-DebugInfo "Network: $Server`:$Port - FAILED ($($_.Exception.Message))" -Level "NET" -Color "Red"
    }
}

function Write-DebugSummary {
    if (-not $script:DebugEnabled) { return }

    $totalTime = [math]::Round(((Get-Date) - $script:StartTime).TotalMilliseconds, 0)
    Write-DebugInfo "EXECUTION SUMMARY:" -Level "SUMMARY" -Color "Magenta"
    Write-DebugInfo "Total execution time: ${totalTime}ms" -Level "SUMMARY"
    Write-DebugInfo "Debug log entries: $($script:DebugLog.Count)" -Level "SUMMARY"
    Write-DebugInfo "System: $([System.Environment]::OSVersion.VersionString)" -Level "SUMMARY"
    Write-DebugInfo "PowerShell: $($PSVersionTable.PSVersion)" -Level "SUMMARY"
    Write-DebugInfo "User: $([System.Environment]::UserName) ($([System.Environment]::UserDomainName))" -Level "SUMMARY"
}

# System compatibility check
function Test-SystemCompatibility {
    Write-DebugStep "Checking system compatibility"
    
    $osVersion = [System.Environment]::OSVersion.Version
    $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
    $psVersion = $PSVersionTable.PSVersion
    
    Write-DebugVariable "OSVersion" "$osCaption (Build $($osVersion.Build))" "Operating System"
    Write-DebugVariable "PowerShellVersion" $psVersion.ToString() "PowerShell Version"
    
    $issues = @()
    
    # Check Windows version (need Windows 10 1607+ / Server 2016+)
    # Windows 10 build 14393 = 1607 (Anniversary Update)
    # Windows 11 build 22000+
    if ($osVersion.Major -lt 10) {
        $issues += "Windows 10/11 or Server 2016+ required (current: $osCaption)"
    }
    elseif ($osVersion.Major -eq 10 -and $osVersion.Build -lt 14393) {
        $issues += "Windows 10 version 1607+ required (current build: $($osVersion.Build))"
    }
    
    # Check PowerShell version (need 5.1+)
    if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
        $issues += "PowerShell 5.1+ required (current: $psVersion)"
    }
    
    # Check DNS Client service
    try {
        $dnsService = Get-Service -Name "Dnscache" -ErrorAction Stop
        Write-DebugVariable "DnsClientService" $dnsService.Status "DNS Client service status"
        
        if ($dnsService.Status -ne 'Running') {
            $issues += "DNS Client service is not running (status: $($dnsService.Status))"
        }
    }
    catch {
        $issues += "Cannot access DNS Client service: $($_.Exception.Message)"
        Write-DebugError "Failed to check DNS Client service" $_.Exception
    }
    
    # Check DnsClient module availability
    $dnsClientModule = Get-Module -Name DnsClient -ListAvailable -ErrorAction SilentlyContinue
    if (-not $dnsClientModule) {
        $issues += "DnsClient PowerShell module not available"
    }
    else {
        Write-DebugVariable "DnsClientModule" "Available (Version: $($dnsClientModule.Version))" "DnsClient module status"
    }
    
    if ($issues.Count -gt 0) {
        Write-Host "`nSYSTEM COMPATIBILITY ISSUES DETECTED:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "   ✗ $issue" -ForegroundColor Red
            Write-DebugError $issue
        }
        return $false
    }
    
    Write-Host "`nSystem Compatibility Check: PASSED" -ForegroundColor Green
    Write-DebugInfo "System compatibility check passed" -Level "STEP"
    return $true
}

# Check administrator privileges
function Test-Administrator {
    Write-DebugStep "Checking administrator privileges"
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-DebugVariable "IsAdministrator" $isAdmin "Administrator privilege check result"
    return $isAdmin
}

if (-not (Test-Administrator)) {
    Write-Host "`nERROR: Administrator privileges required!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
    Write-DebugError "Script execution aborted: Administrator privileges required"
    Write-DebugSummary
    Read-Host "`nPress Enter to exit"
    exit 1
}

# Check system compatibility
if (-not (Test-SystemCompatibility)) {
    Write-Host "`nERROR: System compatibility check failed!" -ForegroundColor Red
    Write-Host "Please ensure your system meets the requirements" -ForegroundColor Yellow
    Write-DebugError "Script execution aborted: System compatibility check failed"
    Write-DebugSummary
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-DebugInfo "Script started with action: $Action" -Level "INIT"
Write-DebugVariable "Action" $Action "Requested operation"
Write-DebugVariable "DebugEnabled" $script:DebugEnabled "Debug mode status"
Write-DebugVariable "TencentDNS" $TencentDNS "DNS server configuration"
Write-DebugVariable "TencentDomains" $TencentDomains "Domain list (count: $($TencentDomains.Count))"
Write-DebugVariable "RuleComment" $RuleComment "NRPT rule identifier"

# Test network connectivity to DNS servers
Write-DebugStep "Testing network connectivity to DNS servers"
foreach ($dns in $TencentDNS) {
    Write-DebugNetworkTest $dns 53
}

# ======================== Core Functions ========================

function Install-TencentDNSRules {
    Write-DebugStep "Starting installation of Tencent DNS rules"
    Write-DebugVariable "TencentDomains.Count" $TencentDomains.Count "Number of domains to configure"
    Write-DebugVariable "TencentDNS" $TencentDNS "DNS servers to use"

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Installing Tencent DNS Permanent Configuration..." -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    # 1. Clean old rules
    Write-Host "`n[1/4] Cleaning old rules..." -ForegroundColor Yellow
    Write-DebugStep "Cleaning existing NRPT rules" "Looking for rules with comment: $RuleComment"

    $oldRules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue |
    Where-Object { $_.Comment -eq $RuleComment }

    Write-DebugVariable "oldRules.Count" $oldRules.Count "Number of existing rules found"

    if ($oldRules) {
        Write-DebugStep "Removing old rules"
        $oldRules | Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        Write-Host "   OK Cleaned $($oldRules.Count) old rules" -ForegroundColor Green
        Write-DebugInfo "Successfully removed $($oldRules.Count) existing rules" -Level "STEP"
    }
    else {
        Write-Host "   OK No cleanup needed" -ForegroundColor Green
        Write-DebugInfo "No existing rules found to clean up" -Level "STEP"
    }

    # 2. Test NRPT functionality
    Write-Host "`n[2/4] Testing NRPT functionality..." -ForegroundColor Yellow
    Write-DebugStep "Testing NRPT functionality" "Creating and removing test rule"

    try {
        $testNamespace = "*.nrpt-test-$(Get-Random).local"
        Write-DebugVariable "testNamespace" $testNamespace "Test namespace for NRPT validation"

        Add-DnsClientNrptRule -Namespace $testNamespace -NameServers "1.1.1.1" -Comment "Test" -ErrorAction Stop | Out-Null
        Write-DebugInfo "Test NRPT rule created successfully" -Level "STEP"

        Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq $testNamespace } | Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        Write-DebugInfo "Test NRPT rule removed successfully" -Level "STEP"

        Write-Host "   OK NRPT is functional" -ForegroundColor Green
        Write-DebugInfo "NRPT functionality test passed" -Level "STEP"
    }
    catch {
        $osVersion = [System.Environment]::OSVersion.Version
        $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
        
        Write-Host "`n   ERROR: NRPT functionality unavailable!" -ForegroundColor Red
        Write-Host "   Details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nSystem Information:" -ForegroundColor Yellow
        Write-Host "   OS: $osCaption (Build $($osVersion.Build))" -ForegroundColor Gray
        Write-Host "   PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        
        if ($osVersion.Build -lt 14393) {
            Write-Host "   1. ✗ Windows version too old (need build 14393+, current: $($osVersion.Build))" -ForegroundColor Red
            Write-Host "      Solution: Update to Windows 10 version 1607 or later" -ForegroundColor Cyan
        }
        else {
            Write-Host "   1. ✓ Windows version is compatible" -ForegroundColor Green
        }
        
        $dnsService = Get-Service -Name "Dnscache" -ErrorAction SilentlyContinue
        if ($dnsService -and $dnsService.Status -eq 'Running') {
            Write-Host "   2. ✓ DNS Client service is running" -ForegroundColor Green
        }
        else {
            Write-Host "   2. ✗ DNS Client service not running" -ForegroundColor Red
            Write-Host "      Solution: Run 'Start-Service Dnscache'" -ForegroundColor Cyan
        }
        
        Write-Host "   3. Domain Group Policy may restrict NRPT" -ForegroundColor Gray
        Write-Host "      Check: Run 'gpresult /r' to view applied policies" -ForegroundColor Cyan
        Write-Host "   4. Windows feature may be disabled" -ForegroundColor Gray
        Write-Host "      Check: Control Panel → Programs → Windows Features" -ForegroundColor Cyan

        Write-DebugError "NRPT functionality test failed" $_.Exception
        Write-DebugSummary
        return $false
    }

    # 3. Create rules in batch
    Write-Host "`n[3/4] Creating NRPT rules..." -ForegroundColor Yellow
    Write-DebugStep "Creating NRPT rules in batch" "Processing $($TencentDomains.Count) domains"

    $successCount = 0
    $failedDomains = @()
    $ruleCreationStart = Get-Date

    foreach ($domain in $TencentDomains) {
        $retryCount = 0
        $maxRetries = 2
        $ruleCreated = $false
        
        while ($retryCount -le $maxRetries -and -not $ruleCreated) {
            try {
                Write-DebugStep "Creating rule for domain" "$domain (attempt $($retryCount + 1)/$($maxRetries + 1))"

                Add-DnsClientNrptRule -Namespace $domain `
                    -NameServers $TencentDNS `
                    -Comment $RuleComment `
                    -ErrorAction Stop | Out-Null

                $successCount++
                $ruleCreated = $true
                Write-Host "   OK $domain" -ForegroundColor Green
                Write-DebugInfo "Successfully created rule for $domain" -Level "STEP"
            }
            catch {
                $retryCount++
                Write-DebugError "Failed to create rule for $domain (attempt $retryCount)" $_.Exception
                
                if ($retryCount -le $maxRetries) {
                    Write-DebugInfo "Retrying after 100ms delay..." -Level "STEP"
                    Start-Sleep -Milliseconds 100
                }
                else {
                    $failedDomains += $domain
                    Write-Host "   FAIL $domain - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }

    $ruleCreationTime = [math]::Round(((Get-Date) - $ruleCreationStart).TotalMilliseconds, 0)
    Write-DebugVariable "ruleCreationTime" $ruleCreationTime "Time taken to create rules (ms)"
    Write-DebugVariable "successCount" $successCount "Successfully created rules"
    Write-DebugVariable "failedDomains.Count" $failedDomains.Count "Failed rule creations"

    # 4. Clear DNS cache
    Write-Host "`n[4/4] Clearing DNS cache..." -ForegroundColor Yellow
    Write-DebugStep "Clearing DNS client cache"

    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Host "   OK DNS cache cleared" -ForegroundColor Green
        Write-DebugInfo "DNS cache cleared successfully" -Level "STEP"
    }
    catch {
        Write-Host "   WARN Cache clear failed (does not affect rules)" -ForegroundColor Yellow
        Write-DebugError "Failed to clear DNS cache" $_.Exception
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
    
    # Display Windows version specific information
    $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-Host "   System: $osCaption (Build $($script:OSVersion.Build))" -ForegroundColor Gray

    if ($failedDomains.Count -gt 0) {
        Write-Host "`nFailed domains:" -ForegroundColor Yellow
        $failedDomains | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
        Write-DebugVariable "failedDomains" $failedDomains "List of domains that failed rule creation"
    }

    Write-Host "`nImportant Notes:" -ForegroundColor Cyan
    Write-Host "   1. Rules are permanent and persist after system reboot" -ForegroundColor White
    Write-Host "   2. Only affects Tencent domains, other sites use default DNS" -ForegroundColor White
    Write-Host "   3. To uninstall: .\TencentDNS_ever.ps1 -Action Uninstall" -ForegroundColor White
    Write-Host "   4. Use Resolve-DnsName to verify (nslookup bypasses NRPT)" -ForegroundColor Yellow
    
    # Windows version specific notes
    if ($script:IsWindows11) {
        Write-Host "   5. Windows 11 detected - All features fully supported" -ForegroundColor Green
    }
    elseif ($script:IsWindows10) {
        Write-Host "   5. Windows 10 detected - All features fully supported" -ForegroundColor Green
    }

    Write-DebugInfo "Installation completed successfully" -Level "SUMMARY"
    Write-DebugVariable "InstallationResult" $true "Installation status"
    return $true
}

function Uninstall-TencentDNSRules {
    Write-DebugStep "Starting uninstallation of Tencent DNS rules"

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Uninstalling Tencent DNS Configuration..." -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    Write-DebugStep "Searching for existing NRPT rules" "Looking for rules with comment: $RuleComment"
    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue |
    Where-Object { $_.Comment -eq $RuleComment }

    Write-DebugVariable "rules.Count" $rules.Count "Number of rules found for uninstallation"

    if (-not $rules) {
        Write-Host "`nNo rules found to uninstall" -ForegroundColor Yellow
        Write-DebugInfo "No Tencent DNS rules found to uninstall" -Level "STEP"
        Write-DebugInfo "Uninstallation completed (no action needed)" -Level "SUMMARY"
        return
    }

    Write-Host "`nFound $($rules.Count) rules, removing..." -ForegroundColor Yellow
    Write-DebugStep "Removing NRPT rules" "Removing $($rules.Count) rules"

    try {
        $uninstallStart = Get-Date
        $rules | Remove-DnsClientNrptRule -Force -ErrorAction Stop
        Write-DebugInfo "Successfully removed $($rules.Count) NRPT rules" -Level "STEP"

        Write-DebugStep "Clearing DNS cache after uninstallation"
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-DebugInfo "DNS cache cleared after uninstallation" -Level "STEP"

        $uninstallTime = [math]::Round(((Get-Date) - $uninstallStart).TotalMilliseconds, 0)
        Write-DebugVariable "uninstallTime" $uninstallTime "Time taken for uninstallation (ms)"

        Write-Host "`nUninstallation Complete!" -ForegroundColor Green
        Write-Host "   Removed $($rules.Count) NRPT rules" -ForegroundColor Gray
        Write-Host "   DNS restored to system default" -ForegroundColor Gray

        Write-DebugInfo "Uninstallation completed successfully" -Level "SUMMARY"
        Write-DebugVariable "UninstallationResult" $true "Uninstallation status"
    }
    catch {
        Write-Host "`nUninstallation Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-DebugError "Uninstallation failed" $_.Exception
        Write-DebugVariable "UninstallationResult" $false "Uninstallation status"
    }
}

function Show-TencentDNSRules {
    Write-DebugStep "Displaying current Tencent DNS rules"

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Current Tencent DNS Rules" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    Write-DebugStep "Querying NRPT rules" "Looking for rules with comment: $RuleComment"
    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue |
    Where-Object { $_.Comment -eq $RuleComment }

    Write-DebugVariable "rules.Count" $rules.Count "Number of Tencent DNS rules found"

    if (-not $rules) {
        Write-Host "`nNo Tencent DNS rules installed" -ForegroundColor Yellow
        Write-Host "To install, run:" -ForegroundColor Gray
        Write-Host "   .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor White
        Write-DebugInfo "No Tencent DNS rules currently installed" -Level "STEP"
        Write-DebugInfo "Show operation completed (no rules found)" -Level "SUMMARY"
        return
    }

    Write-Host "`nFound $($rules.Count) rules:`n" -ForegroundColor Green
    Write-DebugInfo "Found $($rules.Count) Tencent DNS rules" -Level "STEP"

    $rules | Sort-Object Namespace | Format-Table -AutoSize `
    @{Label = "Domain"; Expression = { $_.Namespace -join ', ' } },
    @{Label = "DNS Servers"; Expression = { $_.NameServers -join ', ' } },
    @{Label = "Status"; Expression = { if ($_.Enabled) { "Enabled" }else { "Disabled" } } }

    Write-Host "`nRule Details:" -ForegroundColor Cyan
    Write-Host "   Rule Count: $($rules.Count)" -ForegroundColor Gray
    Write-Host "   DNS Servers: $($rules[0].NameServers -join ', ')" -ForegroundColor Gray
    Write-Host "   Status: $(if($rules[0].Enabled){'Enabled'}else{'Disabled'})" -ForegroundColor Gray
    Write-Host "   Rule ID: $($rules[0].Comment)" -ForegroundColor Gray

    Write-DebugVariable "RuleStatus" $(if ($rules[0].Enabled) { 'Enabled' }else { 'Disabled' }) "Current rule status"
    Write-DebugVariable "ConfiguredDNSServers" $($rules[0].NameServers -join ', ') "DNS servers in rules"
    Write-DebugInfo "Show operation completed successfully" -Level "SUMMARY"
}

function Test-TencentDNSRules {
    Write-DebugStep "Starting comprehensive DNS rules testing"

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Testing Tencent DNS Rules" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    # 1. Check rules exist
    Write-Host "`n[1/3] Checking NRPT rules..." -ForegroundColor Yellow
    Write-DebugStep "Checking NRPT rules existence" "Looking for rules with comment: $RuleComment"

    $rules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue |
    Where-Object { $_.Comment -eq $RuleComment }

    Write-DebugVariable "rules.Count" $rules.Count "Number of NRPT rules found"

    if (-not $rules) {
        Write-Host "   ERROR: No NRPT rules found!" -ForegroundColor Red
        Write-Host "   Please run: .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor Yellow
        Write-DebugError "No NRPT rules found for testing"
        Write-DebugInfo "Test operation aborted - no rules installed" -Level "SUMMARY"
        return
    }

    Write-Host "   OK Found $($rules.Count) rules" -ForegroundColor Green
    Write-DebugInfo "Found $($rules.Count) NRPT rules for testing" -Level "STEP"

    # 2. Test DNS resolution
    Write-Host "`n[2/3] Testing DNS resolution..." -ForegroundColor Yellow
    Write-DebugStep "Testing DNS resolution for sample domains"

    $testDomains = @("qq.com", "v.qq.com", "weixin.qq.com")
    Write-DebugVariable "testDomains" $testDomains "Domains to test DNS resolution"

    Write-DebugStep "Clearing DNS cache before testing"
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "   DNS cache cleared" -ForegroundColor Gray
    Write-DebugInfo "DNS cache cleared successfully" -Level "STEP"

    $testResults = @()
    $resolutionStart = Get-Date

    foreach ($domain in $testDomains) {
        Write-DebugStep "Testing DNS resolution" "Domain: $domain"
        try {
            Write-Host "`n   Testing: $domain" -ForegroundColor Cyan
            $result = Resolve-DnsName $domain -Type A -ErrorAction Stop | Select-Object -First 1
            Write-Host "      OK Resolved: $($result.IPAddress)" -ForegroundColor Green
            Write-DebugInfo "Successfully resolved $domain to $($result.IPAddress)" -Level "STEP"

            # Compare with direct Tencent DNS query
            Write-DebugStep "Comparing with direct DNS query" "Domain: $domain, Server: $($TencentDNS[0])"
            $directResult = Resolve-DnsName $domain -Server $TencentDNS[0] -Type A -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($directResult -and $result.IPAddress -eq $directResult.IPAddress) {
                Write-Host "      OK IP matches, NRPT rule is working" -ForegroundColor Green
                Write-DebugInfo "NRPT rule working correctly for $domain - IP matches direct query" -Level "STEP"
                $testResults += @{Domain = $domain; Status = "PASS"; IP = $result.IPAddress }
            }
            else {
                Write-Host "      WARN IP mismatch, rule may not be effective" -ForegroundColor Yellow
                Write-DebugInfo "NRPT rule may not be effective for $domain - IP mismatch" -Level "STEP"
                Write-DebugVariable "NRPT_IP" $result.IPAddress "IP from NRPT resolution"
                Write-DebugVariable "Direct_IP" $(if ($directResult) { $directResult.IPAddress }else { "N/A" }) "IP from direct DNS query"
                $testResults += @{Domain = $domain; Status = "WARN"; IP = $result.IPAddress }
            }
        }
        catch {
            Write-Host "      FAIL Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-DebugError "DNS resolution failed for $domain" $_.Exception
            $testResults += @{Domain = $domain; Status = "FAIL"; IP = "N/A" }
        }
    }

    $resolutionTime = [math]::Round(((Get-Date) - $resolutionStart).TotalMilliseconds, 0)
    Write-DebugVariable "resolutionTime" $resolutionTime "Time taken for DNS resolution tests (ms)"
    Write-DebugVariable "testResults" $testResults "Summary of DNS resolution test results"

    # 3. Verify DNS cache
    Write-Host "`n[3/3] Verifying DNS cache..." -ForegroundColor Yellow
    Write-DebugStep "Verifying DNS cache contents"

    try {
        $cache = Get-DnsClientCache -ErrorAction Stop | Where-Object { $_.Entry -match "(qq|tencent|weixin)\.com" }
        Write-DebugVariable "cache.Count" $cache.Count "Number of Tencent domain entries in DNS cache"

        if ($cache) {
            Write-Host "   OK Cache has $($cache.Count) Tencent domain entries" -ForegroundColor Green
            Write-DebugInfo "Found $($cache.Count) Tencent domain entries in DNS cache" -Level "STEP"
            $cache | Select-Object -First 5 | Format-Table Entry, Data, TimeToLive -AutoSize
        }
        else {
            Write-Host "   INFO No Tencent domains in cache (normal, will populate after access)" -ForegroundColor Gray
            Write-DebugInfo "No Tencent domains found in DNS cache (expected for fresh cache)" -Level "STEP"
        }
    }
    catch {
        Write-Host "   WARN Cannot read DNS cache" -ForegroundColor Yellow
        Write-DebugError "Failed to read DNS cache" $_.Exception
    }

    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "Test Complete" -ForegroundColor Green
    Write-Host "="*70 -ForegroundColor Cyan

    Write-DebugInfo "DNS rules testing completed" -Level "SUMMARY"
    Write-DebugVariable "TestCompletionStatus" "SUCCESS" "Overall test completion status"
}

# ======================== Main Entry Point ========================

Write-Host @"

========================================================================

           Tencent DNS Permanent Configuration Tool v1.0
           Persistent NRPT Rules (Survives System Reboot)

========================================================================

"@ -ForegroundColor Cyan

Write-DebugInfo "Main entry point reached, processing action: $Action" -Level "INIT"
Write-DebugVariable "Action" $Action "User requested action"

switch ($Action) {
    "Install" {
        Write-DebugStep "Executing Install action"
        $result = Install-TencentDNSRules
        if ($result) {
            Write-Host "`nSuccess! Rules are permanent and will persist after reboot." -ForegroundColor Green
            Write-DebugInfo "Install action completed successfully" -Level "SUMMARY"
            Write-DebugVariable "InstallResult" $true "Installation outcome"
        }
        else {
            Write-DebugInfo "Install action failed" -Level "SUMMARY"
            Write-DebugVariable "InstallResult" $false "Installation outcome"
        }
    }
    "Uninstall" {
        Write-DebugStep "Executing Uninstall action"
        Uninstall-TencentDNSRules
        Write-DebugInfo "Uninstall action completed" -Level "SUMMARY"
    }
    "Show" {
        Write-DebugStep "Executing Show action"
        Show-TencentDNSRules
        Write-DebugInfo "Show action completed" -Level "SUMMARY"
    }
    "Test" {
        Write-DebugStep "Executing Test action"
        Test-TencentDNSRules
        Write-DebugInfo "Test action completed" -Level "SUMMARY"
    }
    default {
        Write-Host "`nERROR: Invalid action '$Action'" -ForegroundColor Red
        Write-Host "Valid actions: Install, Uninstall, Show, Test" -ForegroundColor Yellow
        Write-DebugError "Invalid action specified: $Action"
        Write-DebugInfo "Script execution aborted due to invalid action" -Level "SUMMARY"
    }
}

Write-Host "`nAvailable Commands:" -ForegroundColor Cyan
Write-Host "   Install:   .\TencentDNS_ever.ps1 -Action Install" -ForegroundColor White
Write-Host "   Uninstall: .\TencentDNS_ever.ps1 -Action Uninstall" -ForegroundColor White
Write-Host "   Show:      .\TencentDNS_ever.ps1 -Action Show" -ForegroundColor White
Write-Host "   Test:      .\TencentDNS_ever.ps1 -Action Test" -ForegroundColor White

# Final debug summary
Write-DebugSummary

Read-Host "`nPress Enter to exit"
