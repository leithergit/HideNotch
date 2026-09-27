import ServiceManagement

public enum LoginItemState: Equatable, Sendable {
    case enabled, disabled, requiresApproval
}

@MainActor
public protocol LoginItemControlling: AnyObject {
    var state: LoginItemState { get }
    func setEnabled(_ on: Bool) throws
    func openSystemSettings()
}

/// Registers the running app bundle as a login item; the system is the source of truth.
public final class SystemLoginItem: LoginItemControlling {
    public init() {}

    public var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    public func setEnabled(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
