import AppKit
import PreviewAICore
import SwiftUI

struct SummaryView: View {
    @Bindable var model: PanelModel

    var body: some View {
        let content = model.content
        VStack(spacing: 0) {
            header(content)
            Divider().opacity(0.6)
            main(content)
            footer(content)
        }
        .frame(minWidth: 420, minHeight: 300)
        .onExitCommand { model.close() }
    }

    // MARK: Header

    private func header(_ content: PanelContent) -> some View {
        HStack(spacing: 10) {
            FileIcon(url: content.fileURL)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(content.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !content.subtitle.isEmpty {
                    Text(content.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !model.providerLabel.isEmpty {
                Text(model.providerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Button {
                model.close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Body

    @ViewBuilder
    private func main(_ content: PanelContent) -> some View {
        if let error = content.error {
            ErrorView(
                message: error,
                canRetry: content.canRegenerate,
                retry: { model.regenerate() },
                openSettings: settingsAction
            )
        } else if content.body.isEmpty {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(content.isWorking ? "Summarizing…" : "Select a document in Finder and press the shortcut.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                MarkdownText(markdown: content.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
    }

    private var settingsAction: (() -> Void)? {
        guard model.onOpenSettings != nil else { return nil }
        return { model.openSettings() }
    }

    // MARK: Footer

    private func footer(_ content: PanelContent) -> some View {
        VStack(spacing: 0) {
            if let note = content.truncationNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            HStack(spacing: 10) {
                Picker("Length", selection: Binding(get: { model.length }, set: { model.changeLength(to: $0) })) {
                    ForEach(SummaryLength.allCases, id: \.self) { length in
                        Text(length.displayName).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .disabled(content.fileURL == nil)

                Spacer()

                if content.isStreaming {
                    ProgressView().controlSize(.small)
                }
                Button {
                    model.regenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Regenerate (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!content.canRegenerate)

                Button {
                    model.copySummary()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy summary (⇧⌘C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!content.canCopy)
            }
            .controlSize(.regular)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, 8)
        }
    }
}

/// Renders summary Markdown block by block: headings, bullets, numbered lists, paragraphs.
struct MarkdownText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, 4)
        case .bullet(let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•").foregroundStyle(.secondary)
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .numbered(let number, let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").monospacedDigit().foregroundStyle(.secondary)
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .paragraph(let text):
            inline(text)
        case .rule:
            Divider()
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }
}

private struct ErrorView: View {
    let message: String
    let canRetry: Bool
    let retry: () -> Void
    let openSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack {
                if let openSettings {
                    Button("Open Settings", action: openSettings)
                }
                if canRetry {
                    Button("Try Again", action: retry)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FileIcon: View {
    let url: URL?

    var body: some View {
        if let url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }
}
