# Windows 10/11 适配性优化说明

## 📋 概述

`TencentDNS_ever.ps1` 脚本已针对 Windows 10 和 Windows 11 进行全面优化,确保在不同版本的 Windows 系统上都能稳定运行。

## 🎯 支持的系统版本

### ✅ 完全支持

#### Windows 11
- **所有版本**: Build 22000 及更高
- **状态**: ✅ 完全支持,所有功能正常
- **特性**:
  - 完整的 NRPT (Name Resolution Policy Table) 支持
  - 原生 DNS Client 模块
  - 最佳性能和稳定性
  - 自动版本检测和优化

#### Windows 10
| 版本 | Build | 支持状态 | 说明 |
|------|-------|----------|------|
| 21H2 | 19044 | ✅ 完全支持 | 推荐版本 |
| 21H1 | 19043 | ✅ 完全支持 | 推荐版本 |
| 20H2 | 19042 | ✅ 完全支持 | 推荐版本 |
| 2004 | 19041 | ✅ 完全支持 | 推荐版本 |
| 1909 | 18363 | ✅ 完全支持 | 正常使用 |
| 1903 | 18362 | ✅ 完全支持 | 正常使用 |
| 1809 | 17763 | ✅ 完全支持 | 正常使用 |
| 1803 | 17134 | ✅ 完全支持 | 正常使用 |
| 1709 | 16299 | ✅ 完全支持 | 正常使用 |
| 1703 | 15063 | ✅ 完全支持 | 正常使用 |
| 1607 | 14393 | ✅ 完全支持 | 最低要求 |

#### Windows Server
- **Server 2022**: ✅ 完全支持
- **Server 2019**: ✅ 完全支持
- **Server 2016**: ✅ 完全支持

### ❌ 不支持

| 系统 | Build | 原因 |
|------|-------|------|
| Windows 10 1511 | < 14393 | 缺少完整的 NRPT 支持 |
| Windows 10 1507 | 10240 | 缺少完整的 NRPT 支持 |
| Windows 8.1 | - | 不支持 NRPT |
| Windows 8 | - | 不支持 NRPT |
| Windows 7 | - | 不支持 NRPT |
| Server 2012 R2 | - | 缺少完整的 NRPT 支持 |
| Server 2012 | - | 不支持 NRPT |

## 🔍 自动兼容性检查

### 检查项目

脚本启动时会自动执行以下兼容性检查:

#### 1. Windows 版本检查
```powershell
- 检测操作系统版本和构建号
- 验证是否满足最低版本要求 (Build 14393+)
- 显示友好的系统版本信息
```

**检测逻辑:**
- Windows Major Version >= 10
- Windows Build >= 14393 (Windows 10 1607)

**错误示例:**
```
✗ Windows 10 version 1607+ required (current build: 10240)
  Solution: Update to Windows 10 version 1607 or later
```

#### 2. PowerShell 版本检查
```powershell
- 检测 PowerShell 版本
- 验证是否 >= 5.1
- 显示当前 PowerShell 版本
```

**检测逻辑:**
- PowerShell Major >= 5
- PowerShell Minor >= 1 (if Major == 5)

**错误示例:**
```
✗ PowerShell 5.1+ required (current: 5.0.10240.17146)
  Solution: Update PowerShell or upgrade Windows
```

#### 3. DNS Client 服务检查
```powershell
- 检查 Dnscache 服务状态
- 验证服务是否正在运行
- 显示服务状态
```

**检测逻辑:**
- Get-Service -Name "Dnscache"
- Status == 'Running'

**错误示例:**
```
✗ DNS Client service is not running (status: Stopped)
  Solution: Run 'Start-Service Dnscache'
```

#### 4. DnsClient 模块检查
```powershell
- 检查 DnsClient PowerShell 模块
- 验证模块是否可用
- 显示模块版本
```

**检测逻辑:**
- Get-Module -Name DnsClient -ListAvailable

**错误示例:**
```
✗ DnsClient PowerShell module not available
  Solution: Run 'sfc /scannow' to repair system files
```

