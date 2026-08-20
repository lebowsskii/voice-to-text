import ServiceManagement

/// Registers the app as a login item via `SMAppService`. No separate helper
/// target — `.mainApp` registers the app bundle itself.
final class LoginItemStore {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
