import AppKit

enum ActivationPolicyManager {
    enum Reason: String {
        case settings
        case updateSession
        case sparkleModalAlert
    }

    private static var reasons: Set<Reason> = []

    static func addReason(_ reason: Reason) {
        reasons.insert(reason)
        applyPolicy()
    }

    static func removeReason(_ reason: Reason) {
        reasons.remove(reason)
        applyPolicy()
    }

    private static func applyPolicy() {
        let policy: NSApplication.ActivationPolicy = reasons.isEmpty ? .accessory : .regular
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