## 🛠️ 优化特性

### 1. 版本特定检测
```powershell
# 自动检测 Windows 版本
$script:OSVersion = [System.Environment]::OSVersion.Version
$script:IsWindows11 = $script:OSVersion.Build -ge 22000
$script:IsWindows10 = $script:OSVersion.Major -eq 10 -and 
                      $script:OSVersion.Build -lt 22000 -and 
                      $script:OSVersion.Build -ge 10240
```

### 2. 智能重试机制
针对不同 Windows 版本的稳定性差异,实现了智能重试:

```powershell
- 每个 NRPT 规则创建失败后自动重试
- 最多重试 2 次(共 3 次尝试)
- 重试间隔 100ms
- 避免临时性错误导致安装失败
```

**重试场景:**
- 网络延迟导致的临时失败
- 系统资源繁忙
- 并发操作冲突

### 3. 详细错误诊断
当 NRPT 功能测试失败时,提供针对性的诊断信息:

```powershell
✓ 自动检测失败原因
✓ 显示系统信息(版本、Build、PowerShell)
✓ 逐项检查可能的问题
✓ 提供具体的解决方案
```

**诊断输出示例:**
```
ERROR: NRPT functionality unavailable!
Details: Access denied

System Information:
   OS: Microsoft Windows 10 Pro (Build 19044)
   PowerShell: 5.1.19041.4648

Possible causes:
   1. ✓ Windows version is compatible
   2. ✓ DNS Client service is running
   3. Domain Group Policy may restrict NRPT
      Check: Run 'gpresult /r' to view applied policies
   4. Windows feature may be disabled
      Check: Control Panel → Programs → Windows Features
```

### 4. 系统信息展示
安装完成后显示当前系统版本:

```powershell
Statistics:
   Success: 19 rules
   Failed: 0 rules
   DNS Servers: 119.29.29.29, 182.254.116.116
   Rule ID: Tencent DNS Permanent Rule
   System: Microsoft Windows 11 Home China (Build 22631)

Important Notes:
   1. Rules are permanent and persist after system reboot
   2. Only affects Tencent domains, other sites use default DNS
   3. To uninstall: .\TencentDNS_ever.ps1 -Action Uninstall
   4. Use Resolve-DnsName to verify (nslookup bypasses NRPT)
   5. Windows 11 detected - All features fully supported
```

## 📊 性能优化

### Windows 11 优化
- 利用最新的 DNS 缓存机制
- 优化的 NRPT 规则处理
- 更快的规则创建速度

### Windows 10 优化
- 兼容旧版本的 DNS Client 实现
- 稳定的重试机制
- 适应不同版本的行为差异

## 🧪 测试建议

### 测试命令
```powershell
# 1. 检查系统兼容性(带调试信息)
.\TencentDNS_ever.ps1 -Action Show -DebugMode

# 2. 安装并查看详细过程
.\TencentDNS_ever.ps1 -Action Install -DebugMode

# 3. 测试 DNS 解析
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

### 验证系统信息
```powershell
# 查看 Windows 版本
[System.Environment]::OSVersion

# 查看构建号
[System.Environment]::OSVersion.Version.Build

# 查看 PowerShell 版本
$PSVersionTable.PSVersion

# 查看 DNS Client 服务状态
Get-Service -Name Dnscache

# 查看 DnsClient 模块
Get-Module -Name DnsClient -ListAvailable
```

## 🔧 故障排查

### 问题 1: 系统版本过低
**症状**: 提示 "Windows 10 version 1607+ required"

**解决方案**:
1. 检查当前 Windows 版本:
   ```powershell
   winver
   ```
2. 更新 Windows:
   - 设置 → 更新和安全 → Windows 更新
   - 或访问 [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/)

### 问题 2: PowerShell 版本过低
**症状**: 提示 "PowerShell 5.1+ required"

**解决方案**:
1. Windows 10/11 应该内置 PowerShell 5.1+
2. 如果版本过低,更新 Windows 系统
3. 或下载安装 Windows Management Framework 5.1

### 问题 3: DNS Client 服务未运行
**症状**: 提示 "DNS Client service is not running"

**解决方案**:
```powershell
# 启动 DNS Client 服务
Start-Service Dnscache

