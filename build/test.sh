#! /bin/bash
set -e

xcodebuild \
  -workspace ReadingList.xcworkspace \
  -scheme ReadingList \
  -destination 'platform=iOS Simulator,name=iPhone 7,OS=10.3.1' \
  -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.4' \
  -destination 'platform=iOS Simulator,name=iPhone XS,OS=12.1' \
  -destination 'platform=iOS Simulator,name=iPad Pro (10.5-inch),OS=11.4' \
  test | xcbeautify