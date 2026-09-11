# CapCrack

iOS 侧"字典跑包"控制台 Demo工程：本地字典导入管理 + Cap/PCAP 文件解析 + SwiftUI 实时监控仪表盘,
由 GitHub Actions(macOS 26 / Xcode 26)自动编译产出 IPA 构件。

> 安全声明:本项目仅用于**授权的安全学习与测试**。对未授权网络的破解属违法行为,请勿用于非法用途。

## 工程结构

```
ccc/
├── .github/workflows/build.yml   # CI: Build & Package iOS IPA
├── project.yml                   # XcodeGen 规格, 生成 Xcode 工程
├── CapCrack/
│   ├── CapCrackApp.swift         # App 入口
│   ├── DictionaryManager.swift   # 多格式(TXT/ZIP/RAR)字典沙盒导入
│   ├── CapParser.swift           # .cap/.pcap 头与握手特征解析
│   ├── CrackEngine.swift         # 跑字典调度引擎 + 状态模型
│   └── CrackDashboardView.swift  # SwiftUI 仪表盘(进度/速度/剩余/倒计时)
└── README.md
```

## 构建方式

方案A(默认,推送自动构建)：

1. push 到 `main` 分支,或在 Actions 页手动 `Run workflow`。
2. 工作流在 `macos-latest`(macOS 26)上安装 XcodeGen → 生成工程 → `xcodebuild` Release 编译。
3. 产物 `CapCrack-unsigned.ipa` 上传为 Actions Artifact(未签名,仅供取证/静态分析,Jailbreak 设备可装)。

方案B(产出可直接安装到 iPhone 的真机版)：

1. 仓库 Settings → Secrets 与 variables → Actions,新增 `DEVELOPMENT_TEAM`(Apple Team ID)。
2. 将 `.github/workflows/build.yml` 中 Build 步骤改为自动签名:

```yaml
- name: Build App (Release, signed)
  run: |
    xcodebuild -project CapCrack.xcodeproj \
               -scheme CapCrack \
               -sdk iphoneos \
               -configuration Release \
               -destination 'generic/platform=iOS' \
               -derivedDataPath build/derived \
               -allowProvisioningUpdates \
               DEVELOPMENT_TEAM=${{ secrets.DEVELOPMENT_TEAM }} \
               build
```

3. 用 `xcodebuild -exportArchive -archivePath ... -exportOptionsPlist ExportOptions.plist -exportPath build/IPA`
   导出签名 IPA。仓库内已附 `ExportOptions.plist`(ad-hoc)。

> 说明:免费 Apple ID 的个人 Team 无法在 CI 中完成自动签名(需在 Xcode 手工登录账户),
> 免费方案建议本地命令行 `xcodebuild` 用 `CODE_SIGNING_ALLOWED=NO` 出包并在真机说明中按需重签。

## 握手验证说明

`CrackEngine` 负责逐行读取字典并推进进度,但真正的 **WPA/WPA2 握手验证(PMK/PTK 推导比对)**
需要密码学库(PBKDF2-SHA1 等)。当前 `CrackEngine.progressOneStep(verify:)` 的 `verify`
钩子为空实现,仅作调度演示。接入真实校验后即可用于授权的 hashcat/aircrack 同原理学习。

## 导入能力

- **TXT**：直接导入并装载,自动兼容 UTF-8 / UTF-16 / GB18030(GBK 超集)编码。
- **ZIP**：导入后自动解压到沙盒,并回收其中的 TXT 字典(依赖 SPM 库 `marmelroy/Zip`)。密码保护的 zip 暂不支持。
- **RAR**：会导入沙盒,但真正解压需集成 `UnrarKit`(闭源,未内置)。
- **CAP/PCAP**：校验 PCAP/PCAPNG 魔数与链路类型(105=IEEE 802.11),失败会给出具体原因。
- 导入统一走 `fileImporter` 全类型(`.item`) + `security-scoped` 访问,避免自定义扩展名选不了/读不到的问题。

## 本地调试

```bash
# 生成工程(XcodeGen 已装时)
xcodegen generate
open CapCrack.xcodeproj
```