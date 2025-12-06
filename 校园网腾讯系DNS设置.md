win11可用
win+x进入终端管理员
cd 进入对应文件夹（路径最好不要中文）![[TencentDNS_ever.ps1]]
```
.\TencentDNS_ever.ps1 -Action Install    # Install", "Uninstall", "Show", "Test"四选一功能如其名
```
![[Pasted image 20251206011151.png]]

## 遇到未包含的腾讯系软件在这里添加子域名和父域名
![[Pasted image 20251206011631.png]]
## 进阶
1. 修改dns
```
$TencentDNS = @("119.29.29.29", "182.254.116.116")  # 修改为对应DNS如百度系180.76.76.76和114.114.114.114  注：最好修改变量名
```
2. 修改域名
``` 
# 修改为对应系域名
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
```
3. 修改DNS名
```
$RuleComment = "Tencent DNS Permanent Rule"    # 必须修改
```
4. 修改测试域名
```
 $testDomains = @("qq.com", "v.qq.com", "weixin.qq.com")  # 如果需要测试的话
```
5. （可选）修改头部信息和变量名