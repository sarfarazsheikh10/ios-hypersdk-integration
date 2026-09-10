# iOS HyperSDK Integration

A minimal iOS test harness for Juspay's **Hyper SDK** (UPI TPAP / UPI Plugin –
Direct PSP), wired up **both ways** — Swift Package Manager *and* CocoaPods —
from a single shared codebase.

Reference docs:
- UPI TPAP SDK — iOS integration architecture: <https://juspay.io/in/docs/upi-tpap-sdk/ios/overview/integration-architecture>
- Hyper base SDK — getting the SDK (SPM + CocoaPods): <https://juspay.io/in/docs/hyper-checkout/ios/base-sdk-integration/1-getting-sdk>

---

## Why it's laid out this way

You **cannot** put both SPM and CocoaPods copies of the Hyper SDK into the same
target — you'd link the framework twice (duplicate symbols) and the two Assets
Plugin hooks would collide. So there are **two app targets**, one per dependency
manager, and they **share every line of app code**:

```
ios-hypersdk-integration/
├── UPITpapTestApp.xcworkspace/   ← open this; contains both app projects (+ Pods)
├── Shared/Sources/               ← ALL app + SDK-integration code (compiled by BOTH apps)
│   ├── AppDelegate.swift  SceneDelegate.swift
│   ├── HyperSDKManager.swift     ← HyperServices(tenantId:clientId:) wrapper: initiate / management ×2 / terminate
│   ├── TPAPPayloadFactory.swift  ← builds the Direct-PSP initiate + the two management payloads
│   ├── UPISignature.swift        ← local RSA / JWS signing of signaturePayload (test-app only)
│   ├── TPAPTestViewController.swift  ← 4 buttons + live log
│   ├── TPAPConfig.swift          ← reads Config/Secrets.json at runtime (placeholders if absent)
│   └── Log.swift
│
├── Config/
│   ├── Secrets.example.json      ← template (committed)
│   └── Secrets.json              ← real values (git-ignored; bundled into both apps)  ← CREATE THIS
│
├── App-SPM/                      ← HyperSDK + HyperUPI + HyperQR via Swift Package Manager
│   ├── project.yml                 (XcodeGen spec: 3 SPM packages + scheme pre-action)
│   ├── MerchantConfig.json         (next to the .xcodeproj — Assets Plugin reads it)
│   └── Resources/Info.plist
│
├── App-CocoaPods/                ← HyperSDK + HyperUPI + HyperQR via CocoaPods
│   ├── project.yml                 (XcodeGen spec, no SDK dep — Podfile adds it)
│   ├── Podfile                     (pod 'HyperSDK' / 'HyperUPI' / 'HyperQR' + Fuse.rb)
│   ├── MerchantConfig.json
│   └── Resources/Info.plist
│
├── ThirdParty/                     (vendored binaries — NOT in git; see ThirdParty/README.md)
│   └── CommonLibrary.xcframework    ← you supply this; both apps link + embed it
├── Scripts/juspay-assets-preaction.sh   (reference copy of the SPM pre-action)
└── Makefile
```

