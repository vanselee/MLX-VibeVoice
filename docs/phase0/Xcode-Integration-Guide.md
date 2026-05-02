# Phase 0: 完整的 Xcode 集成指南

此文档详细说明了如何在 Xcode 中完成 Phase 0 集成

## 一、在 Xcode 中添加新文件

### 步骤 1: 添加所有视图文件

打开 `/Users/apple/Desktop/SoftDev/aiaudiovideo/MLXVoiceNotes/MLXVoiceNotes.xcodeproj

添加以下文件：

1. **Services 目录下的文件**
   - `MLXAudioService.swift

2. **Views 目录下的文件**
   - `SharedComponents.swift
   - `ScriptLibraryView.swift
   - `RoleReviewView.swift
   - `ResourceCenterView.swift
   - `TaskQueueView.swift
   - `PreferencesView.swift
   - `CreateVoiceProfileView.swift
   - `MLXTestView.swift

添加方式：
- 在 Xcode 左侧项目导航器中，右键点击 `MLXVoiceNotes` 项目文件夹
- 选择「Add Files to "MLX Voice Notes..."
- 从文件选择器中选中所有要添加的文件
- 确保勾选：
  - ✅ Copy items if needed
  - ✅ Add to targets: "MLX Voice Notes"
- 点击「Add」

## 二、添加 Swift Package Manager 依赖

### 步骤 2: 添加 mlx-audio-swift

1. 在 Xcode 中，选择项目文件导航器中最顶层的项目（蓝色图标）
2. 选择 「Package Dependencies」 标签页
3. 点击左下角的 「+」 按钮
4. 在搜索框中输入：
   ```
   https://github.com/Blaizzy/mlx-audio-swift
   ```
5. 在 Dependency Rule 选项中选择：「Up to Next Major Version」，输入 `0.1.0`
6. 点击「Add Package」按钮
7. 在弹出的对话框中，勾选 `MLXAudioTTS` 和 `MLXAudioCore`（如果可用）
8. 点击「Add Package」确认

## 三、验证项目可以构建

### 步骤 3: 构建并运行

1. 在 Xcode 中按 ⌘+B （Product → Build）来构建项目
2. 确保没有错误
3. 按 ⌘+R （Product → Run）运行应用
4. 检查应用正常启动

## 四、Phase 0 验证清单

- [ ] 所有文件都成功添加到 Xcode 项目中
- [ ] Package Dependencies 添加成功
- [ ] 项目成功编译无错误
- [ ] 应用成功启动
- [ ] Debug 模式下能看到「MLX Test」导航项

## 五、下一步

完成 Phase 0 集成后，我们将进入 Phase 1，实现功能集成。
