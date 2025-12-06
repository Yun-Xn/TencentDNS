# Tencent DNS 永久配置工具 - 快速使用指南

## 📋 基本命令

### 1️⃣ 安装 DNS 规则(永久生效)
```powershell
# 普通安装
.\TencentDNS_ever.ps1 -Action Install

# 带调试信息安装
.\TencentDNS_ever.ps1 -Action Install -DebugMode
```

### 2️⃣ 卸载 DNS 规则
```powershell
# 普通卸载
.\TencentDNS_ever.ps1 -Action Uninstall

# 带调试信息卸载
.\TencentDNS_ever.ps1 -Action Uninstall -DebugMode
```

### 3️⃣ 显示当前规则
```powershell
# 查看已安装的规则
.\TencentDNS_ever.ps1 -Action Show

# 查看规则并显示详细调试信息
.\TencentDNS_ever.ps1 -Action Show -DebugMode
```

### 4️⃣ 测试 DNS 解析
```powershell
# 测试规则是否正常工作
.\TencentDNS_ever.ps1 -Action Test

# 测试并显示详细调试信息
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

## 🔧 系统要求

### ✅ 完全支持的系统
- **Windows 11** (所有版本,Build 22000+)
  - ✓ 完整 NRPT 支持
  - ✓ 所有功能正常
  - ✓ 最佳性能

- **Windows 10** (版本 1607 及更高,Build 14393+)
  - ✓ 完整 NRPT 支持
  - ✓ 所有功能正常
  - ✓ 推荐更新到最新版本

- **Windows Server 2016+**
  - ✓ 完整 NRPT 支持
  - ✓ 所有功能正常

### ⚙️ 其他要求
- ✅ PowerShell 5.1 或更高版本
- ✅ 管理员权限(必须以管理员身份运行 PowerShell)
- ✅ DNS Client 服务必须运行(通常默认启用)

### ⚠️ 不支持的系统
- ✗ Windows 8.1 及更早版本(缺少 NRPT 支持)
- ✗ Windows 10 版本 1511 及更早(Build < 14393)
- ✗ Windows Server 2012 R2 及更早版本

### 🔍 自动兼容性检查
脚本会自动检查:
- Windows 版本和构建号
- PowerShell 版本
- DNS Client 服务状态
- DnsClient PowerShell 模块可用性

如果系统不兼容,脚本会显示详细的错误信息和解决方案。

## 🎯 主要特性

### ✨ 永久配置
- 规则一次配置,永久生效
- 系统重启后自动恢复
- 无需后台服务或监控进程

### 🖥️ Windows 10/11 完全兼容
- ✅ 自动检测 Windows 版本
- ✅ 针对不同版本优化
- ✅ 详细的兼容性诊断
- ✅ 智能重试机制
- ✅ Windows 11 全功能支持
- ✅ Windows 10 (1607+) 全功能支持

### 🌐 覆盖域名
自动配置以下 Tencent 域名使用 Tencent DNS:
- `qq.com`, `*.qq.com`
- `weixin.qq.com`, `*.weixin.qq.com`
- `tencent.com`, `*.tencent.com`
- `wegame.com`, `*.wegame.com`
- `wechat.com`, `*.wechat.com`
- 以及其他 Tencent 相关域名(共19个规则)

### 🔍 调试模式(新增)
使用 `-DebugMode` 参数可以查看:
- 详细的执行步骤
- 变量值和状态
- 网络连接测试
- DNS 解析过程
- 性能和时间统计
- 错误诊断信息

## 📊 使用示例

### 示例 1: 首次安装
```powershell
# 步骤 1: 以管理员身份打开 PowerShell
# 步骤 2: 切换到脚本目录
cd G:\

# 步骤 3: 安装规则(推荐首次使用调试模式)
.\TencentDNS_ever.ps1 -Action Install -DebugMode

# 步骤 4: 测试规则是否工作
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

### 示例 2: 日常使用
```powershell
# 查看当前规则状态
.\TencentDNS_ever.ps1 -Action Show

# 如果需要卸载
.\TencentDNS_ever.ps1 -Action Uninstall
```

### 示例 3: 问题排查
```powershell
# 当 DNS 解析有问题时,使用调试模式查看详细信息
.\TencentDNS_ever.ps1 -Action Test -DebugMode

# 检查规则状态
.\TencentDNS_ever.ps1 -Action Show -DebugMode
```

