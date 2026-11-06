import PreviewAICore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        TabView(selection: $model.tab) {
            GeneralSettings(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProviderSettings(model: model)
                .tabItem { Label("Providers", systemImage: "sparkles") }
                .tag(SettingsTab.providers)
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 560, height: 440)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Summarize shortcut") {
                    ShortcutRecorderButton(model: model)
                }
                if let hint = model.recorder.hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
                if let warning = model.shortcutWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("Select a document in Finder and press the shortcut. You can also right-click a file → Services → Summarize with PreviewAI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Default length", selection: $model.settings.length) {
                    ForEach(SummaryLength.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Open PreviewAI at login", isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let error = model.loginItemError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRecorderButton: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Button {
            if model.recorder.isRecording { model.endShortcutRecording() } else { model.beginShortcutRecording() }
        } label: {
            Text(model.recorder.isRecording ? "Type shortcut…" : model.settings.shortcut.displayString)
                .monospaced()
                .frame(minWidth: 120)
        }
        .help("Click, then press the new shortcut")
    }
}

// MARK: - About

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.page.badge.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("PreviewAI").font(.title2.weight(.semibold))
            Text("Version \(PreviewAIInfo.version)").foregroundStyle(.secondary)
            Text("Select a document in Finder, press a shortcut, get a summary.")
                .multilineTextAlignment(.center)
            Text("No data leaves your Mac unless you choose a cloud provider. With Apple Intelligence or a local model, documents stay on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Link("github.com/memoliertorerr/previewAI", destination: URL(string: "https://github.com/memoliertorerr/previewAI")!)
                .padding(.top, 4)
            Text("PreviewAI is an independent open-source project. It isn't made by, affiliated with, or endorsed by Apple, Anthropic, OpenAI, Ollama, or LM Studio. Product names belong to their owners.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Providers

private struct ProviderSettings: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $model.settings.selectedProvider) {
                    ForEach(ProviderRegistry.availableIDs, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: model.settings.selectedProvider) { model.clearProviderFeedback() }
            }

            switch model.settings.selectedProvider {
            case .appleIntelligence: AppleIntelligenceForm(model: model)
            case .anthropic: AnthropicForm(model: model)
            case .openAICompatible: OpenAICompatibleForm(model: model)
            case .claudeCode: CLIForm(model: model, tool: .claudeCode)
            case .codex: CLIForm(model: model, tool: .codex)
            }

            Section {
                HStack {
                    Button("Test Connection") { model.testConnection() }
                        .disabled(model.isTesting)
                    if model.isTesting { ProgressView().controlSize(.small) }
                    Spacer()
                }
                switch model.testResult {
                case .success(let message)?:
                    Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
                case .failure(let message)?:
                    Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.callout)
                case nil:
                    EmptyView()
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppleIntelligenceForm: View {
    @Bindable var model: SettingsModel
    @State private var status: ProviderAvailability?

    var body: some View {
        Section {
            switch status {
            case .ready?:
                Label("Ready — runs on this Mac, free and private.", systemImage: "checkmark.circle")
            case .unavailable(let reason)?:
                Text(reason).foregroundStyle(.secondary)
                Button("Open Apple Intelligence Settings") { model.openAppleIntelligenceSettings() }
            case nil:
                ProgressView().controlSize(.small)
            }
            Text("The on-device model has a small context window, so long documents are summarized from their first part.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { status = await AppleIntelligenceProvider().availability() }
    }
}

private struct AnthropicForm: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            APIKeyField(model: model, provider: .anthropic, placeholder: "sk-ant-…")
            Picker("Model", selection: $model.settings.anthropic.model) {
                ForEach(AnthropicConfig.models, id: \.self) { Text($0).tag($0) }
            }
            Text("Opus is the most capable; Haiku is the fastest and cheapest. Keys: platform.claude.com.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OpenAICompatibleForm: View {
    @Bindable var model: SettingsModel

    var body: some View {
        let config = model.settings.openAICompatible
        Section {
            Picker("Service", selection: $model.settings.openAICompatible.preset) {
                ForEach(OpenAICompatiblePreset.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model.settings.openAICompatible.preset) { model.clearProviderFeedback() }

            if config.preset == .openAI {
                LabeledContent("Server", value: config.effectiveBaseURL)
            } else {
                TextField("Server URL", text: $model.settings.openAICompatible.baseURL,
                          prompt: Text(config.preset.defaultBaseURL.isEmpty ? "https://example.com/v1" : config.preset.defaultBaseURL))
            }
            if !config.preset.isLocal {
                APIKeyField(model: model, provider: .openAICompatible,
                            placeholder: config.preset.needsAPIKey ? "sk-…" : "Optional")
            }
            HStack {
                TextField("Model", text: $model.settings.openAICompatible.model, prompt: Text(config.preset.isLocal ? "e.g. llama3.2" : "Model ID"))
                Menu("Choose") {
                    if model.availableModels.isEmpty {
                        Text(model.modelListError ?? "Click Refresh to load models")
                    }
                    ForEach(model.availableModels, id: \.self) { name in
                        Button(name) { model.settings.openAICompatible.model = name }
                    }
                }
                .fixedSize()
                Button("Refresh") { model.refreshModels() }
            }
            if let error = model.modelListError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if config.preset.isLocal {
                Text("Make sure \(config.preset.displayName) is running. Local models see the first ~24 000 characters of a document.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CLIForm: View {
    @Bindable var model: SettingsModel
    let tool: ProviderID

    private var config: Binding<CLIConfig> {
        tool == .claudeCode ? $model.settings.claudeCode : $model.settings.codex
    }

    var body: some View {
        Section {
            #if !APPSTORE
            let cli: CLITool = tool == .claudeCode ? .claude : .codex
            let found = cli.locate(override: config.wrappedValue.binaryPath)
            LabeledContent("Status") {
                if let found {
                    Text(found.path).foregroundStyle(.secondary).textSelection(.enabled)
                } else {
                    Text(config.wrappedValue.binaryPath.isEmpty ? "Not installed" : "Not found at that path").foregroundStyle(.red)
                }
            }
            #endif
            TextField("Path override", text: config.binaryPath, prompt: Text("Auto-detect"))
            TextField("Model", text: config.model, prompt: Text("CLI default"))
            Text(tool == .claudeCode
                 ? "Install Claude Code and sign in once by running `claude` in Terminal."
                 : "Install Codex and sign in once by running `codex` in Terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let notice = tool.termsNotice {
                Label(notice, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A secure field that saves to the Keychain; shows whether a key is stored without revealing it.
private struct APIKeyField: View {
    @Bindable var model: SettingsModel
    let provider: ProviderID
    let placeholder: String
    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        let hasKey = model.settings.apiKey(for: provider) != nil
        HStack {
            SecureField("API key", text: $draft, prompt: Text(hasKey ? "Saved in Keychain — type to replace" : placeholder))
                .onSubmit(save)
            Button("Save", action: save).disabled(draft.isEmpty)
            if hasKey {
                Button("Remove") { store(nil) }
            }
        }
        if let error {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }

    private func save() {
        guard !draft.isEmpty else { return }
        store(draft)
    }

    private func store(_ key: String?) {
        do {
            try model.settings.setAPIKey(key, for: provider)
            draft = ""
            error = nil
            model.clearProviderFeedback()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
