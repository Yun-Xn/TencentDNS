# Tencent DNS 永久配置工具 - 调试功能说明

## 概述
此脚本已增强,添加了全面的调试日志功能,可以提供详细的执行信息,帮助排查问题和监控脚本运行状态。

## 主要特性

### 1. 调试模式激活--powershell管理员窗口进入对应文件夹运行
使用 `-DebugMode` 参数启用详细的调试输出:

```powershell
# 标准运行(无调试信息)
.\TencentDNS_ever.ps1 -Action Install

# 带调试信息运行
.\TencentDNS_ever.ps1 -Action Install -DebugMode
```

### 2. 调试信息类别

调试系统提供以下类别的信息:

| 级别 | 颜色 | 用途 |
|------|------|------|
| **INIT** | Gray | 脚本初始化和主要操作启动 |
| **INFO** | Gray | 一般信息性消息 |
| **VAR** | Gray | 变量值和状态信息 |
| **STEP** | Cyan | 操作步骤和进度跟踪 |
| **ERROR** | Red | 错误信息和异常详情 |
| **NET** | Green/Red | 网络连接测试结果 |
| **SUMMARY** | Gray | 执行摘要和统计信息 |

### 3. 调试输出格式

每条调试消息包含:
- **时间戳**: 精确到毫秒的当前时间
- **执行时间**: 从脚本启动开始的相对时间(毫秒)
- **级别标签**: 消息类别
- **详细信息**: 具体的操作、变量或状态信息

示例输出:
```
[01:51:53.170 +16ms] [STEP] STEP: Checking administrator privileges
[01:51:53.224 +71ms] [VAR] IsAdministrator = True (Administrator privilege check result)
[01:51:53.315 +162ms] [NET] Network: 119.29.29.29:53 - CONNECTED
```

### 4. 提供的调试信息

#### 安装操作 (Install)
- 管理员权限检查
- DNS 服务器网络连接测试
- 旧规则清理过程
- NRPT 功能测试
- 每个域名的规则创建状态
- 规则创建总耗时
- 成功/失败统计

#### 卸载操作 (Uninstall)
- 现有规则查询
- 规则删除过程
- DNS 缓存清理
- 操作完成状态
- 卸载总耗时

#### 显示操作 (Show)
- 规则查询过程
- 找到的规则数量
- 规则状态(启用/禁用)
- 配置的 DNS 服务器

#### 测试操作 (Test)
- NRPT 规则检查
- DNS 解析测试(每个测试域名)
- NRPT 规则与直接 DNS 查询的 IP 对比
- DNS 缓存验证
- 解析测试总耗时
- 测试结果摘要

### 5. 执行摘要

脚本结束时提供完整的执行摘要:
- 总执行时间
- 生成的调试日志条目数量
- 系统版本信息
- PowerShell 版本
- 当前用户信息

## 使用场景

### 场景 1: 安装问题排查
当安装过程出现问题时,使用调试模式查看详细信息:

```powershell
.\TencentDNS_ever.ps1 -Action Install -DebugMode
```

调试输出将显示:
- 哪些 DNS 服务器可以连接
- NRPT 功能是否可用
- 哪些域名规则创建成功/失败
- 具体的错误消息和异常详情

### 场景 2: 网络连接诊断
检查 Tencent DNS 服务器的可达性:

```powershell
.\TencentDNS_ever.ps1 -Action Show -DebugMode
```

查看 NET 级别的消息:
- `CONNECTED`: DNS 服务器可达
- `TIMEOUT`: DNS 服务器无响应(2秒超时)
- `ERROR`: 连接失败

### 场景 3: DNS 解析验证
验证 NRPT 规则是否正确工作:

```powershell
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```

调试输出将显示:
- 每个域名的解析结果
- NRPT 解析与直接 DNS 查询的 IP 对比
- IP 匹配状态(PASS/WARN/FAIL)
- DNS 缓存中的条目

