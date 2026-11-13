# OpenEUICC Magisk 模块（安卓 16 闪退修复）

[![Build Magisk module](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml/badge.svg)](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml)

本仓库把 [PeterCxy 的 OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC)（Android 上的开源
eSIM LPA 实现）打包成 Magisk / KernelSU / APatch 模块，并修复了安卓 16 上"一打开就闪退"的问题。

它来自 [hzy132/OpenEUICC_for_Magisk](https://github.com/hzy132/OpenEUICC_for_Magisk)，内置的上游源码
固定在提交 `9a537a25163c5159899260fb6191a5da35a692bd`（也就是发布 `3(802)` 时使用的那个提交），
只做了少量针对性修改。

* **OpenEUICC**（`im.angry.openeuicc`）——特权版，作为系统应用**同时**安装在
  `/system/priv-app/OpenEUICC/` 与 `/system_ext/priv-app/OpenEUICC/`。KernelSU 的各种挂载
  实现覆盖的分区不同，两份都放可以提高成功率；两份同时可见时包管理器以 `/system` 那份为准，
  另一份会被忽略，不会冲突。
* **EasyEUICC**（`im.angry.easyeuicc`）——非特权版，普通用户应用，作为独立 APK 附带在 release 里。

## 闪退的原因

### 现象

点开应用立刻退出，日志大致是：

```
FATAL EXCEPTION: main
Process: im.angry.openeuicc, PID: ...
java.lang.RuntimeException: Unable to create application im.angry.openeuicc.PrivilegedOpenEuiccApplication
    at android.app.ActivityThread.handleBindApplication(ActivityThread.java:...)
Caused by: java.lang.SecurityException: Caller does not have permission.
    at android.os.Parcel.createExceptionOrNull(Parcel.java:...)
    at android.os.Parcel.readException(Parcel.java:...)
```

### 根因

OpenEUICC 是**特权应用**，它会调用 `TelephonyManager.uiccCardsInfo`，这需要
`READ_PRIVILEGED_PHONE_STATE` 签名权限。只有"以系统应用身份安装 + 出现在 privapp 权限白名单里"
才能拿到这个权限。

在安卓 16（以及新版 KernelSU / Magisk 的某些挂载模式）下，模块经常在包管理器扫描时还没有
被挂载，特权 APK 根本不可见（旧版本放在 `/system_ext`，很多 KernelSU 挂载实现压根不覆盖这个
分区，所以现在改放 `/system/priv-app`）；与此同时，旧版模块安装时还会执行
`pm install`，又往 `/data/app` 装了一份**同包名的非特权副本**。这份副本会盖住系统应用，
于是应用以普通用户身份启动，而 `PrivilegedOpenEuiccApplication.onCreate()` 里没有做任何保护的
`uiccCardsInfo` 调用直接抛出 `SecurityException`，进程在第一个界面出现前就被杀掉。

### 本仓库做的修改

| 位置 | 修改 |
| --- | --- |
| `openeuicc/app/src/main/java/im/angry/openeuicc/util/PrivilegedTelephonyCompat.kt` | `uiccCardsInfoCompat` 捕获 `SecurityException`，返回空列表，不再抛出。 |
| `openeuicc/app/src/main/java/im/angry/openeuicc/PrivilegedOpenEuiccApplication.kt` | 非特权启动时跳过特权清理逻辑，并且不让异常逃出 `onCreate()`。 |
| `openeuicc/app/src/main/java/im/angry/openeuicc/ui/PrivilegedMainActivity.kt` | 没有 `READ_PRIVILEGED_PHONE_STATE` 时弹出说明对话框（重启、修好模块挂载），而不是崩溃。 |
| `magisk-module/customize.sh` | 不再执行 `pm install`（它正是非特权"影子副本"的来源）；APK 改放 `/system/priv-app`；顺带清掉旧版本留下的 `/data/app` 副本。 |
| `magisk-module/service.sh` | 开机后自愈：发现系统 APK 已挂载但当前运行的仍是 `/data/app` 副本时，自动卸载该副本让系统应用生效；随后授予 `READ_PHONE_STATE` / `POST_NOTIFICATIONS`，并写开机日志 `/data/local/tmp/openeuicc-boot.log`。 |
| `magisk-module/system/system_ext/etc/default-permissions/openeuicc.xml` | 首次开机自动授予运行时权限，作为第二重保险。 |
| `openeuicc/app-common/.../core/EuiccDiagnostics.kt` 等 | 记录卡/端口/权限/通道打开失败原因，并在主菜单与"未检测到 eUICC"页面提供诊断对话框。 |
| `openeuicc/buildSrc/.../Versioning.kt` + `build.sh` | 显式指定递增的 `versionCode`（内置源码没有上游 git 历史，算出来的版本号会远小于已发布的 `802`，反而会让系统继续保留旧的 `/data/app` 版本）。 |

除此之外应用本身没有改动，这不是重写。

**注意**：如果模块确实没有挂载成功，应用仍然无法工作——非特权应用本来就没有 eUICC 访问权限。
这个补丁只是把"崩溃"变成"明确的错误提示"，并消除了模块这边的诱因。

## 安装

1. 从 [最新 release](https://github.com/ban-sky/OpenEUICC_for_Magisk/releases/latest) 下载
   `OpenEUICC-Magisk_module.zip`。
2. 在 Magisk / KernelSU (Next) / APatch 中刷入。
3. 重启。
4. 打开 OpenEUICC。

如果应用提示"不是特权应用"，说明模块没有被挂载。用 root shell 检查：

```sh
ls -l /system/priv-app/OpenEUICC/OpenEUICC.apk
cat /data/local/tmp/openeuicc-boot.log
```

文件不存在的话，换一种挂载方式（KernelSU Next 可以试不同的挂载模式，或者刷 `mountify` 模块），
然后重启。部分机型上"重新刷一遍模块 + 重启两次"也有效。

### 模块没挂载时会怎样

模块绝不会让手机上没有应用：

* 开机时 `post-fs-data.sh` 先把挂载状态写进 `/data/local/tmp/openeuicc-mount.log`；
* 开机完成后 `service.sh` 做决定：
  * 系统 APK 可见 → 删掉遗留的 `/data/app` 副本，让特权系统应用生效（必要时 `pm install-existing`）；
  * 系统 APK 不可见（模块没挂载）→ 自动把同一个 APK 作为普通应用安装，至少能打开并在弹窗里说明
    原因，而不是「装完模块应用不见了」；
  * 之后挂载修好，下一次开机会自动把普通应用副本清掉、切回系统应用。

### KernelSU 注意事项

* 本模块把 APK 放在 `/system/priv-app`，这是所有 KernelSU 挂载实现（overlayfs、magic mount、
  mountify、meta-overlayfs）都会覆盖的分区；`/system_ext` 在部分实现里不会被挂载。
* KernelSU 管理器里不要把 OpenEUICC 加入"卸载模块"（umount）名单，否则该应用的挂载会被隐藏，
  应用就会退回普通应用身份。
* 从旧模块（hzy132 的版本，或本模块 3.806/3.809）升级时，旧版 `pm install` 会在 `/data/app`
  留一份副本。新版 `customize.sh` 会尽量删除它，删不掉时 `service.sh` 会在开机后重试——
  升级后请重启一次，再打开应用。
* 开机日志 `/data/local/tmp/openeuicc-boot.log` 里会记录：模块目录、系统 APK 是否为
  `present`、`pm path` 指向哪里、自愈是否执行。诊断信息里也有对应的 `APK path`、
  `System flags`、`File /system/priv-app/...` 等行。

## 看不到 eSIM / 无法查看 eSIM 信息

如果模块刷入后应用能打开、但主界面显示"未检测到 eUICC"，请先用应用内的**诊断信息**：

* 主界面右上角菜单 → **诊断信息**；或
* "未检测到 eUICC" 页面的 **显示诊断信息** 按钮。

对话框里会列出系统报告的每张 UICC 卡、每个端口（是否 eUICC、是否可移除、是否支持 MEP）、
每个权限的授予状态、应用实际运行的 APK 路径与系统标志、`/system/priv-app` 与 `/system_ext`
下 APK 是否存在，以及打开逻辑通道失败的具体异常。点 **复制** 就能把整段内容贴到 issue 里。

根据这些信息，常见原因分三类：

1. **模块没有挂载成功**（诊断里显示"以系统应用安装: false"，或
   `READ_PRIVILEGED_PHONE_STATE: denied`）：见上一节的挂载排查。
2. **eSIM 在系统设置里被关闭**：安卓在 eSIM 被停用之后会把它从 `UiccCardsInfo` 里拿掉，
   第三方应用就完全看不到这张卡。此时进 设置 → 网络和互联网 → SIM 卡 重新启用 eSIM，
   然后重启手机（上游 issue #346 就是这个现象）。
3. **槽位映射 / 基带限制**：部分机型（尤其是支持 MEP 的新机）只允许基带访问某个物理端口，
   打开逻辑通道会返回 `NO_SUCH_ELEMENT`。可以先在 设置 → 开发者选项 里打开
   **在所有地方使用 TelephonyManager**（应用自己的开发者选项里也有同名开关），再重新打开应用；
   诊断信息里会如实记录这类失败。

如果诊断信息里出现 `SecurityException: The calling package is not allowed to access ISD-R`，
说明系统把另一个 LPA（例如厂商自带的 eUICC 服务）当成了"最优 eUICC 服务"，因此拒绝本应用访问
ISD-R。这种情况请把诊断信息贴到 issue，并说明机型和系统版本。

## 构建

构建全部在 GitHub Actions 里完成：[`.github/workflows/build.yml`](.github/workflows/build.yml)
会安装 JDK 17、Android SDK（`platforms;android-37.0`、`build-tools;37.0.0`、
`ndk;26.1.10909125`），编译两个 APK 并打包模块。

在 *Actions → Build Magisk module → Run workflow* 手动触发，可填版本名和版本号
（留空则用 `802 + 提交数`）；默认会创建 `v<版本>` 的 release，取消勾选 `create_release` 则只出
artifact。推送到 `main` 也会自动构建并发布。

本地构建（需要同样的 JDK / SDK / NDK）：

```sh
# 需要 openeuicc/keystore.properties，内容指向一个 keystore：
#   storeFile=/绝对路径/keystore.p12
#   storePassword=...
#   keyAlias=...
#   keyPassword=...
#   unprivKeyAlias=...        （EasyEUICC）
#   unprivKeyPassword=...
OPENEUICC_VERSION_NAME=3 OPENEUICC_VERSION_CODE=803 ./build.sh
```

产物在 `out/`：

* `OpenEUICC-Magisk_module-<版本>.zip` —— 带版本号的模块（文件名里的版本形如 `3.806`，
  `module.prop` 里显示为同一构建的 `3(806)`）
* `OpenEUICC-Magisk_module.zip` —— 同一文件的固定名字，供 `update.json` 使用
* `EasyEUICC-<版本>.apk` —— 非特权版本
* `update.json` —— Magisk 更新信息

### 签名说明

首次构建时 workflow 用 `keytool` 生成签名密钥，之后从 Actions 缓存（`openeuicc-signing-v1`）
恢复，所以连续构建的签名一致，可以直接覆盖安装。如果缓存被清掉，签名会变化，需要先卸载旧版
（或清数据）再装。

想永久固定签名，可以添加仓库 Secret `KEYSTORE_BASE64`，内容是一个 PKCS#12 keystore 的 base64，
密钥口令为 `openeuicc-module-2026`、别名为 `openeuicc`（对应 workflow 里的
`KEYSTORE_PASSWORD` / `KEYSTORE_ALIAS`）。本仓库不包含任何私钥。

## 致谢

* [PeterCxy/OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) —— 应用本体（GPL-3.0）。
* [hzy132/OpenEUICC_for_Magisk](https://github.com/hzy132/OpenEUICC_for_Magisk) —— 本仓库的起点。
* [liuran001/OpenEUICC_Magisk_Module](https://github.com/liuran001/OpenEUICC_Magisk_Module)、
  [EmilienCourt/kernelsu-module-openeuicc](https://github.com/EmilienCourt/kernelsu-module-openeuicc)
  —— 帮助定位"挂载 / 权限"根因的其它模块打包方式。

GPL-3.0 授权，见 [LICENSE](LICENSE)。
