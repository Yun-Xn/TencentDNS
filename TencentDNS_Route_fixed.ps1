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
[System.Text.Encoding]::Default = [System.Text.Encoding]::UTF8

# -------------------------- 配置项（可按需修改） --------------------------
# 腾讯DNS服务器地址
$TencentDNS = "119.29.29.29", "182.254.116.116"
# 腾讯系域名列表（标准化，移除中文域名）
$TencentDomains = @(
    "*.qq.com",        # QQ全系域名
    "*.weixin.qq.com", # 微信相关域名
    "*.tencent.com",   # 腾讯主域名
    "*.wegame.com",    # 腾讯游戏平台
    "*.tim.qq.com",    # TIM办公版
    "*.qzone.qq.com",  # QQ空间
    "*.v.qq.com",      # 腾讯视频（替换原中文域名）
    "*.lol.qq.com",    # 英雄联盟
    "*.cf.qq.com",     # 穿越火线
    "*.dnf.qq.com",    # 地下城与勇士
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
# 监控间隔（秒，建议5-15秒）
$MonitorInterval = 8
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

# ======================== 核心函数 ========================
<#
.SYNOPSIS
应用腾讯DNS策略（NRPT）
#>
function Enable-TencentDNS {
    if ($script:DNSPolicyActive) { return }

    try {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] 🔄 检测到腾讯软件运行，应用DNS策略..." -ForegroundColor Cyan
        
        # 清除旧策略（避免重复）
        Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
            Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" } | 
            Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue

        # 批量创建新策略
        foreach ($domain in $TencentDomains) {
            Add-DnsClientNrptRule -Namespace $domain `
                -ServerAddresses $TencentDNS `
                -Comment "Tencent Domain DNS Rule" `
                -Force -ErrorAction Stop | Out-Null
        }

        # 清除DNS缓存，策略立即生效
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        $script:DNSPolicyActive = $true
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 腾讯DNS策略已启用（$($TencentDNS -join ', ')）" -ForegroundColor Green
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
        # 批量检测进程，减少Get-Process调用次数
        $allProcesses = Get-Process -Name $TencentProcesses -ErrorAction SilentlyContinue
        return $allProcesses -ne $null -and $allProcesses.Count -gt 0
    }
    catch {
        Write-Warning "进程检测出错: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
检测浏览器是否访问腾讯系网站（轻量版）
#>
function Test-TencentWebAccess {
    try {
        # 仅检测已建立的HTTPS/HTTP连接，避免频繁DNS解析
        $tcpConnections = Get-NetTCPConnection -State Established -RemotePort 80,443 -ErrorAction SilentlyContinue
        if (-not $tcpConnections) { return $false }

        # 批量解析IP对应的域名（减少循环次数）
        $remoteIPs = $tcpConnections.RemoteAddress | Select-Object -Unique
        foreach ($ip in $remoteIPs) {
            try {
                $hostname = [System.Net.Dns]::GetHostEntry($ip).HostName
                foreach ($rootDomain in $TencentWebRootDomains) {
                    if ($hostname -like "*.$rootDomain" -or $hostname -eq $rootDomain) {
                        return $true
                    }
                }
            }
            catch {
                # 忽略解析失败的IP（如CDN/非域名IP）
                continue
            }
        }
        return $false
    }
    catch {
        Write-Warning "网页访问检测出错: $($_.Exception.Message)"
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

    # 注册Ctrl+C捕获（优雅退出）
    [Console]::TreatControlCAsInput = $false
    $exitEvent = New-Object System.Threading.ManualResetEvent($false)
    [Console]::CancelKeyPress += {
        Write-Host "`n`n[$(Get-Date -Format 'HH:mm:ss')] 🛑 检测到退出指令，正在清理..." -ForegroundColor Red
        $script:IsMonitoring = $false
        $exitEvent.Set()
        # 立即恢复DNS
        Disable-TencentDNS
    }

    # 监控主循环
    while ($script:IsMonitoring) {
        try {
            # 检测腾讯进程/网页访问
            $hasTencentProcess = Test-TencentProcessRunning
            $hasTencentWeb = Test-TencentWebAccess
            $shouldEnableTencentDNS = $hasTencentProcess -or $hasTencentWeb

            # 策略切换逻辑
            if ($shouldEnableTencentDNS -and -not $script:DNSPolicyActive) {
                Enable-TencentDNS
                # 输出触发原因
                if ($hasTencentProcess) {
                    $runningProcs = Get-Process -Name $TencentProcesses -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique
                    Write-Host "   📌 触发原因：运行中的腾讯软件 → $($runningProcs -join ', ')" -ForegroundColor Gray
                }
                if ($hasTencentWeb -and -not $hasTencentProcess) {
                    Write-Host "   📌 触发原因：浏览器访问腾讯系网站" -ForegroundColor Gray
                }
            }
            elseif (-not $shouldEnableTencentDNS -and $script:DNSPolicyActive) {
                Disable-TencentDNS
            }

            # 心跳日志（固定间隔输出，避免刷屏）
            $now = Get-Date
            if (($now - $script:LastHeartbeatTime).TotalSeconds -ge $HeartbeatInterval) {
                $status = if ($script:DNSPolicyActive) { "🟢 腾讯DNS" } else { "🔵 自动DNS" }
                Write-Host "[$($now.ToString('HH:mm:ss'))] 📡 监控中... 当前状态: $status" -ForegroundColor DarkGray
                $script:LastHeartbeatTime = $now
            }

            # 等待监控间隔（可被退出信号中断）
            if ($exitEvent.WaitOne($MonitorInterval * 1000)) {
                break
            }
        }
        catch {
            Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] 🚨 监控循环异常: $($_.Exception.Message)"
            Start-Sleep -Seconds $MonitorInterval
        }
    }

    # 退出清理
    $exitEvent.Dispose()
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
        Get-DnsClientNrptRule -ErrorAction SilentlyContinue | 
            Where-Object { $_.Comment -eq "Tencent Domain DNS Rule" } | 
            Remove-DnsClientNrptRule -Force -ErrorAction SilentlyContinue
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Host "已恢复为自动DNS" -ForegroundColor Green
    }
}
