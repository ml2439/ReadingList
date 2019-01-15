#! /bin/bash

bundle install > /dev/null

if [ "${TRAVIS_SECURE_ENV_VARS}" == "true" ]
then
  /usr/libexec/PlistBuddy -c "Set :Fabric:APIKey $FABRIC_API_KEY" "ReadingList/Info.plist"
  echo "\"\${PODS_ROOT}/Fabric/run\" $FABRIC_API_KEY $FABRIC_BUILD_SECRET" > fastlane/fabric.sh
else
  echo "No access to secure variables; not configuring Fabric"
fi

brew install mint
mint run yonaskolb/xcodegen

pod repo update > /dev/null
pod install
