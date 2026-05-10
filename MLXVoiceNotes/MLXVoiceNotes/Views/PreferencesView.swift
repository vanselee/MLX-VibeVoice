import SwiftUI

struct PreferencesView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    @AppStorage("cacheLimit") private var cacheLimit: CacheLimit = .gb20
    @AppStorage("defaultExportDirectory") private var defaultExportDirectory: String = ""
    @State private var cacheUsage: String = "待统计"

    private static let trailingColumnWidth: CGFloat = 300
    private static let controlWidth: CGFloat = 176
    private static let pairButtonWidth: CGFloat = 124
    private static let controlHeight: CGFloat = 32

    private var currentExportDisplayPath: String {
        if defaultExportDirectory.isEmpty {
            return "Downloads / MLX VibeVoice Exports"
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let path = defaultExportDirectory
            if path.hasPrefix(home) {
                return String(path.dropFirst(home.count))
                    .replacingOccurrences(of: "/Downloads/MLX VibeVoice Exports", with: "Downloads / MLX VibeVoice Exports")
            }
            return path
        }
    }

    private func shouldTruncatePath(_ path: String) -> Bool {
        let pathWidth = path.size(withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]).width
        let totalWidth: CGFloat = 600
        return pathWidth > totalWidth * 0.5
    }

    var body: some View {
        AppPageScaffold(title: "偏好设置", subtitle: "管理语言、导出位置和本地缓存。") {
            VStack(alignment: .leading, spacing: 14) {
                settingsCard {
                    preferenceRow("语言") {
                        HStack {
                            Spacer()
                            Picker("", selection: $appLanguage) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.regular)
                            .frame(width: Self.controlWidth, height: Self.controlHeight)
                        }
                        .frame(width: Self.trailingColumnWidth)
                    }
                }

                settingsCard {
                    preferenceRow("导出位置") {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(currentExportDisplayPath)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(shouldTruncatePath(currentExportDisplayPath) ? 1 : nil)
                                .truncationMode(.middle)
                                .frame(width: Self.trailingColumnWidth, alignment: .trailing)
                            HStack(spacing: 8) {
                                Button("恢复默认位置") {
                                    defaultExportDirectory = ""
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .frame(width: Self.pairButtonWidth, height: Self.controlHeight)
                                Button("更改位置") {
                                    changeExportDirectory()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .frame(width: Self.pairButtonWidth, height: Self.controlHeight)
                            }
                            .frame(width: Self.trailingColumnWidth, alignment: .trailing)
                        }
                    }
                }

                settingsCard {
                    VStack(spacing: 0) {
                        preferenceRow("当前占用缓存") {
                            HStack {
                                Spacer()
                                Text(cacheUsage)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: Self.trailingColumnWidth)
                        }

                        Divider().padding(.horizontal, 16)

                        preferenceRow("缓存上限", subtitle: "达到上限后提醒用户清理缓存。") {
                            HStack {
                                Spacer()
                                Picker("", selection: $cacheLimit) {
                                    ForEach(CacheLimit.allCases) { limit in
                                        Text(limit.displayName).tag(limit)
                                    }
                                }
                                .labelsHidden()
                                .controlSize(.regular)
                                .frame(width: Self.controlWidth, height: Self.controlHeight)
                            }
                            .frame(width: Self.trailingColumnWidth)
                        }

                        Divider().padding(.horizontal, 16)

                        preferenceRow("清理缓存", subtitle: "清除可再生成的临时文件，不删除用户文案和导出音频。") {
                            HStack {
                                Spacer()
                                Button("清理缓存") {
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .frame(width: Self.controlWidth, height: Self.controlHeight)
                                .disabled(true)
                            }
                            .frame(width: Self.trailingColumnWidth)
                        }
                    }
                }
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func preferenceRow(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
                .frame(width: Self.trailingColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func changeExportDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "选择导出目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if !defaultExportDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultExportDirectory)
        } else {
            panel.directoryURL = AudioExportService.defaultExportDirectory
        }

        if panel.runModal() == .OK, let url = panel.url {
            defaultExportDirectory = url.path
        }
        #endif
    }
}

#Preview {
    PreferencesView()
}
