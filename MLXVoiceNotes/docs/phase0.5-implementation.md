# Phase 0.5 实现记录

## 完成时间
2026-05-02 17:03 UTC+8

## 目标
将真实 TTS 接入正式文案生成流程，实现单篇文案串行生成与完整 WAV 导出。

## 实施内容

### 1. ScriptSegment 新增字段
```swift
var generatedAudioPath: String?  // 生成的音频文件路径（相对路径）
```

**约束**：
- 不保存临时目录路径
- 保存相对路径（相对于 `Application Support/MLX Voice Notes/GeneratedAudio/`）
- 默认 nil，旧数据自动迁移
- 找不到文件时该段落视为需要重新生成

### 2. AudioStorageService（新增）
管理 App 持久化音频存储目录：
- 根目录：`Application Support/MLX Voice Notes/GeneratedAudio/`
- 文案目录：`<scriptID>/`
- 段落文件：`<segmentID>.wav`

**功能**：
- `persistAudioFile(tempURL:for:segmentID:)` — 复制临时文件到持久化目录
- `relativePath(from:)` — 转换为相对路径
- `absoluteURL(from:)` — 从相对路径恢复绝对路径
- `deleteAudioFiles(for:)` — 删除文案的所有音频文件
- `totalGeneratedAudioSize()` — 计算总大小（用于缓存清理）

### 3. GenerationService（重写）
**移除 Timer 调度**，改为 Task 串行生成：

```swift
static func start(script:voiceInstruct:completion:)
static func pause(script:)
static func cancel(script:)
static func retryFailedSegments(script:voiceInstruct:completion:)
static func resume(script:voiceInstruct:completion:)
```

**流程**：
1. 用户点击"生成音频" → 调用 `start()`
2. 创建后台 Task
3. 按段串行生成（检查状态，防止重复启动）
4. 每段生成完成后：
   - 调用 `MLXAudioService.generateAudio()` 生成临时 WAV
   - 调用 `AudioStorageService.persistAudioFile()` 复制到持久化目录
   - 保存相对路径到 `ScriptSegment.generatedAudioPath`
   - 删除临时文件
5. 全部完成 → `script.status = .completed`

**错误处理**：
- 单段失败不中断整体流程
- 失败段落标记 `.failed`，可单独重试

### 4. AudioExportService（重写）
**真实 WAV 合并**（不简单拼接字节）：

```swift
static func exportRealWAV(for:fileName:) throws -> AudioExportResult
```

**流程**：
1. 获取所有已完成段落（按顺序）
2. 使用 `AVAudioFile` 读取每段 PCM samples
3. 合并所有 samples 到一个数组
4. 使用 `AVAudioFile` 写入新 WAV 文件

**约束**：
- WAV 文件有 header，不能直接 Data 追加
- 使用 AVFoundation API 统一处理 24kHz mono 输出

### 5. ScriptLibraryView（修改）
- `startPlaceholderGeneration()` → 调用 `GenerationService.start()`
- `exportWAV()` → 调用 `AudioExportService.exportRealWAV()`

### 6. ContentView（修改）
- 移除 `Timer.publish` 调度
- 不再调用 `GenerationService.advanceOneTick()`

## 约束遵守

| 约束 | 状态 |
|------|------|
| 不下载模型 | ✅ |
| 不移动或删除模型文件 | ✅ |
| 不改 SwiftData schema（破坏性） | ✅ 新增可选字段，自动迁移 |
| 不做并发生成 | ✅ 串行 Task |
| 不做多版本 | ✅ |
| 不做参考音频克隆 | ✅ |
| 不改 UI 大结构 | ✅ 复用现有按钮 |
| 不保存临时目录路径 | ✅ 使用相对路径 |

## Git 提交
`4e536fe` — `feat(phase0.5): integrate real TTS generation with persistent audio storage`

## Build 验证
**BUILD SUCCEEDED** ✅

## 下一步
- 用户测试：启动 App → 创建文案 → 生成音频 → 导出 WAV
- 验证音频文件是否保存到 `Application Support/MLX Voice Notes/GeneratedAudio/`
- 验证导出的 WAV 是否可播放
- 验证音频内容与文案文本是否匹配
