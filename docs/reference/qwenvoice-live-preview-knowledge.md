# QwenVoice 实时预览参考知识库

更新时间：2026-05-06

用途：记录对开源项目 `PowerBeef/QwenVoice` 的实时语音预览机制分析。后续如果需要研究或实现“生成中实时试听/实时预览”，优先回看本文档。当前阶段仅作为参考，不代表 MLX Voice Notes 立即进入该功能开发。

## 结论

QwenVoice 的实时预览不是“等待最终 WAV 生成完成后播放”，而是真正的流式音频预览。

核心方式是：

1. 模型生成使用 `generateStream(...)`，生成过程中持续产出音频 chunk。
2. 每个 chunk 被转换为 PCM16 音频数据。
3. chunk 通过事件总线传给 UI。
4. UI 使用 `AVAudioEngine + AVAudioPlayerNode` 维护播放队列。
5. 播放前有预缓冲策略，降低边生成边播放时的卡顿概率。
6. 最终完整 WAV 仍会写入文件，用于最终播放、保存或导出。

## 关键实现链路

### 1. 模型层：generateStream

参考文件：

- `/private/tmp/QwenVoice/third_party_patches/mlx-audio-swift/Sources/MLXAudioTTS/Models/Qwen3TTS/Qwen3TTS.swift`
- `/private/tmp/QwenVoice/third_party_patches/mlx-audio-swift/Sources/MLXAudioTTS/Models/Qwen3TTS/README.md`

Qwen3TTS 提供 `generateStream(...)`，返回：

```swift
AsyncThrowingStream<AudioGeneration, Error>
```

生成过程中会持续 yield：

- `.token`
- `.info`
- `.chunkTimings`
- `.audio(chunk)`

其中 `.audio(chunk)` 是实时预览的关键。

QwenVoice 默认使用类似：

```swift
streamingInterval: 0.32
```

也就是大约每 0.32 秒产出一个音频 chunk。

### 2. 生成层：chunk 转 PCM

参考文件：

- `/private/tmp/QwenVoice/Sources/QwenVoiceCore/NativeStreamingSynthesisSession.swift`

关键流程：

1. 接收 `.audio(let samples)`。
2. `samples.asArray(Float.self)` 转为 `[Float]`。
3. 通过 limiter 限制峰值，避免爆音。
4. 转为 PCM16。
5. 同时做两件事：
   - 写入最终完整 WAV。
   - 构造实时预览 chunk 事件。

### 3. 事件结构：StreamingAudioChunk

参考文件：

- `/private/tmp/QwenVoice/Sources/QwenVoiceCore/SemanticTypes.swift`

实时音频 chunk 的核心结构：

```swift
public struct StreamingAudioChunk: Hashable, Codable, Sendable {
    public let requestID: Int?
    public let sampleRate: Int
    public let frameOffset: Int64
    public let frameCount: Int
    public let pcm16LE: Data
    public let isFinal: Bool
}
```

重点：QwenVoice 优先把 PCM16 小端音频数据直接放进事件里传给 UI，而不是只依赖临时 WAV 文件。

这比“写 chunk.wav，再让 UI 读 chunk.wav”更低延迟，也更少文件读写竞争。

### 4. 事件总线：GenerationChunkBroker

参考文件：

- `/private/tmp/QwenVoice/Sources/QwenVoiceNative/GenerationChunkBroker.swift`

它用 Combine 的 `PassthroughSubject` 广播生成事件：

```swift
GenerationChunkBroker.publish(event)
```

播放器订阅这个 broker，收到 chunk 后进入实时播放流程。

### 5. 播放层：AVAudioEngine 队列播放

参考文件：

- `/private/tmp/QwenVoice/Sources/SharedSupport/ViewModels/AudioPlayerViewModel.swift`

播放器收到实时 chunk 后：

1. 如果事件里有 `previewAudio`，走内联 PCM 路径。
2. `makePCMBuffer(from:)` 把 PCM16 转成 `AVAudioPCMBuffer`。
3. 使用 `AVAudioEngine + AVAudioPlayerNode`。
4. 通过 `scheduleBuffer(buffer)` 把 chunk 追加到播放队列。
5. 队列达到预缓冲条件后开始播放。

关键设计：不是每个 chunk 新建一个播放器，而是维护同一个 `AVAudioEngine` 和 `AVAudioPlayerNode`，持续排队播放 buffer。

### 6. 预缓冲策略

参考文件：

- `/private/tmp/QwenVoice/Sources/SharedSupport/ViewModels/AudioPlayerViewModel.swift`

默认策略大致是：

- 至少 3 个 chunk。
- 或至少约 2.25 秒可播放音频。

如果播放速度追上生成速度，会暂停等待更多 chunk，再继续播放。

这个策略用于平衡：

- 首次出声速度。
- 播放过程是否容易中断。

## 对 MLX Voice Notes 的启发

当前 MLX Voice Notes 更接近：

```text
生成完整段落 WAV -> 保存 -> 试听/导出
```

如果未来要实现类似 QwenVoice 的实时预览，建议不要一次照搬完整架构，而是分阶段推进。

推荐最小路线：

1. 在 `MLXAudioService` 增加 `generateAudioStream(...)`。
2. 内部调用 `model.generateStream(...)`。
3. 先只支持单段文本实时试听。
4. 将 `.audio(chunk)` 转成 PCM16。
5. 建一个轻量 `LivePreviewBroker` 或回调闭包。
6. UI 用 `AVAudioEngine + AVAudioPlayerNode` 播放实时 chunk。
7. 同时保留最终 WAV 写入，确保导出和退出后可复用。

不建议第一步就接入整篇多角色生成，因为那会同时牵涉：

- 段落队列状态。
- 多音色切换。
- 取消/暂停。
- SwiftData 持久化。
- 导出合并。
- 错误恢复。

## 可借鉴设计

可以借鉴：

- `generateStream(...)` 作为流式生成入口。
- 内联 PCM chunk 事件，而不是只传临时文件路径。
- `AVAudioEngine + AVAudioPlayerNode` 持续排队播放。
- 预缓冲策略。
- chunk decode/播放失败诊断。
- 最终 WAV 与实时预览并行生成。

暂不建议照搬：

- QwenVoice 的完整 XPC/native engine 架构。
- 复杂性能探针。
- 多平台兼容层。
- 过重的 benchmark/telemetry 体系。

## 后续触发方式

当用户提到“知识库”“实时预览知识库”“QwenVoice 预览方案”时，优先读取本文档，再结合当前项目代码给出方案。
