import Foundation

protocol ConnectionRecoveryEventPublishing {
    func publishOnlineSessionValidated(_ event: SynologyOnlineSessionValidatedEvent)
    func publishQuickConnectEndpointOptimized(_ event: SynologyQuickConnectEndpointOptimizedEvent)
}

struct NotificationCenterConnectionRecoveryEventPublisher: ConnectionRecoveryEventPublishing {
    private let notificationCenter: NotificationCenter
    private let object: AnyObject?

    init(notificationCenter: NotificationCenter = .default, object: AnyObject? = nil) {
        self.notificationCenter = notificationCenter
        self.object = object
    }

    func publishOnlineSessionValidated(_ event: SynologyOnlineSessionValidatedEvent) {
        notificationCenter.post(
            name: .synologyOnlineSessionValidated,
            object: object,
            userInfo: event.toUserInfo()
        )
    }

    func publishQuickConnectEndpointOptimized(_ event: SynologyQuickConnectEndpointOptimizedEvent) {
        notificationCenter.post(
            name: .synologyQuickConnectEndpointOptimized,
            object: object,
            userInfo: event.toUserInfo()
        )
    }
}
