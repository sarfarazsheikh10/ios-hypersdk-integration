# ThirdParty

Vendored binary frameworks that are **not** checked in (proprietary / licensed).

## CommonLibrary.xcframework  (NPCI Common Library)

Not included in this repo. Obtain it from your NPCI / Juspay contact and drop it
here:

```
ThirdParty/CommonLibrary.xcframework/
```

Both apps already reference it (`- framework: ../ThirdParty/CommonLibrary.xcframework`,
Embed & Sign) in `App-SPM/project.yml` and `App-CocoaPods/project.yml`. After
adding the folder:

```sh
make gen
cd App-CocoaPods && pod install
```

Use it from Swift with `import CommonLibrary`. It must contain both a device
(`ios-arm64`) and a simulator (`ios-arm64_x86_64-simulator`) slice.
