<#
.SYNOPSIS
Windows自动分流DNS：腾讯系软件运行时使用指定DNS，关闭后自动恢复
.DESCRIPTION
通过Windows NRPT（名称解析策略表）实现精准DNS分流，实时监控腾讯系软件运行状态
.REQUIREMENTS
1. 以管理员身份运行PowerShell
2. Windows 10/11/Server 2016+（NRPT功能原生支持）
.FEATURES
- 自动检测腾讯系软件进程（QQ、微信、WeGame等）
- 监控腾讯系网站访问状态（浏览器标签页）
- 软件运行时自动应用腾讯DNS策略
- 软件关闭后自动恢复默认DNS设置
- 优雅退出（Ctrl+C）并自动清理DNS策略
#>

# 强制UTF-8编码解析（解决中文乱码）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 全局禁用确认提示（避免Remove-DnsClientNrptRule等命令弹窗）
$ConfirmPreference = 'None'

# -------------------------- 配置项（可按需修改） --------------------------
# 腾讯DNS服务器地址
$TencentDNS = "119.29.29.29", "182.254.116.116"
# 腾讯系域名列表（标准化，移除中文域名）
$TencentDomains = @(
    "qq.com",          # QQ主域名
    "*.qq.com",        # QQ全系域名
    "weixin.qq.com",   # 微信主域名
    "*.weixin.qq.com", # 微信相关域名
    "tencent.com",     # 腾讯主域名
    "*.tencent.com",   # 腾讯主域名
    "wegame.com",      # WeGame主域名
    "*.wegame.com",    # 腾讯游戏平台
    "*.tim.qq.com",    # TIM办公版
    "*.qzone.qq.com",  # QQ空间
    "v.qq.com",        # 腾讯视频主域名
    "*.v.qq.com",      # 腾讯视频（替换原中文域名）
    "*.lol.qq.com",    # 英雄联盟
    "*.cf.qq.com",     # 穿越火线
    "*.dnf.qq.com",    # 地下城与勇士
    "wechat.com",      # 微信海外版主域名
    "*.wechat.com",    # 微信海外版
    "*.qqmusic.qq.com",# QQ音乐
    "*.meeting.qq.com" # 腾讯会议
)
# 需要监控的腾讯系软件进程名（不含.exe后缀，支持通配符）
$TencentProcesses = @(
    "QQ", "WeChat", "WXWork", "TIM", "WeGame",
    "QQMusic", "QQBrowser", "QQLive", "TencentMeeting",
    "CrossFire", "LOLCLIENT", "DNF", "PUBGLite", "TenioLauncher"
)
# 腾讯系网站根域名（用于检测浏览器访问）
$TencentWebRootDomains = @("qq.com", "tencent.com", "weixin.qq.com", "wegame.com", "v.qq.com")
# 腾讯IP段（用于快速检测，避免DNS反向解析）
$TencentIPRanges = @(
    "122.14.0.0/16",    # 腾讯云
    "123.151.0.0/16",   # 腾讯
    "183.60.0.0/16",    # 腾讯云
    "203.205.0.0/16",   # 腾讯
    "43.130.0.0/16",    # 腾讯云国际
    "43.132.0.0/16",    # 腾讯云
    "43.134.0.0/16",    # 腾讯云
    "43.136.0.0/16",    # 腾讯云
    "43.138.0.0/16",    # 腾讯云
    "43.139.0.0/16",    # 腾讯云
    "43.140.0.0/16",    # 腾讯云
    "43.142.0.0/16",    # 腾讯云
    "43.143.0.0/16",    # 腾讯云
    "43.152.0.0/16",    # 腾讯云
    "43.153.0.0/16",    # 腾讯云
    "43.154.0.0/16",    # 腾讯云
    "43.155.0.0/16",    # 腾讯云
    "43.156.0.0/16",    # 腾讯云
    "43.157.0.0/16",    # 腾讯云
    "43.159.0.0/16",    # 腾讯云
    "43.163.0.0/16",    # 腾讯云
    "150.109.0.0/16",   # 腾讯云
    "162.14.0.0/16",    # 腾讯云
    "175.24.0.0/16"     # 腾讯
)
# 监控间隔（秒，建议5-15秒）
$MonitorInterval = 10
# 心跳日志输出间隔（秒）
$HeartbeatInterval = 30
# -------------------------------------------------------------------------

# 检查管理员权限
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "❌ 请以【管理员身份】运行此脚本！"
    Read-Host "按任意键退出"
    exit 1
}

# 全局变量
$script:DNSPolicyActive = $false
$script:LastHeartbeatTime = Get-Date
$script:IsMonitoring = $true
$script:DNSCache = @{}  # DNS解析缓存
$script:BrowserProcesses = @("chrome", "msedge", "firefox", "opera")  # 主流浏览器