## 🐛 常见问题

### Q1: 提示 "需要管理员权限"
**A:** 右键点击 PowerShell,选择 "以管理员身份运行"

### Q2: 提示 "系统兼容性检查失败"
**A:** 检查脚本输出的详细错误信息:
- **Windows 版本过低**: 需要 Windows 10 1607+ (Build 14393+)
- **PowerShell 版本过低**: 需要 PowerShell 5.1+
- **DNS Client 服务未运行**: 运行 `Start-Service Dnscache`
- **DnsClient 模块缺失**: 可能是系统组件损坏,尝试运行 `sfc /scannow`

### Q3: 规则显示 "Disabled" 状态
**A:** 这是正常的,NRPT 规则在某些情况下会显示 Disabled,但仍然有效
使用 Test 命令验证:
```powershell
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

### Q4: Windows 10 和 Windows 11 有什么区别?
**A:** 两个系统都完全支持,脚本会自动检测并适配:
- **Windows 11**: Build 22000+,所有功能完整支持
- **Windows 10**: Build 14393+,所有功能完整支持
- 脚本会根据系统版本自动优化执行策略

### Q5: 我的 Windows 10 是旧版本怎么办?
**A:** 检查你的 Windows 10 版本:
```powershell
# 查看系统版本
[System.Environment]::OSVersion.Version
```
- **Build < 14393**: 需要升级到 1607 或更高版本
- **Build ≥ 14393**: 完全支持,可以正常使用

### Q6: DNS 服务器连接超时
**A:** 调试模式会测试 DNS 服务器连接,如果显示 TIMEOUT:
- 可能是网络问题
- 可能是防火墙阻止(端口 53)
- 规则仍然可以正常工作,因为 Windows 会自动处理

### Q7: 想要保存调试信息到文件
**A:** 使用输出重定向:
```powershell
.\TencentDNS_ever.ps1 -Action Install -DebugMode > install_log.txt 2>&1
```

### Q8: 想验证规则是否真的在工作
**A:** 使用 PowerShell 的 Resolve-DnsName 命令:
```powershell
# 测试 qq.com 的解析
Resolve-DnsName qq.com

# 或者使用脚本的 Test 功能
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

**注意:** 不要使用 `nslookup` 命令测试,因为它会绕过 NRPT 规则。

## 📌 重要提示

1. **管理员权限**: 必须以管理员身份运行 PowerShell
2. **执行策略**: 如果脚本无法运行,执行:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ```
3. **使用 Resolve-DnsName**: 验证 DNS 解析时使用 PowerShell 的 Resolve-DnsName,不要用 nslookup
4. **规则持久性**: 安装后无需其他操作,规则自动持久化
5. **调试模式**: 首次使用或遇到问题时建议使用 `-DebugMode` 参数

## 📝 完整流程示例

```powershell
# ========== 完整安装和验证流程 ==========

# 1. 以管理员身份运行 PowerShell

# 2. 导航到脚本目录
cd G:\

# 3. 查看当前规则(可选)
.\TencentDNS_ever.ps1 -Action Show

# 4. 安装 Tencent DNS 规则(首次建议用调试模式)
.\TencentDNS_ever.ps1 -Action Install -DebugMode

# 5. 验证规则是否工作
.\TencentDNS_ever.ps1 -Action Test -DebugMode

# 6. 查看最终规则状态
.\TencentDNS_ever.ps1 -Action Show

# ========== 完成! ==========
# 规则已永久配置,重启后自动生效
```

## 🔗 相关文件

- `TencentDNS_ever.ps1` - 主脚本文件
- `TencentDNS_Debug_说明.md` - 详细调试功能说明
- `README.md` - 本快速使用指南

## 💡 提示

- 🚀 首次使用建议用 `-DebugMode` 了解脚本工作原理
- 🔍 遇到问题时使用 `-DebugMode` 获取详细诊断信息
- ⚡ 日常使用时可以不加 `-DebugMode` 参数,执行更快
- 📊 调试模式会显示执行时间,帮助了解性能

## 🎉 享受使用!

如有问题或需要帮助,请查看 `TencentDNS_Debug_说明.md` 了解更多调试技巧。
