# 底部 Tab 图标资源

原设计板图的不同页面存在图标语义不一致。本次统一采用 P01 的完整五项组合作为基准，避免切换页面时同一 Tab 从房屋变成叶片，或从工具变成加号。

| Tab | 造型 | 未选中 | 选中 |
|---|---|---|---|
| Discover | 叶片与叶脉 | 灰色轮廓 | 深绿色加重轮廓 |
| Make | 交叉画笔与铅笔 | 灰色轮廓 | 深绿色画笔柄 |
| Spaces | 房屋与门洞 | 灰色轮廓 | 深绿色填充，透明门洞 |
| Community | 三人组合 | 灰色轮廓 | 深绿色填充 |
| Profile | 无外圈人物 | 灰色轮廓 | 深绿色填充 |

## 交付与接入

- 可编辑 SVG：项目 `design/tab-icons/`，10 个，统一 24 × 24 viewBox。
- iOS 资源：`MadeRoom/Resources/TabIcons.xcassets`，10 个独立矢量 PDF imageset。
- PDF 保留矢量表示，使用 template tint；无背景色、无截图裁片，不依赖 SF Symbols 近似替代。
- 生成源：`tools/generate_tab_icons.swift`。在 ios 目录执行 `swift tools/generate_tab_icons.swift` 可重建全部 SVG、PDF 和检查用 PNG。
- 接入：RoomTabIcon 同时用于自定义底栏与底层 UITabBarItem，选中态明确切换对应资源。
- 可点击区域保持原来的 58 pt 高度；24 pt 图标大小不会缩小点击区域。
- 此为基于原稿的独立矢量重绘，不宣称与低分辨率原图逐像素一致。

[两种状态资源预览](icon-preview.png)

## 验证结果

2026-09-28，iPhone 17 Pro / iOS 26.1：构建成功，19 项单元测试与 2 项 UI 测试通过。确认 10 个模板图片资源均成功加载且为 24 pt；五个 Tab 的选中状态、点击区域、切换、搜索返回和侧滑返回通过。

测试结果：`build/Logs/Test/Test-MadeRoom-2026.09.28_16-50-53-+0800.xcresult`。

实际运行截图：[Discover](D01.png) · [Make](M01.png) · [Spaces](S01.png) · [Community](C01.png) · [Profile](P01.png)。
