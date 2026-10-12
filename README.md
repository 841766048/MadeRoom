# Made Room · iOS

Swift + UIKit 应用，最低支持 iOS 17，第三方依赖通过 CocoaPods 管理。

## 获取并运行

```sh
git clone https://github.com/841766048/MadeRoom.git
cd MadeRoom
pod install
open MadeRoom.xcworkspace
```

选择 MadeRoom scheme 和已安装的 iPhone 模拟器运行。真机运行需要在 Xcode 配置自己的签名团队。工程由 `project.yml` 管理；修改配置后执行 `xcodegen generate`，再执行 `pod install`。

## 当前功能（2026-10-12）

- 原生发现、制作、空间、社区和个人主页；作品与空间缩略图。
- 邮箱账号、云端内容加载、社区发布与评论、点赞、关注、圈子及站内通知。
- 个人资料、作品库、收藏和偏好同步；网络失败状态与重试。
- 协议通过 WKWebView 展示，键盘管理使用 IQKeyboardManagerSwift。
- 已配置女性侧脸正式 App Icon。系统 APNs 推送尚未配置。

## 项目文件

- `MadeRoom/`：应用源码与必要资源。
- `Tests/`、`UITests/`：单元测试与 UI 测试。
- `content/`：内容发布工具和测试使用的源数据，应用内容通过网络加载。
- `tools/`：内容发布、资源处理与规则测试工具。
- `firestore.rules`、`firestore.indexes.json`、`firebase.json`：后端规则及部署配置。
- `docs/`：设计和验证记录；历史记录仅代表当时状态。
- `legacy-screenshot-renderer/`：历史实现归档，不参与当前 App 编译。

仓库保留客户端服务配置，管理端发布需要开发者自行登录服务 CLI。私钥、登录令牌、Pods、构建产物、缓存和本机日志不提交。首次运行需要联网安装依赖，在线功能需要对应服务可用。

---

## 历史实现记录

以下内容保留作为历史记录；其中“服务未连接”等说明已由上面的当前功能说明取代。

# Made Room · Swift + UIKit 原生重做版

2026-09-28，根据用户指出“很多界面仍是截图且截图不对”的问题，**撤换上一版 OCR 坐标回放、背景描摹和 UI 裁片实现**。旧代码仅归档于 `legacy-screenshot-renderer/`，不参与编译、不打包进 App。

## 当前实现方式

- Swift + UIKit，Auto Layout + UIStackView，真实 UIButton、UILabel、UITextField、UITextView、UISwitch、UISegmentedControl、UIProgressView。
- 56 个稳定页面 ID 的界面结构直接在 Swift 文件中编写；路由目录只含 ID/名称，不含设计截图的像素坐标。
- 内容图片资源为 `EditorialAssets/` 中逐张检查的 44 张插画/照片/材料图。它们可能来自原始设计中的内容图片区域，但不包含按钮、表单、卡片边框、导航或整屏 UI。图片清单和来源见 manifest.json。
- 底部 Tab 使用按原稿重绘的 10 个矢量 PDF 图标（含两种状态），其余图标采用原生符号渲染；卡片、填色、圆角、标题、图片外的正文和可交互控件由 UIKit 实现。
- CocoaPods 管理第三方依赖，不使用 SPM。当前没有必须引入的第三方库。

## 导航修正（2026-09-28）

详情页统一使用原生 UINavigationBar 和侧滑返回；五个 Tab 保留独立导航栈；重复目标不再叠加；创建/保存成功后移除已提交表单。作品加入空间流程、搜索返回、底栏安全区及临时跳转后的输入保留已调整。完整规则与回归记录见 [导航修正](docs/navigation-fix/README.md)。

## 个人主页、收藏与活动

P01–P04 已按设计审阅页第 07 组重新实现，包含对应内容素材、主页作品网格、收藏夹缩略图、活动分组和完整资料表单。说明与实际对照见 [四页还原记录](docs/profile-fidelity/README.md)。

## 底部图标

五个 Tab 已替换为独立矢量图标，资源与生成说明见 [Tab 图标](docs/tab-icons/README.md)。

## 运行

打开 `MadeRoom.xcworkspace`，选择 MadeRoom scheme 和 iPhone 模拟器。最低 iOS 17。真机运行需要自己的签名团队。