The `.xcodeproj` files are **generated** by [XcodeGen](https://github.com/yonyz/XcodeGen)
from the `project.yml` specs, so they're git-ignored. Regenerate any time with
`make gen`.

---

## First-time setup

```sh
brew install xcodegen          # if not already installed
sudo gem install cocoapods     # if not already installed

cd ios-hypersdk-integration
make setup                     # = make gen + make pods
open UPITpapTestApp.xcworkspace
```

Then, in the workspace, choose the scheme:

| Scheme | Integration | Notes |
|---|---|---|
| `UPITpapTestApp-SPM`  | Swift Package Manager | Assets Plugin runs as a **scheme Build pre-action**. First build must be a **Clean Build Folder** (⇧⌘K) so assets download. |
| `UPITpapTestApp-Pods` | CocoaPods | Assets Plugin (`Fuse.rb`) runs in the Podfile **`post_install`**. Re-run `pod install` after changing the version. |

---

## Before it will actually run

1. **`Config/Secrets.json`** — `cp Config/Secrets.example.json Config/Secrets.json`
   and fill in `clientId`, `merchantId`, `tenantId`, `pspMerchantId` /
   `pspMerchantChannelId`, `issuingPsp`, and the sandbox `apiKey` /
   `merchantKeyId` / RSA `privateKey` / `kid`. `TPAPConfig` reads it at runtime;
   the file is git-ignored. See **Secrets** below.
2. **`App-SPM/MerchantConfig.json`** and **`App-CocoaPods/MerchantConfig.json`** —
   the `clientConfigs` key must equal `TPAPConfig.clientId`. The
   build-time Assets Plugin uses it to fetch your merchant bundle; it needs
   network access to Juspay's asset CDN and a client whose sandbox assets you're
   entitled to — otherwise the build fails at the HyperSDK "Validate Mandatory
   Files" step with a `400` on `assets.zip`.
3. **Versions** — three modules, kept on one version each side:
   `App-SPM/project.yml` pins `HyperSDK` / `HyperUPI` / `HyperQR` at
   `exactVersion: "2.2.9"`; `App-CocoaPods/Podfile` pins all three at `2.2.9.2`
   via the `hyper_sdk_version` var. Change to whatever Juspay gave you (see
   "Changing the HyperSDK version" below).
4. **Signing** — set your team on each app target (or `CODE_SIGN_STYLE` /
   `DEVELOPMENT_TEAM` in the `project.yml` `settings`).
5. **URL scheme** — the apps register `upitpaptest://` for PSP/bank redirects;
   change it in `TPAPConfig.swift` **and** both `Info.plist` files if you need a
   different one. `LSApplicationQueriesSchemes` lists common UPI apps; the Assets
   Plugin injects more at build time.

---

## Secrets

Credentials live in **`Config/Secrets.json`**, which is **git-ignored**.
`TPAPConfig` reads it from the app bundle at runtime; if it's missing or a value
is blank, harmless placeholders are used (SDK calls fail obviously, the build
doesn't).

```sh
cp Config/Secrets.example.json Config/Secrets.json
# fill in real values, then:
make gen && (cd App-CocoaPods && pod install)
```

`Config/Secrets.json` (from `Secrets.example.json`):

| Field | |
|---|---|
| `clientId` `merchantId` `pspMerchantId` `pspMerchantChannelId` `tenantId` | merchant identifiers |
| `apiVersion` `environment` `issuingPsp` `betaAssets` `redirectScheme` | SDK config |
| `sandbox` / `production` → `apiKey` `merchantKeyId` `privateKey` `kid` `alg` | per-env secrets |
| `testCustomerId` `testCustomerMobile` `clientAuthToken` `authExpiry` | test customer |

It's added to both targets as an **optional** bundled resource
(`- path: ../Config/Secrets.json` in each `project.yml`) so `xcodegen` and
builds still work on a clone that doesn't have it.

**Still hand-maintained separately:** `App-SPM/MerchantConfig.json` and
`App-CocoaPods/MerchantConfig.json` — the Fuse asset plugin reads these at
`pod install` / pre-action time (outside Swift), so keep their `clientId` /
`tenantName` in sync with `Secrets.json`.

The RSA signing in `UPISignature.swift` is a **test-app shortcut** — in
production the private key never ships in the client; your backend signs.

`ThirdParty/CommonLibrary.xcframework` is git-ignored — see `ThirdParty/README.md`.

---

## Changing the HyperSDK version

Three modules — `HyperSDK`, `HyperUPI` (UPI TPAP plugin,
<https://github.com/juspay/hyperupi-ios>) and `HyperQR` (QR plugin,
<https://github.com/juspay/hyperqr-ios>) — are pinned per app. Keep all three on
the **same release** on each side. The SPM git tag has 3 components (`2.2.9`),
the CocoaPods release has 4 (`2.2.9.2`) — they map to the same release but won't
be literally equal.

### SPM app

1. Edit `App-SPM/project.yml` — update the `exactVersion` on all three packages:
   ```yaml
   packages:
     HyperSDK:
       url: https://github.com/juspay/hypersdk-ios.git
       exactVersion: "2.3.0"     # ← new git tag
     HyperUPI:
       url: https://github.com/juspay/hyperupi-ios.git
       exactVersion: "2.3.0"
     HyperQR:
       url: https://github.com/juspay/hyperqr-ios.git
       exactVersion: "2.3.0"
       # or, to always take latest:  branch: main   (remove exactVersion)
   ```
2. Regenerate the project and re-resolve packages:
   ```sh
   make gen        # or: cd App-SPM && xcodegen generate
   cd App-SPM && xcodebuild -resolvePackageDependencies \
       -project UPITpapTestApp-SPM.xcodeproj -scheme UPITpapTestApp-SPM
   ```
   (Opening the workspace in Xcode also resolves automatically.)
3. In Xcode: **Product → Clean Build Folder** (⇧⌘K), then build. The scheme
   pre-action re-runs `Fuse.rb` and re-downloads assets for the new version.

### CocoaPods app

1. Edit `App-CocoaPods/Podfile` — the one `hyper_sdk_version` var feeds all
   three pods (`HyperSDK`, `HyperUPI`, `HyperQR`):
   ```ruby
   hyper_sdk_version = '2.3.0.1'   # ← CocoaPods 4-part version
   ```
2. Reinstall:
   ```sh
   cd App-CocoaPods && pod install
   ```
   `post_install` re-runs `Fuse.rb`. Confirm the log shows the new
   `[HyperSDK] HyperSDK version - …`.
3. Commit the updated `Podfile.lock` if you decide to track it (git-ignored by
   default).

### Notes

- `HyperCore` (the transitive dependency) is pinned inside HyperSDK's own
  `Package.swift` / podspec — you don't set it; it moves when you bump HyperSDK.
- Update the version numbers in the **"Before it will actually run"** section
  above too, so this README stays accurate.

---

## What the test screen does

This is the **UPI Plugin – Direct PSP** flow (`service: in.juspay.hyperupi`).
`TPAPTestViewController` has four buttons; every payload + callback event is
streamed to the on-screen log.

| Button | Calls | Payload |
|---|---|---|
| **1 · Initiate SDK** | `HyperSDKManager.initiate(from:)` | `TPAPPayloadFactory.initiatePayload()` |
| **2 · UPI Management — Signature** | `openUPIManagementSignature()` | `managementPayloadSignature()` |
| **3 · UPI Management — Auth Token** | `openUPIManagementToken()` | `managementPayloadToken()` |
| **Terminate** | `terminate()` | — |

`HyperServices` is constructed tenant + client scoped:

```swift
let hyper = HyperServices(tenantId: TPAPConfig.tenantId, clientId: TPAPConfig.clientId)
```

**Plugins:** `HyperUPI` and `HyperQR` have no separate Swift API here — you just
link them; `HyperSDK` discovers them at runtime. Nothing to `import` in app code.

**NPCI Common Library:** `ThirdParty/CommonLibrary.xcframework` is **not in this
repo** (proprietary). Both apps already reference it via `- framework:` in each
`project.yml` (Embed & Sign); supply the folder yourself per
`ThirdParty/README.md`, then `make gen` + `pod install`. Use it from Swift with
`import CommonLibrary`. CL is version-locked to a matching NPCI backend/config.

---

## Initiate — Direct PSP

Doc: <https://juspay.io/in/docs/upi-plugin-direct-psp/ios/interaction-with-sdk/initiating-the-sdk>

Customer-scoped and signed at initiate time:

```jsonc
{
  "requestId": "<uuid>",
  "service": "in.juspay.hyperupi",
  "payload": {
    "action": "initiate",
    "clientId": "<your clientId>",
    "merchantId": "<your merchantId>",
    "customerId": "<your ref>",
    "environment": "sandbox",
    "issuingPsp": "<YOUR_PSP>",       // TPAPConfig.issuingPsp — your bank's handle
    "merchantLoader": false,
    // auth: v3 (JWS RS256, from TPAPConfig.apiVersion) —
    "enableJwsAuth": true,
    "protected":        "<base64url {alg:RS256, kid}>",
    "signaturePayload": "<base64url signed JSON>",
    "signature":        "<base64url RS256 signature>"
    // v1/v2 instead: signaturePayload (raw JSON) + signature + merchantKeyId
    // clientAuthToken set? -> "clientAuthToken": "<token>" replaces the signature fields
  }
}
```

Signed JSON (before encoding): `{ "merchant_id": "<your merchantId>", "customer_id": "<ref>", "timestamp": "<ms>" }`.

---

## UPI Management — two process payloads

Doc: <https://juspay.io/in/docs/upi-plugin-sdk/ios/process-payloads/upi-management>

One `process` call, `action: "management"`, made **after** a successful initiate.
Opens the SDK-managed screen (linked bank accounts, VPAs, set / change UPI PIN,
deregister). Two auth variants — the two buttons:

**Signature** (`managementPayloadSignature()`):

```jsonc
"payload": {
  "action": "management",
  "shouldExitOnDeregister": false,
  "enableJwsAuth": true,
  "protected": "…", "signaturePayload": "…", "signature": "…"   // v3 JWS
  // v1/v2: signaturePayload (raw JSON) + signature + merchantKeyId
}
```

**Auth Token** (`managementPayloadToken()` — set `TPAPConfig.clientAuthToken`):

```jsonc
"payload": {
  "action": "management",
  "merchantId": "<your merchantId>",
  "customerId": "<your ref>",
  "clientAuthToken": "<backend-minted token>",
  "authExpiry": "<ISO-8601, optional>",
  "shouldExitOnDeregister": false
}
```

### Signing

`Shared/Sources/UPISignature.swift` signs `{merchant_id, customer_id, timestamp}`
locally with the sandbox `privateKey` — RSA `PKCS1v15-SHA256`, wrapped as a
compact JWS when `apiVersion == "v3"`. PKCS#8 keys (`MIIEv…`) are unwrapped to
PKCS#1 for iOS's `SecKey`.

> ⚠️ **Test-app only.** In production the private key never ships in the client —
> your backend produces the signature / JWS (or mints the `clientAuthToken`) and
> the app just forwards it. Swap `UPISignature` for a call to that endpoint.

---

## Common issues

| Symptom | Fix |
|---|---|
| `No such module 'HyperSDK'` (SPM) | Let package resolution finish, then **Clean Build Folder**. |
| Assets / bundle not found at runtime | `clientId` in `TPAPConfig.swift` ≠ `MerchantConfig.json`, or first build wasn't a clean build. |
| `Fuse.rb not found` during `pod install` | The `HyperSDK` pod/version didn't resolve — check the version and your CocoaPods spec source access. |
| `Unable to resolve module dependency: 'HyperSDK'` (Pods app) | You ran `xcodegen generate` **after** `pod install`, wiping the CocoaPods xcconfig. Always regenerate first, then `pod install`. Fix: `cd App-CocoaPods && pod install`. |
| Build fails at `[CP-User] Validate Mandatory Files` / `Required files are missing in HyperSDK.xcframework` / `400` on `assets.zip` | OTA assets didn't download. Needs network access to Juspay's asset CDN and a `clientId` whose sandbox assets your account is entitled to. Not a code issue. |
| Duplicate symbols / `HyperSDK` linked twice | You added the SPM package to the Pods app (or vice-versa). Keep each manager in its own target. |
| `Multiple commands produce '…/Info.plist'` | `Info.plist` got into the resources copy phase — it's `excludes:`d in each `project.yml`; regenerate. |
| `No such module 'CommonLibrary'` | `ThirdParty/CommonLibrary.xcframework` missing, or you ran the Pods app project directly instead of the workspace / didn't `make gen` after cloning. |
| `building for iOS Simulator, but linking … CommonLibrary … built for iOS` | Using an xcframework with no simulator slice. This one has `ios-arm64_x86_64-simulator`; if you swap it, keep a simulator slice. |
| `make: *** missing separator` | Makefile recipe lines must be TAB-indented. |
