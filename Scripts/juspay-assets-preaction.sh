#!/bin/sh
# Reference copy of the Juspay Assets Plugin build pre-action for the SPM app.
#
# You normally do NOT run this by hand. It is already wired into the SPM app's
# scheme by `App-SPM/project.yml` (scheme.preActions) and runs on every
# "Clean Build Folder". Kept here so it is reviewable / diff-able.
#
# Source: https://github.com/juspay/hypersdk-ios  (README, verbatim)

PACKAGE_DIR="${BUILD_DIR%Build/*}SourcePackages/artifacts/hypersdk-ios/HyperSDK"
XCFRAMEWORK_DIR="${PACKAGE_DIR}/HyperSDK.xcframework"
FUSE_SCRIPT="${PACKAGE_DIR}/Fuse.rb"
FUSE_MARKER="${XCFRAMEWORK_DIR}/.fuse_completed"
VALIDATION_SCRIPT="${PACKAGE_DIR}/ValidateHyperSDK.rb"

[ ! -f "$FUSE_MARKER" ] || [ "${ACTION}" == "clean" ] && { cd "${PROJECT_DIR}"; echo "Running Fuse.rb script..."; ruby "$FUSE_SCRIPT"; }

ruby "$VALIDATION_SCRIPT" && touch "$FUSE_MARKER" || exit 1
