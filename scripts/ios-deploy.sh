#!/bin/bash
set -e

xcodebuild -quiet -workspace data.xcworkspace -scheme data build

# ios-deploy --debug --uninstall --bundle DerivedData/data/Build/Products/Debug-iphoneos/data.app
ios-deploy --uninstall --bundle DerivedData/data/Build/Products/Debug-iphoneos/data.app

