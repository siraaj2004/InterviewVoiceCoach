#!/bin/bash
set -euo pipefail
xcodegen generate
xcodebuild -project AIInterviewVoice.xcodeproj -scheme AIInterviewVoice -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
APP=$(find build/DerivedData/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' | head -1)
test -n "$APP"
rm -rf build/Payload build/AIInterviewVoice-unsigned.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
cd build && zip -qr AIInterviewVoice-unsigned.ipa Payload && cd ..
ls -lh build/AIInterviewVoice-unsigned.ipa
unzip -l build/AIInterviewVoice-unsigned.ipa | head -20