### 场景 4: 性能分析
使用调试模式监控操作耗时:

```powershell
.\TencentDNS_ever.ps1 -Action Install -DebugMode
```

查看时间相关的调试信息:
- 每个操作步骤的时间戳
- 规则创建总耗时
- 整体执行时间

## 调试信息解读

### 网络连接测试
```
[01:51:53.315 +162ms] [NET] Network: 119.29.29.29:53 - CONNECTED
[01:51:55.320 +2166ms] [NET] Network: 182.254.116.116:53 - TIMEOUT
```
- **CONNECTED**: 第一个 DNS 服务器(119.29.29.29)可以正常连接
- **TIMEOUT**: 第二个 DNS 服务器(182.254.116.116)连接超时,可能网络不通或防火墙阻止

### 变量跟踪
```
[01:51:53.236 +82ms] [VAR] TencentDNS = Array[2]: 119.29.29.29, 182.254.116.116 (DNS server configuration)
[01:51:55.716 +2563ms] [VAR] rules.Count = 19 (Number of NRPT rules found)
```
- 显示当前变量的值和类型
- 数组会显示元素数量和内容
- 包含变量含义的描述

### 步骤跟踪
```
[01:51:55.721 +2567ms] [STEP] STEP: Clearing DNS cache before testing
[01:51:55.822 +2668ms] [STEP] DNS cache cleared successfully
```
- 显示当前执行的操作
- 操作完成状态
- 可以用于跟踪脚本执行流程

### 错误详情
如果发生错误,调试模式会显示:
```
[时间戳] [ERROR] ERROR: 错误描述
[时间戳] [ERROR] Exception Type: 异常类型
[时间戳] [ERROR] Exception Message: 异常消息
[时间戳] [ERROR] Stack Trace: 堆栈跟踪
```

## 注意事项

1. **性能影响**: 调试模式会略微增加执行时间(通常 < 100ms),但对于诊断问题非常有用

2. **输出量**: 调试模式会产生大量输出,建议:
   - 在需要排查问题时使用
   - 正常使用时不添加 `-DebugMode` 参数

3. **日志记录**: 调试信息仅在控制台显示,不会自动保存到文件
   - 如需保存,可以重定向输出:
   ```powershell
   .\TencentDNS_ever.ps1 -Action Install -DebugMode > debug.log 2>&1
   ```

4. **不交互模式**: 即使在调试模式下,脚本也不会要求额外的用户输入
   - 所有调试信息自动输出
   - 不影响自动化使用场景

## 常见问题诊断

### 问题: 规则安装失败
**解决方法**: 使用调试模式查看详细错误
```powershell
.\TencentDNS_ever.ps1 -Action Install -DebugMode
```
查看:
- 管理员权限检查结果
- NRPT 功能测试结果
- 具体哪些域名规则创建失败
- 错误异常详情

### 问题: DNS 解析不工作
**解决方法**: 运行测试并查看调试信息
```powershell
.\TencentDNS_ever.ps1 -Action Test -DebugMode
```
检查:
- 规则是否存在且启用
- DNS 服务器连接状态
- 解析结果与直接查询是否匹配
- DNS 缓存中是否有相关条目

### 问题: DNS 服务器无法连接
**解决方法**: 查看网络连接测试结果
```powershell
.\TencentDNS_ever.ps1 -Action Show -DebugMode
```
检查 NET 级别消息:
- TIMEOUT: 可能是防火墙或网络问题
- ERROR: 可能是服务器地址错误或网络断开

## 总结

调试模式为 Tencent DNS 永久配置工具提供了强大的诊断能力:
- ✅ 无需交互即可获取详细信息
- ✅ 分类清晰的调试输出
- ✅ 精确的时间和性能测量
- ✅ 完整的变量和状态跟踪
- ✅ 网络连接实时测试
- ✅ 详细的错误诊断信息

建议在首次安装、排查问题或验证配置时使用 `-DebugMode` 参数。
