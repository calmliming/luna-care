# LunaCare

记录女朋友的生理期，推算下一次什么时候来。Flutter 编写，界面为中文，数据只保存在手机本地。

安卓安装包在 [Releases](https://github.com/calmliming/luna-care/releases) 页面，一般手机下载 `app-arm64-v8a-release.apk`。

## 功能

- **今天**：月相周期图（每颗珠子代表周期中的一天，月亮随周期盈亏：经期是新月，排卵前后接近满月）；显示“还有几天来月经”、经期第几天或已推迟几天，以及当前阶段的照顾建议。一键记录“她今天来月经了”“月经今天结束了”，都可以撤销。
- **日历**：按月查看经期、预测经期、排卵期和排卵日，左右滑动切换月份；点某一天可以补记或修改；底部列出接下来三次月经。
- **记录**：时间线展示每次月经的日期、天数和相邻两次的间隔，间隔异常（可能漏记）会提示。
- **提醒**（安卓）：在设置里打开后，预计经期开始前几天（默认 2 天）和预计当天各发一条通知，提醒时间可以改（默认 9:00）；可以先发一条测试通知，看手机能不能收到。
- **设置**：她的称呼、经期提醒、默认周期和经期天数、剪贴板备份与恢复、清空记录。
- 跟随系统的浅色和深色主题。

## 推算规则

规则集中在 [lib/src/logic/cycle_forecast.dart](lib/src/logic/cycle_forecast.dart)：

| 项目 | 规则 |
| --- | --- |
| 平均周期 | 最近 6 个周期的平均值。两次开始日相隔 15 到 60 天才算一个周期，超出范围视为漏记；有 3 个以上样本时，偏离中位数超过 10 天的会被忽略 |
| 平均经期 | 最近 6 次记录了结束日期的经期的平均天数 |
| 数据不足时 | 使用设置里的默认值（28 天周期、5 天经期） |
| 下次月经 | 最近一次开始日加上平均周期；过了预计日期还没来，就显示推迟天数，预测从今天起算 |
| 排卵日 | 下次月经前 14 天 |
| 排卵期 | 排卵日前 5 天到后 4 天 |
| 提醒 | 只安排下一次月经的两条提醒，记下这次月经后自动排下一次；推迟了或很久没记录时暂停，补上记录后恢复 |

预测仅供参考，不能用于避孕。

## 提醒

提醒交给系统的闹钟服务，应用不用开着，手机重启或应用更新后会自动重新安排。提醒用精确闹钟准时送达，这项权限安装时系统就默认允许，不会额外弹窗；万一系统不允许，会改用普通闹钟，最多可能晚一小时。

部分手机（小米、华为、OPPO、vivo 等）会拦下被清理出后台的应用的定时通知。如果测试通知能收到、到点的提醒却没来，在系统设置里给 LunaCare 打开“自启动”（或“允许后台活动”），并把电池优化设为“不限制”。

## 运行

需要 Flutter 3.47 或更高版本（Dart 3.13）。

```bash
flutter pub get
flutter run              # 连接安卓手机或模拟器
flutter run -d chrome    # 没有安卓环境时，可以先在浏览器里预览
flutter test
```

在安卓手机上运行或打包 APK 需要 JDK 17 以上和 Android SDK（装 Android Studio 会一并装好，也可以只装命令行工具）。第一次先运行 `flutter doctor --android-licenses` 接受许可，然后：

```bash
flutter build apk --split-per-abi   # 在 build/app/outputs/flutter-apk/ 下按 CPU 架构各生成一个安装包
```

release 包用正式密钥签名，密钥库的位置和密码写在 `android/key.properties` 里（不进 git）。维护者这台电脑上，密钥库、这份文件和使用说明都放在 `D:\SDK\keys\luna-care\`，需要整体备份。

```properties
storeFile=D:/SDK/keys/luna-care/luna-care-release.jks
storePassword=…
keyAlias=luna-care
keyPassword=…
```

没有这个文件时会改用调试密钥，照样能打包，但签名不同的包不能互相覆盖安装，只能先卸载，而卸载会删掉记录。所以给手机装的包要一直用同一个密钥，换包前先在设置里复制备份。密钥库和密码丢了就再也发不了能覆盖安装的更新，务必另外备份一份。

## 应用图标

图标是轨道上的一弯新月和一颗胭脂色圆点，由 [tool/make_icon.py](tool/make_icon.py) 绘制，再用 flutter_launcher_icons 生成安卓（含自适应图标和 Android 13 主题图标）、iOS 和网页的各个尺寸。修改后重新生成：

```bash
uv run tool/make_icon.py          # 重画 assets/icon/ 下的源图
dart run flutter_launcher_icons   # 按 flutter_launcher_icons.yaml 生成各平台图标
```

## 目录结构

```text
lib/
  main.dart                 入口：打开本地存储并启动应用
  src/
    app.dart                MaterialApp、主题、中文本地化
    theme.dart              中国传统色（月白、黛、胭脂、天水碧、藤黄）和数字字体
    logic/cycle_forecast.dart  周期推算（纯 Dart，无界面依赖）
    logic/reminder_plan.dart   提醒的时间和文案（纯 Dart）
    models/                 经期记录、设置和提醒设置
    data/                   shared_preferences 存储、备份格式和安卓通知
    state/                  CycleStore、Reminders（ChangeNotifier）及对应的 Scope
    ui/                     今天、日历、记录、设置页面，以及月相周期图
assets/fonts/               Cormorant Garamond，只截取了数字所需字符（SIL OFL 许可）
assets/icon/                应用图标源图（不打包进应用）
tool/make_icon.py           绘制图标源图的脚本
test/                       推算逻辑、提醒、存储、界面流程和大字体测试
```
