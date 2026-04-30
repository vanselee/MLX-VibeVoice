# MLX Voice Notes 原型

## 低保真流程原型

文件：`mlx-voice-notes-low-fi.html`

用途：

- 讨论信息架构和功能覆盖
- 校对 PRD 中的流程是否完整
- 给外部设计工具提供结构参考

## 中高保真产品原型

文件：`mlx-voice-notes-hifi.html`

用途：

- 评审真实 macOS App 的界面气质
- 确认主工作台布局、右侧检查器、资源中心和底部状态栏
- 作为 Phase 1 SwiftUI 工程的界面参考

这版原型仍然是静态 HTML，不代表最终代码结构。正式 App 会使用 SwiftUI 实现。

## 中高保真页面组

文件：`mlx-voice-notes-hifi-pages.html`

用途：

- 展示完整 App 不同页面/视图之间的分工
- 覆盖工作台、角色确认、资源中心、生成队列、导出与设置
- 用于 Phase 1 开发前确认页面范围和导航逻辑

页面组说明：

- 01 配音工作台：最高频的创作主界面
- 02 角色确认：批量处理候选角色、相似名和未标记文本
- 03 资源中心：模型下载、音色库、缓存管理
- 04 生成队列：分段生成、版本切换、失败重试
- 05 导出与设置：WAV/SRT 导出、语言、缓存、诊断

## 原型资源

Logo 文件：`assets/mlx-voice-notes-logo.png`

该文件来自当前项目选定的应用 Logo，用于高保真原型中的品牌位。正式 App 开发时需要再转换为 macOS AppIcon 所需的多尺寸资源。

已准备的 App 图标开发资源：

- `assets/AppIcon.iconset/`：macOS iconset 多尺寸 PNG。
- `assets/AppIcon.appiconset/`：可迁移到 Xcode `Assets.xcassets` 的 AppIcon 资源。

主工作台中的资源与队列区域应视为可收起底部抽屉；完整管理流程应进入独立的资源中心和任务队列页面，避免主编辑界面过载。