```sh
xcodegen generate
pod install
xcodebuild -workspace MadeRoom.xcworkspace -scheme MadeRoom -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

XcodeGen 重新生成工程后必须再次执行 pod install。

## 源码

- `Core/RoomStore.swift`：本地模型、校验和原子持久化。
- `UI/ScreenViewController.swift`：原生页面基类、自动布局、键盘和输入控件。
- `UI/NativeComponents.swift`：原生文字、按钮、卡片和内容图片。
- `UI/DiscoverScreens.swift`、`MakingScreens.swift`、`SpaceScreens.swift`、`CommunityScreens.swift`、`ProfileScreens.swift`、`StateScreens.swift`：手写的页面结构。
- `UI/AppCoordinator.swift`：导航、业务操作和系统照片/分享面板。
- `UI/DesignCatalog.swift`：仅保存语义路由信息和明确命名的内容图片读取。
- `tools/export_editorial_assets.py`：人工确定区域的内容素材提取；不导出 UI 布局、文字图片或控件。

## 本地业务

保留项目创建→六步制作→加入空间、项目笔记和归档、空间创建/改名、收藏集、资料与头像、草稿和偏好持久化。空间改名同步作品归属，删除收藏集保留全局收藏。在线登录、公开发布、评论发送、举报、审核、挑战投稿和云同步仍未连接服务，不返回虚构成功。

Debug 长按 1.5 秒打开页面检查目录；`--screen D04` 可直达页面。设计状态入口是检查用预览，不表示对应在线服务已发生。

## 验收边界

**原生重做不等于已达成 1:1。** 当前已改变错误的实现方式；字体、间距、图标造型、各页配图对应关系和次级交互仍需要逐页对照。44 张内容素材不是原图所有插画的完整交付。不得把“56 页能打开”写成“56 页视觉或业务全部通过”。

旧版 `docs/screenshots/`、`docs/visual-review.html` 是已撤换实现的历史证据，不作为新版本验收。新截图和检查记录写入 `docs/native-rebuild/`。

## Pixso 账号流程（2026-10-08）

已根据 Pixso MCP 获取的四页设计加入原生邮箱登录、注册、找回密码和首次启动协议弹层。登录插画上下边缘使用原生渐变衔接背景，字号采用设计稿的思源黑体。入口为首次启动、A01/A02 和设置 → 账号 → 邮箱登录。账号服务尚未配置，详情与实际验证边界见 [账号流程说明](docs/pixso-auth/README.md)。

## Codemagic（MadeRoom）

仓库根目录的 `codemagic.yaml` 提供两个手动工作流，固定 Xcode 27.0、CocoaPods 1.16.2，使用已提交的 `Podfile.lock` 和 `MadeRoom.xcworkspace`。不设置自动触发。

- `ios-tests`：安装锁定依赖 → MadeRoomTests 单元测试 → 无分发签名的真机 Release 编译。
- `ios-release`：安装依赖 → 设置构建号 → 单元测试 → App Store 签名 → 归档导出 IPA。使用前在 MadeRoom 环境变量中设置未上传过的正整数 `RELEASE_BUILD_NUMBER`，并配置匹配 `studio.maderoom.ios` 的 App Store 描述文件与证书。

版本默认 `1.0.0 (1)`，由 `project.yml` 与已提交工程一致管理；CI 使用 agvtool 修改当前构建副本的 Build 号。后续更新营销版本时同步修改 XcodeGen 配置并重新生成工程、执行 `pod install`。

本次仅配置代码侧，未绑定 Apple API 集成、未配置 publishing、未上传或自动提审。Apple 团队和商店应用记录确认后，再增加对应的 `integrations.app_store_connect` 与发布配置。不要直接使用其他应用的描述文件。

CI 运行 `MadeRoomTests`，不包含需要在线账号和外部服务的 `MadeRoomUITests`；UI 验收需单独执行。测试结果及编译日志作为构建产物保留。

本地验证：

```sh
pod install --deployment
bash scripts/ci-tests.sh
# 可覆盖模拟器目标，例如：
TEST_DESTINATION='platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' bash scripts/ci-tests.sh
```

提交并推送配置后，在 Codemagic 的 MadeRoom 项目选择对应分支，点击 Check for configuration files，然后手动运行 `ios-tests`。当前代码配置不代表云端构建、签名或上传已经验证成功。