# ======================== 核心函数 ========================
<#
.SYNOPSIS
应用腾讯DNS策略（NRPT）
#>
function Enable-TencentDNS {
    if ($script:DNSPolicyActive) { return }

    try {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] 🔄 检测到腾讯软件运行，正在切换DNS..." -ForegroundColor Cyan
        
        # 清除旧策略（避免重复）
        Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
        Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" } | 
        Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue

        # 检测NRPT功能是否可用
        $testRule = $null
        try {
            # 直接尝试创建实际规则，如果失败会进入catch
            $testNamespace = "*.test-nrpt-check.local"
            Add-DnsClientNrptRule -Namespace $testNamespace -NameServers "1.1.1.1" -Comment "NRPT Test" -ErrorAction Stop | Out-Null
            # 立即删除测试规则
            Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq $testNamespace } | Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host "`n⚠️  NRPT功能不可用" -ForegroundColor Yellow
            Write-Host "[错误详情] $errorMsg" -ForegroundColor Red
            Write-Host "`n诊断信息：" -ForegroundColor Cyan
            Write-Host "  - Windows版本: Win11 (Build $([System.Environment]::OSVersion.Version.Build))" -ForegroundColor Gray
            Write-Host "  - DNS服务状态: $(Get-Service Dnscache | Select-Object -ExpandProperty Status)" -ForegroundColor Gray
            
            # 检查是否在域环境
            $isDomain = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
            Write-Host "  - 域环境: $isDomain" -ForegroundColor Gray
            
            if ($errorMsg -match "无法加载 NRPT 信息" -or $errorMsg -match "WIN32 5") {
                Write-Host "`n原因分析：权限不足或组策略限制" -ForegroundColor Yellow
                Write-Host "解决方案：" -ForegroundColor Cyan
                Write-Host "  1. 检查组策略: gpedit.msc → 计算机配置 → 管理模板 → 网络 → DNS客户端" -ForegroundColor Gray
                Write-Host "  2. 运行: gpupdate /force 刷新组策略" -ForegroundColor Gray
                Write-Host "  3. 重启DNS客户端服务: Restart-Service Dnscache" -ForegroundColor Gray
            }
            
            Write-Host "`n备用方案：切换到【手动修改网络适配器DNS】模式" -ForegroundColor Cyan
            Write-Host "运行以下命令手动设置DNS：" -ForegroundColor Gray
            Write-Host "  Get-NetAdapter | Where-Object Status -eq 'Up' | Set-DnsClientServerAddress -ServerAddresses '119.29.29.29','182.254.116.116'" -ForegroundColor White
            return
        }

        # 批量创建新策略
        $ruleCount = 0
        $dnsServers = @("119.29.29.29", "182.254.116.116")
        foreach ($domain in $script:TencentDomains) {
            try {
                # 使用 -NameServers 参数（必须是字符串数组）
                Add-DnsClientNrptRule -Namespace $domain `
                    -NameServers $dnsServers `
                    -Comment "Tencent Domain DNS Rule" `
                    -ErrorAction Stop | Out-Null
                $ruleCount++
            }
            catch {
                Write-Host "⚠️  创建规则失败: $domain - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        if ($ruleCount -eq 0) {
            Write-Host "`n❌ 所有DNS策略创建失败，NRPT功能不可用" -ForegroundColor Red
            Write-Host "请检查：" -ForegroundColor Yellow
            Write-Host "  1. 是否以管理员身份运行" -ForegroundColor Gray
            Write-Host "  2. 是否在域环境中（域组策略可能限制）" -ForegroundColor Gray
            Write-Host "  3. 系统是否支持NRPT（Win10/11, Server 2016+）" -ForegroundColor Gray
            return
        }

        # 清除DNS缓存，策略立即生效
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        $script:DNSPolicyActive = $true
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ DNS已切换至腾讯DNS（$($TencentDNS -join ', ')）" -ForegroundColor Green
        Write-Host "   ├─ 已应用 $ruleCount 条NRPT规则" -ForegroundColor Gray
        Write-Host "   └─ DNS缓存已清空，策略立即生效" -ForegroundColor Gray
    }
    catch {
        Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] ❌ DNS策略应用失败: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
移除腾讯DNS策略，恢复自动DNS
#>
function Disable-TencentDNS {
    if (-not $script:DNSPolicyActive) { return }

    try {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] 🔄 未检测到腾讯软件，恢复自动DNS..." -ForegroundColor Yellow
        
        # 清理NRPT策略
        Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
        Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" } | 
        Remove-DnsClientNrptRule -Force -ErrorAction Stop

        # 清除DNS缓存
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        $script:DNSPolicyActive = $false
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 已恢复为系统自动DNS" -ForegroundColor Green
    }
    catch {
        Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] ❌ DNS策略清理失败: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
