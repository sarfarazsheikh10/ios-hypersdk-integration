import UIKit
import HyperSDK

/// Thin wrapper around `HyperServices`. One instance per app process.
///
/// Lifecycle: `initiate(from:)` once, then `openUPIManagement…()` any number of
/// times, then `terminate()` when leaving the flow.
final class HyperSDKManager {

    static let shared = HyperSDKManager()

    /// Direct PSP: the SDK is scoped to a tenant + client at construction.
    let hyper = HyperServices(tenantId: TPAPConfig.tenantId, clientId: TPAPConfig.clientId)

    private init() {}

    var isInitialised: Bool { hyper.isInitialised() }

    /// Fire-and-forget. Call exactly once for this instance.
    func initiate(from viewController: UIViewController,
                  onEvent: @escaping (_ event: String, _ data: [String: Any]) -> Void) {

        let payload = TPAPPayloadFactory.initiatePayload()
        Log.json("initiate →", payload)

        hyper.initiate(viewController, payload: payload) { response in
            guard let data = response, let event = data["event"] as? String else { return }
            Log.json("event ← \(event)", data)

            // The SDK asks us to resume an in-flight payment.
            if event == "paymentAttempt", let resume = data["payload"] as? [String: Any] {
                HyperSDKManager.shared.hyper.process(resume)
            }

            onEvent(event, data)
        }
    }

    /// UPI Management screen, signature auth.
    /// https://juspay.io/in/docs/upi-plugin-sdk/ios/process-payloads/upi-management
    func openUPIManagementSignature(customerId: String = TPAPConfig.testCustomerId,
                                    shouldExitOnDeregister: Bool = false) {
        guard requireInitialised("management (signature)") else { return }
        let payload = TPAPPayloadFactory.managementPayloadSignature(
            customerId: customerId, shouldExitOnDeregister: shouldExitOnDeregister)
        Log.json("process → management (signature)", payload)
        hyper.process(payload)
    }

    /// UPI Management screen, `clientAuthToken` auth.
    func openUPIManagementToken(customerId: String = TPAPConfig.testCustomerId,
                                clientAuthToken: String = TPAPConfig.clientAuthToken,
                                authExpiry: String? = TPAPConfig.authExpiry,
                                shouldExitOnDeregister: Bool = false) {
        guard requireInitialised("management (token)") else { return }
        guard !clientAuthToken.isEmpty else {
            Log.line("management (token) ignored — set TPAPConfig.clientAuthToken first")
            return
        }
        let payload = TPAPPayloadFactory.managementPayloadToken(
            customerId: customerId, clientAuthToken: clientAuthToken,
            authExpiry: authExpiry, shouldExitOnDeregister: shouldExitOnDeregister)
        Log.json("process → management (token)", payload)
        hyper.process(payload)
    }

    func terminate() {
        Log.line("terminate")
        hyper.terminate()
    }

    /// Call from AppDelegate/SceneDelegate URL handlers so PSP/bank redirects
    /// reach the SDK.
    @discardableResult
    static func handleRedirect(_ url: URL, sourceApplication: String?) -> Bool {
        HyperServices.handleRedirectURL(url, sourceApplication: sourceApplication ?? "")
    }

    // MARK: -

    private func requireInitialised(_ what: String) -> Bool {
        guard hyper.isInitialised() else {
            Log.line("\(what) ignored — SDK not initialised yet (run Initiate first)")
            return false
        }
        return true
    }
}
