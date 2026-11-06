import Foundation
import ServiceManagement

public enum LoginItemStatus: Sendable, Equatable {
    case enabled
    /// Registered, but the user must allow it in System Settings → General → Login Items.
    case requiresApproval
    case disabled
}

/// Registers the app as a login item. Behind a protocol so tests never touch the real one.
@MainActor
public protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openApprovalSettings()
}

@MainActor
public final class SystemLoginItemService: LoginItemService {
    public init() {}

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    public func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Keeps the "Open at login" setting and the system login item in agreement.
@MainActor
public final class LaunchAtLogin {
    private let settings: SettingsStore
    private let service: LoginItemService

    static let approvalMessage = "Allow PreviewAI in System Settings → General → Login Items to finish turning this on."

    public init(settings: SettingsStore, service: LoginItemService) {
        self.settings = settings
        self.service = service
    }

    /// Shown while macOS is waiting for the user's approval; nil otherwise.
    public var approvalMessage: String? {
        service.status == .requiresApproval ? Self.approvalMessage : nil
    }

    /// Reflects the system's state (the user can also change it in System Settings).
    public func syncFromSystem() {
        let on = service.status != .disabled
        if settings.launchAtLogin != on { settings.launchAtLogin = on }
    }

    /// Returns a message to show if macOS refused or needs approval; the setting then reflects
    /// reality.
    @discardableResult
    public func set(_ enabled: Bool) -> String? {
        do {
            try service.setEnabled(enabled)
            syncFromSystem()
            if enabled, service.status == .requiresApproval {
                service.openApprovalSettings()
                return Self.approvalMessage
            }
            return nil
        } catch {
            syncFromSystem()
            return "macOS didn't allow changing the login item: \(error.localizedDescription)"
        }
    }
}
