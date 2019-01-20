#! /bin/bash

bundle install > /dev/null

# Configure Fabric (only if we have access to the variables)
if [ "${TRAVIS_SECURE_ENV_VARS}" == "true" ]
then
  /usr/libexec/PlistBuddy -c "Set :Fabric:APIKey $FABRIC_API_KEY" "ReadingList/Info.plist"
  echo "\"\${PODS_ROOT}/Fabric/run\" $FABRIC_API_KEY $FABRIC_BUILD_SECRET" > build/fabric.sh
else
  echo "No access to secure variables; not configuring Fabric"
fi

# Set the build number to the commit count
git=$(sh /etc/profile; which git)
number_of_commits=$("$git" rev-list HEAD --count)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number_of_commits" "ReadingList/Info.plist"

brew install mint
mint run yonaskolb/xcodegen

pod repo update > /dev/null
pod install
