import Foundation
import ServiceManagement

/// Registers the app as a login item. Behind a protocol so tests never touch the real one.
@MainActor
public protocol LoginItemService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public final class SystemLoginItemService: LoginItemService {
    public init() {}

    public var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Keeps the "Open at login" setting and the system login item in agreement.
@MainActor
public final class LaunchAtLogin {
    private let settings: SettingsStore
    private let service: LoginItemService

    public init(settings: SettingsStore, service: LoginItemService) {
        self.settings = settings
        self.service = service
    }

    /// Reflects the system's state (the user can also remove the item in System Settings).
    public func syncFromSystem() {
        if settings.launchAtLogin != service.isEnabled { settings.launchAtLogin = service.isEnabled }
    }

    /// Returns an error message if macOS refused; the setting then reflects reality.
    @discardableResult
    public func set(_ enabled: Bool) -> String? {
        do {
            try service.setEnabled(enabled)
            settings.launchAtLogin = service.isEnabled
            return nil
        } catch {
            settings.launchAtLogin = service.isEnabled
            return "macOS didn't allow changing the login item: \(error.localizedDescription)"
        }
    }
}