# 设置为自动启动
Set-Service Dnscache -StartupType Automatic

# 验证状态
Get-Service Dnscache
```

### 问题 4: DnsClient 模块缺失
**症状**: 提示 "DnsClient PowerShell module not available"

**解决方案**:
1. 运行系统文件检查器:
   ```powershell
   sfc /scannow
   ```
2. 运行 DISM 修复:
   ```powershell
   DISM /Online /Cleanup-Image /RestoreHealth
   ```
3. 重启计算机后重试

### 问题 5: 组策略限制
**症状**: NRPT 测试失败,系统兼容但无法创建规则

**解决方案**:
1. 检查组策略设置:
   ```powershell
   gpresult /r
   ```
2. 查看 NRPT 相关策略:
   - 计算机配置 → 策略 → Windows 设置 → 名称解析策略
3. 如果在域环境中,联系域管理员
4. 本地组策略编辑器(非域环境):
   ```
   gpedit.msc
   ```

## 📈 版本兼容性矩阵

| 功能 | Win11 | Win10 1607+ | Win10 < 1607 | Win8.1 |
|------|-------|-------------|--------------|---------|
| NRPT 规则创建 | ✅ | ✅ | ❌ | ❌ |
| DNS 重定向 | ✅ | ✅ | ❌ | ❌ |
| 规则持久化 | ✅ | ✅ | ❌ | ❌ |
| 自动兼容性检查 | ✅ | ✅ | ✅ | ✅ |
| 调试模式 | ✅ | ✅ | ✅ | ✅ |
| 智能重试 | ✅ | ✅ | N/A | N/A |
| 版本检测 | ✅ | ✅ | ✅ | ✅ |

## 💡 最佳实践

### 推荐配置
1. **Windows 11**: 保持最新版本
2. **Windows 10**: 更新到最新的功能更新(21H2 或更高)
3. **PowerShell**: 使用内置的 PowerShell 5.1
4. **DNS Client**: 保持服务运行和自动启动

### 企业环境
- 在部署前使用调试模式验证兼容性
- 检查组策略是否有 NRPT 限制
- 在测试环境验证后再部署到生产环境
- 保存调试日志用于问题排查

### 家庭用户
- 首次使用建议用调试模式查看详细信息
- 定期运行 Test 命令验证规则状态
- 系统更新后重新测试确保正常工作

## 📚 技术细节

### NRPT 支持历史
- **Windows 8**: 首次引入 NRPT,功能有限
- **Windows 8.1**: 改进 NRPT,仍有限制
- **Windows 10 1507-1511**: NRPT 基本支持,但不稳定
- **Windows 10 1607+**: NRPT 成熟稳定,推荐使用
- **Windows 11**: NRPT 进一步优化,最佳体验

### PowerShell 模块依赖
```powershell
需要的模块:
- DnsClient (内置于 Windows 10 1607+)
- CimCmdlets (内置)

使用的 Cmdlet:
- Add-DnsClientNrptRule
- Remove-DnsClientNrptRule
- Get-DnsClientNrptRule
- Clear-DnsClientCache
- Resolve-DnsName
- Get-Service
- Get-CimInstance
```

## 🎓 总结

`TencentDNS_ever.ps1` 脚本通过以下优化确保在 Windows 10/11 上的最佳兼容性:

✅ **自动检测**: 智能识别系统版本和配置
✅ **详细诊断**: 提供清晰的错误信息和解决方案
✅ **智能重试**: 自动处理临时性错误
✅ **版本适配**: 针对不同版本优化执行策略
✅ **全面测试**: 完整的兼容性验证流程

无论你使用的是 Windows 10 还是 Windows 11,只要系统版本满足要求(Build 14393+),脚本都能稳定可靠地工作!
