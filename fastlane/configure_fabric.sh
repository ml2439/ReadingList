#!/bin/bash

# Configure Fabric (only if we have access to the variables)
if [[ -z $FABRIC_API_KEY ]] || [[ -z $FABRIC_BUILD_SECRET ]]
then
  echo "Fabric variables not defined, not configuring"
else
  /usr/libexec/PlistBuddy -c "Set :Fabric:APIKey $FABRIC_API_KEY" "../ReadingList/Info.plist"
  sed -i '' -e "s|# FABRIC_SCRIPT_PLACEHOLDER|\"\\$\{PODS_ROOT\}/Fabric/run\" $FABRIC_API_KEY $FABRIC_BUILD_SECRET|g" ../project.yml
fi
