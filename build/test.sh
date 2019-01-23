#! /bin/bash
set -e
bundle exec fastlane test
#env NSUnbufferedIO=YES \
# xcodebuild \
#  -workspace ReadingList.xcworkspace \
#  -scheme ReadingList \
#  -destination 'platform=iOS Simulator,id=839D5DB2-32BD-4484-AC84-A75180CF8FB4' \
#  -destination 'platform=iOS Simulator,id=D6E41B94-1BD3-45F8-B478-530FDE38E6B0' \
#  -destination 'platform=iOS Simulator,id=B40F7090-26EE-4D2E-A7A2-C13E10EDA669' \
#  -destination 'platform=iOS Simulator,id=C339A636-603E-425D-82B2-6FD8A064D2E6' \
#  build test | mint run thii/xcbeautify
