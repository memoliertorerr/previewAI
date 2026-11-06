import AppKit
import Observation
import PreviewAICore

/// Glue between the panel's SwiftUI view and the session: holds UI-only state and actions.
@MainActor
@Observable
final class PanelModel {
    let session: SummarySession
    var length: SummaryLength = .standard
    var additionalFiles = 0
    /// Called by the view's close button / Esc.
    @ObservationIgnored var onClose: (() -> Void)?
    /// Set when there is somewhere useful to send the user after an error.
    @ObservationIgnored var onOpenSettings: (() -> Void)?
    /// Remembers the user's length choice as the new default.
    @ObservationIgnored var onLengthChange: ((SummaryLength) -> Void)?

    init(session: SummarySession) {
        self.session = session
    }

    var content: PanelContent {
        PanelContent(state: session.state, additionalFiles: additionalFiles)
    }

    var providerLabel: String { session.providerLabel }

    func changeLength(to newLength: SummaryLength) {
        guard newLength != length else { return }
        length = newLength
        onLengthChange?(newLength)
        session.regenerate(length: newLength)
    }

    func regenerate() {
        session.regenerate()
    }

    func copySummary() {
        let text = content.body
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func close() {
        onClose?()
    }

    func openSettings() {
        onOpenSettings?()
    }
}
