# UPI TPAP test app — setup helpers
# Requires: xcodegen (brew install xcodegen), cocoapods (gem install cocoapods)

.PHONY: setup gen pods open clean

setup: gen pods
	@echo ""
	@echo "Done. Open UPITpapTestApp.xcworkspace and pick a scheme:"
	@echo "  • UPITpapTestApp-SPM   — HyperSDK via Swift Package Manager"
	@echo "  • UPITpapTestApp-Pods  — HyperSDK via CocoaPods"

# NOTE: always `gen` BEFORE `pods`. Running `gen` again after `pod install`
# overwrites the CocoaPods xcconfig on the Pods app — re-run `make pods` to fix.
gen:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found — run: brew install xcodegen"; exit 1; }
	cd App-SPM && xcodegen generate
	cd App-CocoaPods && xcodegen generate

pods:
	cd App-CocoaPods && pod install

open:
	open UPITpapTestApp.xcworkspace

clean:
	rm -rf App-SPM/UPITpapTestApp-SPM.xcodeproj \
	       App-CocoaPods/UPITpapTestApp-Pods.xcodeproj \
	       App-CocoaPods/Pods App-CocoaPods/Podfile.lock