高效检测腾讯进程是否运行（减少资源占用）
#>
function Test-TencentProcessRunning {
    try {
        $runningProcesses = @()
        # 逐个检测进程，确保精确匹配
        foreach ($processName in $TencentProcesses) {
            $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($process) {
                $runningProcesses += $processName
            }
        }
        return $runningProcesses
    }
    catch {
        Write-Warning "进程检测出错: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
检测浏览器是否访问腾讯系网站（高性能版）
#>
function Test-TencentWebAccess {
    try {
        # 1. 仅检测主流浏览器进程的PID
        $browserPIDs = @()
        foreach ($browserName in $script:BrowserProcesses) {
            $processes = Get-Process -Name $browserName -ErrorAction SilentlyContinue
            if ($processes) {
                $browserPIDs += $processes.Id
            }
        }
        
        if ($browserPIDs.Count -eq 0) { 
            return $false 
        }

        # 2. 仅检测浏览器进程的TCP连接
        $allConnections = Get-NetTCPConnection -State Established -RemotePort 443 -ErrorAction SilentlyContinue
        $tcpConnections = $allConnections | Where-Object { $browserPIDs -contains $_.OwningProcess }
        
        if (-not $tcpConnections) { 
            return $false 
        }

        # 3. 过滤内网IP和无效IP，限制前10个
        $validIPs = $tcpConnections.RemoteAddress | 
            Where-Object { 
                $_ -notmatch '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.|224\.)' 
            } | 
            Select-Object -Unique -First 10
        
        if ($validIPs.Count -eq 0) { 
            return $false 
        }

        # 4. 优先使用IP段匹配（快速路径，无需DNS解析）
        foreach ($ip in $validIPs) {
            if (Test-TencentIP $ip) {
                return $true
            }
        }        # 5. 批量异步解析DNS（带缓存）- 作为备用方案
        $jobs = @()
        $cacheHits = 0
        foreach ($ip in $validIPs) {
            # 检查缓存
            if ($script:DNSCache.ContainsKey($ip)) {
                $hostname = $script:DNSCache[$ip]
                $cacheHits++
                if ($hostname -and (Test-TencentDomain $hostname)) {
                    return $true
                }
                continue
            }
            
            # 创建异步解析Job
            $jobs += Start-Job -ScriptBlock {
                param($ipAddr)
                try {
                    $host = [System.Net.Dns]::GetHostEntry($ipAddr).HostName
                    return @{IP = $ipAddr; Host = $host }
                }
                catch {
                    return @{IP = $ipAddr; Host = $null }
                }
            } -ArgumentList $ip
        }
        
        # 6. 等待所有Job完成（最多2秒）
        if ($jobs.Count -gt 0) {
            $completed = Wait-Job $jobs -Timeout 2
            $results = $completed | Receive-Job
            Get-Job | Remove-Job -Force
            
            # 7. 检查结果并更新缓存
            foreach ($result in $results) {
                if ($result.Host) {
                    $script:DNSCache[$result.IP] = $result.Host
                    if (Test-TencentDomain $result.Host) {
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
快速检测域名是否属于腾讯系
#>
function Test-TencentDomain {
    param([string]$hostname)
    
    if (-not $hostname) { return $false }
    
    # 直接字符串匹配，比循环快
    $isTencent = ($hostname -match '\.qq\.com$|^qq\.com$|\.tencent\.com$|^tencent\.com$|\.weixin\.qq\.com$|\.wegame\.com$|^wegame\.com$|\.v\.qq\.com$')
    
    return $isTencent
}

<#
.SYNOPSIS
检测IP是否属于腾讯IP段
#>
function Test-TencentIP {
    param([string]$ipAddress)
    
    if (-not $ipAddress) { return $false }
    
    try {
        $ip = [System.Net.IPAddress]::Parse($ipAddress)
        $ipBytes = $ip.GetAddressBytes()
        
        # 将IP转换为数字便于比较
        $ipNum = ([uint32]$ipBytes[0] -shl 24) + ([uint32]$ipBytes[1] -shl 16) + ([uint32]$ipBytes[2] -shl 8) + $ipBytes[3]
        
        foreach ($range in $script:TencentIPRanges) {
            $parts = $range.Split('/')
            $network = [System.Net.IPAddress]::Parse($parts[0])
            $netBytes = $network.GetAddressBytes()
            $netNum = ([uint32]$netBytes[0] -shl 24) + ([uint32]$netBytes[1] -shl 16) + ([uint32]$netBytes[2] -shl 8) + $netBytes[3]
            
            $prefix = [int]$parts[1]
            $mask = [uint32]([Math]::Pow(2, 32) - [Math]::Pow(2, (32 - $prefix)))
            
            if (($ipNum -band $mask) -eq ($netNum -band $mask)) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
启动监控循环（核心逻辑）
#>
function Start-Monitoring {
    Write-Host "`n" + "="*70 -ForegroundColor Magenta
    Write-Host "🚀 腾讯DNS自动切换监控已启动 [管理员模式]" -ForegroundColor Magenta
    Write-Host "="*70 -ForegroundColor Magenta
    Write-Host "📋 监控配置：" -ForegroundColor Cyan
    Write-Host "   ├─ 腾讯DNS: $($TencentDNS -join ', ')" -ForegroundColor Gray
    Write-Host "   ├─ 监控进程: $($TencentProcesses.Count) 个" -ForegroundColor Gray
    Write-Host "   ├─ 监控域名: $($TencentDomains.Count) 个" -ForegroundColor Gray
    Write-Host "   └─ 检测间隔: $MonitorInterval 秒" -ForegroundColor Gray
    Write-Host "`n💡 操作提示：按 Ctrl+C 停止监控并自动恢复DNS`n" -ForegroundColor Yellow

    # 监控主循环
    while ($script:IsMonitoring) {
        try {
            # 检测腾讯进程/网页访问
            $runningProcesses = Test-TencentProcessRunning
            $hasTencentWeb = Test-TencentWebAccess
            $shouldEnableTencentDNS = ($runningProcesses.Count -gt 0) -or $hasTencentWeb

            # 策略切换逻辑
            if ($shouldEnableTencentDNS -and -not $script:DNSPolicyActive) {
                Enable-TencentDNS
                # 输出详细的触发原因
                if ($runningProcesses.Count -gt 0) {
                    Write-Host "   📌 检测到运行中的腾讯软件 ($($runningProcesses.Count)个):" -ForegroundColor Cyan
                    Write-Host "      → $($runningProcesses -join ', ')" -ForegroundColor Yellow
                }
                if ($hasTencentWeb) {
                    Write-Host "   📌 检测到浏览器访问腾讯系网站" -ForegroundColor Cyan
                }
            }
            elseif (-not $shouldEnableTencentDNS -and $script:DNSPolicyActive) {
                Write-Host "\n[$(Get-Date -Format 'HH:mm:ss')] 🔄 所有腾讯软件已关闭" -ForegroundColor Yellow
                Disable-TencentDNS
            }

            # 心跳日志（固定间隔输出，避免刷屏）
            $now = Get-Date
            if (($now - $script:LastHeartbeatTime).TotalSeconds -ge $HeartbeatInterval) {
                $status = if ($script:DNSPolicyActive) { "🟢 腾讯DNS" } else { "🔵 自动DNS" }
                $processInfo = if ($runningProcesses.Count -gt 0) { "检测到 $($runningProcesses.Count) 个腾讯软件" } else { "无腾讯软件运行" }
                Write-Host "[$($now.ToString('HH:mm:ss'))] 📡 监控中... 状态: $status | $processInfo" -ForegroundColor DarkGray
                $script:LastHeartbeatTime = $now
            }

            # 等待监控间隔
            Start-Sleep -Seconds $MonitorInterval
        }
        catch {
            Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] 🚨 监控循环异常: $($_.Exception.Message)"
            Start-Sleep -Seconds $MonitorInterval
        }
    }

    # 退出清理
    Write-Host "`n" + "="*70 -ForegroundColor Magenta
    Write-Host "✅ 监控已停止，DNS已恢复为系统默认设置" -ForegroundColor Green
    Write-Host "="*70 -ForegroundColor Magenta
}

# ======================== 主程序入口 ========================
try {
    # 初始化：清理残留的旧策略
    Write-Host "🔧 初始化中... 清理残留DNS策略" -ForegroundColor Cyan
    Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
        Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" } | 
        Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
    
    # 启动监控
    Start-Monitoring
}
catch {
    Write-Error "[$(Get-Date -Format 'HH:mm:ss')] ❌ 程序异常终止: $($_.Exception.Message)"
    # 强制清理策略
    Disable-TencentDNS
    Read-Host "`n按任意键退出"
    exit 1
}
finally {
    # 最终兜底：确保DNS恢复
    if ($script:DNSPolicyActive) {
        Write-Host "`n🔧 最终清理：恢复系统自动DNS" -ForegroundColor Yellow
        Disable-TencentDNS
    }
}