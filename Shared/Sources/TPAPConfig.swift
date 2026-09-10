import Foundation

/// Merchant credentials + SDK identifiers Juspay provisions for your account.
///
/// Values are read at runtime from **`Config/Secrets.json`**, which is bundled
/// as an app resource and **not** committed to git. If the file is absent or a
/// value is blank, a harmless placeholder is used (the SDK calls will fail
/// obviously rather than the build breaking).
///
/// Set it up: `cp Config/Secrets.example.json Config/Secrets.json`, fill in the
/// real values, then `make gen` (+ `pod install`).
enum TPAPConfig {

    // MARK: - Secrets.json loader

    private static let root: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            NSLog("[TPAPConfig] Config/Secrets.json not bundled — using placeholders. See Config/Secrets.example.json")
            return [:]
        }
        return obj
    }()

    private static func string(_ key: String, default fallback: String) -> String {
        guard let v = root[key] as? String, !v.isEmpty else { return fallback }
        return v
    }

    // MARK: - Merchant identifiers

    static let clientId               = string("clientId", default: "your_client_id")
    static let merchantId             = string("merchantId", default: "your_merchant_id")
    static let pspMerchantId          = string("pspMerchantId", default: "your_psp_merchant_id")
    static let pspMerchantChannelId   = string("pspMerchantChannelId", default: "your_psp_merchant_channel_id")
    static let tenantId               = string("tenantId", default: "your_tenant_id")

    /// "v1" | "v2" | "v3". v3 → signatures are JWS (RS256).
    static let apiVersion            = string("apiVersion", default: "v3")
    static let betaAssets            = root["betaAssets"] as? Bool ?? false

    /// "sandbox" | "production".
    static let environment          = string("environment", default: "sandbox")

    /// Service the SDK routes on. UPI Plugin **Direct PSP** flows use
    /// `in.juspay.hyperupi`. (Code-level choice, not a secret — stays here.)
    static let service              = "in.juspay.hyperupi"

    /// Issuing PSP handle for the Direct PSP integration (Juspay-provided).
    static let issuingPsp           = string("issuingPsp", default: "YOUR_PSP")

    /// Custom URL scheme this app registers (Info.plist CFBundleURLTypes).
    static let redirectScheme       = string("redirectScheme", default: "upitpaptest")

    // MARK: - Per-environment secrets

    struct EnvCreds {
        let apiKey: String
        let merchantKeyId: String
        /// RSA private key, base64 DER (PKCS#8 or PKCS#1). Whitespace is ignored.
        let privateKey: String
        let kid: String
        let alg: String
    }

    private static func envCreds(_ key: String) -> EnvCreds {
        let d = root[key] as? [String: Any] ?? [:]
        return EnvCreds(
            apiKey:        d["apiKey"] as? String ?? "",
            merchantKeyId: d["merchantKeyId"] as? String ?? "",
            privateKey:    d["privateKey"] as? String ?? "",
            kid:           d["kid"] as? String ?? "",
            alg:           d["alg"] as? String ?? "RSA256"
        )
    }

    static let sandbox    = envCreds("sandbox")
    static let production  = envCreds("production")

    /// Credentials for the currently selected `environment`.
    static var creds: EnvCreds { environment == "production" ? production : sandbox }

    // MARK: - Test customer

    static let testCustomerId       = string("testCustomerId", default: "test_customer_01")
    static let testCustomerMobile   = string("testCustomerMobile", default: "910000000000")

    // MARK: - clientAuthToken auth (alternative to signature)

    static let clientAuthToken      = string("clientAuthToken", default: "")
    static let authExpiry: String?  = root["authExpiry"] as? String
}
