# 「我晕」v1.1 安装与病毒安全自检报告

生成时间：2026-08-10 21:32
APK：`WoYun/我晕.apk`（311 KB，versionCode=2 / versionName=1.1）

---

## 1. 图标替换
- 已用桌面 `我晕.png`（2048×2048）生成标准密度图标：
  `mipmap-mdpi(48) / hdpi(72) / xhdpi(96) / xxhdpi(144) / xxxhdpi(192)` 各含 `ic_launcher.png` 与 `ic_launcher_round.png`。
- 已删除原自适应图标 XML（`mipmap/ic_launcher.xml`、`mipmap-anydpi-v26/ic_launcher.xml`）及无用 drawable。
- `aapt2 dump badging` 已确认五个密度图标均打入 APK。

## 2. 权限自检（安装时显示项）
当前声明权限共 6 个，**全部为 normal / special 级别，无任何 dangerous 权限**：

| 权限 | 级别 | 用途 | 安装时是否弹"危险权限"警告 |
|---|---|---|---|
| SYSTEM_ALERT_WINDOW | special | 悬浮圆点显示在其它应用之上 | 否（属"特殊应用权限"，安装界面不弹危险警告；在设置里可见） |
| FOREGROUND_SERVICE | normal | 两前台服务常驻 | 否 |
| FOREGROUND_SERVICE_SPECIAL_USE | normal | 视觉提示前台服务类型 | 否 |
| FOREGROUND_SERVICE_MEDIA_PLAYBACK | normal | 低频音前台服务类型 | 否 |
| POST_NOTIFICATIONS | runtime(13+) | 前台服务通知 | 否（首次发通知时弹一次授权，非危险） |
| WAKE_LOCK | normal | 息屏后保持音频输出 | 否 |

**危险权限扫描结果（通讯录/短信/电话/定位/相机/麦克风/存储/网络/无障碍）：0 命中 → 安装界面不会出现红色危险权限警告。**

### 关于"敏感权限能否避免显示"
- 唯一会被部分第三方安装器列为"特殊权限"的是 `SYSTEM_ALERT_WINDOW`（显示在其他应用上）。这是悬浮圆点的**核心能力**，无法在不删除该功能的条件下移除；且它不在安装时的"危险权限"清单里。
- 已顺手移除多余权限 `HIGH_SAMPLING_RATE_SENSORS`（传感器仅 ~50Hz，远低于 200Hz 阈值，原本就不需要），进一步缩短权限列表。
- 若你愿意接受"圆点只在 App 自身界面内显示、不覆盖其它应用"，可彻底去掉 `SYSTEM_ALERT_WINDOW`，实现安装时零特殊权限——但这会失去车载/边用手机边看提示的场景。默认保留。

## 3. 病毒 / 安全自检
| 检查项 | 结果 |
|---|---|
| 签名方案 | v1 + v2 + v3 全部启用；`apksigner verify` 退出码 0（通过） |
| 证书 | 自签名 RSA 2048 / SHA384withRSA；有效期 2026-08-10 ~ 2056-08-02（30 年，未过期） |
| 原生库 | 无 `.so`（纯 Java/Dex），不触发原生库类启发式 |
| 代码混淆 | 未启用（Dex 未混淆），不触发混淆类启发式 |
| 网络/外联 | 无 INTERNET 等权限；源码无 `java.net`/`HttpURLConnection`/`OkHttp` 等（0 命中） |
| 短信/电话/定位 | 无 `SmsManager`/`TelephonyManager`/定位权限（0 命中） |
| 无障碍/动态加载 | 无 `AccessibilityService`/`DexClassLoader`/`getRuntime().exec`/反射调用（0 命中） |
| zipalign | 4 字节对齐通过 |

**结论**：APK 结构干净，不含任何典型恶意行为（无外联、无隐私窃取、无隐藏执行、无动态代码）。安装与常规杀毒扫描预期**全绿**。

> 说明：本机未检测到可用的命令行杀毒扫描器（Windows Defender 平台目录不存在，疑似已被 360 安全卫士接管），未能在此自动跑杀毒程序。建议你用桌面的 **360 安全卫士** 或 Windows Defender 对该 APK 右键扫描一次；自签名应用可能显示"未知发布者"，属正常提示而非病毒。

## 4. 验证命令（可复现）
```
aapt2 dump permissions 我晕.apk            # 权限清单（应仅 6 项，无危险权限）
apksigner verify 我晕.apk                  # 退出码 0 = 签名通过
zipalign -c -p 4 我晕.apk                  # 对齐 OK
keytool -list -v -keystore keystore/woyun.jks -storepass woyun123 -alias woyun   # 证书有效期
```
