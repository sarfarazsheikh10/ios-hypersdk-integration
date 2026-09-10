import Foundation
import Security

/// Local signing of the `signaturePayload` for Hyper SDK auth.
///
/// ⚠️ For a **test app only**. In production the private key never ships in the
/// client — your backend signs `signaturePayload` and returns `signature`
/// (v1/v2) or the JWS parts (v3). This mirrors what that backend does so the
/// sandbox flow is self-contained.
///
/// - v1 / v2: `RSASSA-PKCS1-v1_5` over SHA-256 of the raw payload string,
///   base64. Sent as `signature` + `signaturePayload` + `merchantKeyId`.
/// - v3: compact JWS (RS256). Sent as `protected` + `signaturePayload`
///   (= base64url payload) + `signature` (= base64url signature).
enum UPISignature {

    // MARK: v1 / v2

    /// Returns base64 `signature` for the given payload string, or "" on failure.
    static func pkcs1v15SHA256(payload: String, privateKeyBase64: String) -> String {
        guard let key = secKey(fromBase64: privateKeyBase64),
              let data = payload.data(using: .utf8) else { return "" }
        var error: Unmanaged<CFError>?
        guard let sig = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256,
                                              data as CFData, &error) as Data? else {
            NSLog("[UPISignature] sign failed: %@", String(describing: error))
            return ""
        }
        return sig.base64EncodedString()
    }

    // MARK: v3 (JWS RS256)

    struct JWSParts { let protectedHeader: String; let payload: String; let signature: String }

    /// Builds a compact JWS (RS256) over `base64url(header).base64url(payload)`
    /// and returns the three parts split out (as the SDK payload expects them).
    static func jwsRS256(payload: String, privateKeyBase64: String, kid: String) -> JWSParts? {
        let header: [String: String] = ["alg": "RS256", "kid": kid]
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = payload.data(using: .utf8),
              let key = secKey(fromBase64: privateKeyBase64) else { return nil }

        let protectedB64 = base64URL(headerData)
        let payloadB64 = base64URL(payloadData)
        let signingInput = "\(protectedB64).\(payloadB64)"

        guard let signingData = signingInput.data(using: .ascii) else { return nil }
        var error: Unmanaged<CFError>?
        guard let sig = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256,
                                              signingData as CFData, &error) as Data? else {
            NSLog("[UPISignature] JWS sign failed: %@", String(describing: error))
            return nil
        }
        return JWSParts(protectedHeader: protectedB64, payload: payloadB64, signature: base64URL(sig))
    }

    // MARK: - helpers

    private static func secKey(fromBase64 b64: String) -> SecKey? {
        guard let der = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return nil }
        let pkcs1 = pkcs1KeyData(from: der)   // iOS SecKey needs bare PKCS#1
        return SecKeyCreateWithData(pkcs1 as NSData,
                                    [kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                     kSecAttrKeyClass: kSecAttrKeyClassPrivate] as NSDictionary,
                                    nil)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// If `der` is a PKCS#8 `PrivateKeyInfo` wrapper (backend / Android format,
    /// `MIIEv…`), returns the inner PKCS#1 `RSAPrivateKey`; otherwise returns
    /// `der` unchanged. `SecKeyCreateWithData` rejects PKCS#8 with errSecParam.
    static func pkcs1KeyData(from der: Data) -> Data {
        let b = [UInt8](der)
        var idx = 0
        func readLen() -> Int? {
            guard idx < b.count else { return nil }
            let first = b[idx]; idx += 1
            if first & 0x80 == 0 { return Int(first) }
            let n = Int(first & 0x7f)
            guard n >= 1, n <= 4, idx + n <= b.count else { return nil }
            var len = 0
            for _ in 0..<n { len = (len << 8) | Int(b[idx]); idx += 1 }
            return len
        }
        func expect(_ tag: UInt8) -> Bool {
            guard idx < b.count, b[idx] == tag else { return false }
            idx += 1
            return true
        }
        // PKCS#8: SEQ { INTEGER version, SEQ AlgorithmIdentifier, OCTET STRING key }
        guard expect(0x30), readLen() != nil else { return der }
        guard expect(0x02), let vlen = readLen() else { return der }
        idx += vlen
        guard expect(0x30), let alen = readLen() else { return der }
        idx += alen
        guard expect(0x04), let olen = readLen(), idx + olen <= b.count else { return der }
        return der.subdata(in: idx..<(idx + olen))
    }
}
