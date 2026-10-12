> Current status: Firebase email/password is connected on the Spark plan. Earlier service-unavailable notes below describe the previous implementation. See [current integration](../firebase/README.md).

# Pixso 账号流程原生实现

设计来源：Pixso 文件 `Cvv6xQS2eeP0vnHU4qCbww`，登录 `2:7`、注册 `2:39`、找回密码 `2:77`、首次启动隐私 `2:104`。通过 MCP design_to_code 获取设计，再逐页获取截图。导出的 HTML、字体和图片保存在 `../../../design/pixso-auth/`，仅作设计参考，不作为 WebView 页面打包。

## 实现

- `AuthViewController`：UIKit 原生输入框、按钮、滚动和键盘处理；注册校验、密码可见性、找回密码和页面返回。
- `AuthStyle`：Pixso 配色、思源黑体、本地内容插画、顶部和底部 CAGradientLayer 融合、原生矢量盾牌。
- `AuthPrivacyController`：首次启动协议弹层；只有明确同意才写入本地状态；拒绝后仍停留在登录页。
- `AuthLegalController`：可阅读的本地预览版使用及隐私说明；不冒充尚未制定的正式线上条款。
- `AppCoordinator`：A01/A02 路由及设置 → 账号 → 邮箱登录入口，首次启动自动展示；未认证时不加载主界面。
- `EditorialAssets` 中仅添加四张经检查的内容插画，表单、品牌、导航、按钮、渐变和弹层均为 UIKit。
- 支持应用原有中英文偏好。默认显示原有语言设置；`--auth-chinese` 仅用于审阅时切换。

## 验证范围

账号服务尚未配置。登录、注册、重置操作只校验表单并明确报告服务未连接，不保存密码、不发送邮件，也不伪造成功。

iOS 26.1 模拟器的 Automatic Strong Password 系统浮层在自动化输入时只接收首字母。UI 回归使用页面的显示密码入口填写，再验证切回密文仍保留内容。生产实现保留正确的 `.newPassword` / `.password` 语义及密码规则；自动强密码填充需要真机补验。

注册协议区将勾选与可点击的两份协议链接分开，便于独立操作。标准交互增加 44pt 点击区域，因此它与静态稿的垂直排版存在小幅差异。真实系统状态栏、灵动岛和 Home 指示条由 iOS 提供；不同设备不会与画板的模拟系统栏完全一致。

## 审阅入口

```sh
xcrun simctl launch --terminate-running-process booted studio.maderoom.ios --uitesting --screen A01 --auth-preview login --auth-chinese
```

将 `login` 换成 `register`、`reset` 或 `privacy` 可直接审阅另三个页面。`--auth-preview` 是设计检查参数，不代表远程认证成功。

测试命令：

```sh
xcodebuild -workspace MadeRoom.xcworkspace -scheme MadeRoom -destination 'platform=iOS Simulator,id=CD567493-645A-46D1-8E80-C4A17441AEAC' -derivedDataPath build -only-testing:MadeRoomUITests/AuthFlowUITests -only-testing:MadeRoomTests CODE_SIGNING_ALLOWED=NO test
```

## 本次结果

- MadeRoom.xcworkspace 编译通过。
- 26 项单元测试、3 项账号流程 UI 测试通过（`Test-MadeRoom-2026.10.08_23-09-31-+0800.xcresult`）。
- 检查 iPhone 17 Pro / iOS 26.1 的四张运行截图；未发现表单、文字或弹层遮挡。
- [四页实际截图](index.html)：[登录](login.png)、[注册](register.png)、[找回密码](reset.png)、[隐私弹层](privacy.png)。
- iOS 模拟器生成强密码的系统浮层限制、协议区布局差异和未连接服务的边界见上文。尚未完成真机自动填充测试。

## 英文展示

当前模拟器语言偏好已切换并保存为英文。使用 `--auth-english` 可明确切换到英文；不传语言参数时继续使用已保存的偏好。已重新编译并检查四页英文截图，未发现文字截断或控件重叠。插画内的装饰画中文字属于原始素材，不随界面语言切换。

## 文字裁切与协议勾选修正

文字按字体实际行高测量并增加上下留白，按钮增加垂直内边距。注册协议使用空心方框、绿色实心勾选和浅绿色选中背景，整行可点击，协议链接独立。已检查英文四页截图与中文勾选截图。注册开关、按钮启用及服务提示回归通过（1 项 UI 测试，`Test-MadeRoom-2026.10.08_23-43-41-+0800.xcresult`）。

## 强制登录入口

启动根控制器为登录导航，主界面不再提前加载。首次同意隐私协议仅保存同意状态，不等于登录。拒绝协议、注册或重置返回、重启，以及 `--screen` 指向主界面均不会绕过登录。账号服务尚未配置，当前不会生成伪造会话或放行主界面；后续需接入真实认证服务才能完成登录后的跳转。原先依赖未登录直达主界面的 UI 测试需要在接入认证后改为经过登录流程。
