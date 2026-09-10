import Foundation

/// Builds the `initiate` and `management` payloads for the
/// **UPI Plugin – Direct PSP** iOS SDK (`service: in.juspay.hyperupi`).
///
/// Envelope:
/// ```
/// { "requestId": "<uuid v4>", "service": "in.juspay.hyperupi",
///   "payload": { "action": "...", ... } }
/// ```
///
/// Docs:
/// - initiate:   https://juspay.io/in/docs/upi-plugin-direct-psp/ios/interaction-with-sdk/initiating-the-sdk
/// - management: https://juspay.io/in/docs/upi-plugin-sdk/ios/process-payloads/upi-management
enum TPAPPayloadFactory {

    private static func envelope(_ inner: [String: Any]) -> [String: Any] {
        ["requestId": UUID().uuidString, "service": TPAPConfig.service, "payload": inner]
    }

    // MARK: - initiate  (Direct PSP)

    /// Customer-scoped initiate. Signs `{merchant_id, customer_id, timestamp}`
    /// (v3 → JWS parts; v2 → signaturePayload string + signature + merchantKeyId;
    /// v1 → clientAuthToken).
    static func initiatePayload(customerId: String = TPAPConfig.testCustomerId) -> [String: Any] {
        var inner: [String: Any] = [
            "action": "initiate",
            "clientId": TPAPConfig.clientId,
            "merchantId": TPAPConfig.merchantId,
            "customerId": customerId,
            "environment": TPAPConfig.environment,
            "issuingPsp": TPAPConfig.issuingPsp,
            "merchantLoader": false
        ]
        for (k, v) in authFields(customerId: customerId) { inner[k] = v }
        return envelope(inner)
    }

    // MARK: - process: UPI Management

    /// UPI Management screen (linked accounts, VPAs, UPI PIN, deregister).
    /// `action: "management"` + signature auth.
    static func managementPayloadSignature(customerId: String = TPAPConfig.testCustomerId,
                                           shouldExitOnDeregister: Bool = false) -> [String: Any] {
        var inner: [String: Any] = [
            "action": "management",
            "shouldExitOnDeregister": shouldExitOnDeregister
        ]
        for (k, v) in signatureAuthFields(customerId: customerId) { inner[k] = v }
        return envelope(inner)
    }

    /// UPI Management screen + `clientAuthToken` auth (backend-minted token
    /// instead of a client-side signature).
    static func managementPayloadToken(customerId: String = TPAPConfig.testCustomerId,
                                       clientAuthToken: String = TPAPConfig.clientAuthToken,
                                       authExpiry: String? = TPAPConfig.authExpiry,
                                       shouldExitOnDeregister: Bool = false) -> [String: Any] {
        var inner: [String: Any] = [
            "action": "management",
            "merchantId": TPAPConfig.merchantId,
            "customerId": customerId,
            "clientAuthToken": clientAuthToken,
            "shouldExitOnDeregister": shouldExitOnDeregister
        ]
        if let authExpiry { inner["authExpiry"] = authExpiry }
        return envelope(inner)
    }

    // MARK: - auth field builders

    /// initiate auth: prefers `clientAuthToken` when configured, else signature.
    private static func authFields(customerId: String) -> [String: Any] {
        if !TPAPConfig.clientAuthToken.isEmpty {
            return ["clientAuthToken": TPAPConfig.clientAuthToken]
        }
        return signatureAuthFields(customerId: customerId)
    }

    /// `{merchant_id, customer_id, timestamp}` signed with the merchant key.
    /// v3 → `enableJwsAuth` + `protected` + `signaturePayload` + `signature`;
    /// v1/v2 → `signaturePayload` (raw JSON) + `signature` + `merchantKeyId`.
    private static func signatureAuthFields(customerId: String) -> [String: Any] {
        let signed = jsonString([
            "merchant_id": TPAPConfig.merchantId,
            "customer_id": customerId,
            "timestamp": String(Int(Date().timeIntervalSince1970 * 1000))
        ])

        if TPAPConfig.apiVersion == "v3" {
            guard let jws = UPISignature.jwsRS256(payload: signed,
                                                 privateKeyBase64: TPAPConfig.creds.privateKey,
                                                 kid: TPAPConfig.creds.kid) else { return [:] }
            return [
                "enableJwsAuth": true,
                "protected": jws.protectedHeader,
                "signaturePayload": jws.payload,
                "signature": jws.signature
            ]
        }

        return [
            "signaturePayload": signed,
            "signature": UPISignature.pkcs1v15SHA256(payload: signed,
                                                    privateKeyBase64: TPAPConfig.creds.privateKey),
            "merchantKeyId": TPAPConfig.creds.merchantKeyId
        ]
    }

    // MARK: - helpers

    private static func jsonString(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
