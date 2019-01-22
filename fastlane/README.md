fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
## iOS
### ios test
```
fastlane ios test
```

### ios deploy
```
fastlane ios deploy
```
Push a new beta build to TestFlight (not externally released)
### ios publish
```
fastlane ios publish
```

### ios snaps
```
fastlane ios snaps
```
Create framed screenshots for a range of devices
### ios dsyms
```
fastlane ios dsyms
```
Download DSYMs from iTunes and upload them to Crashlytics
### ios reset_build_number
```
fastlane ios reset_build_number
```

### ios patch
```
fastlane ios patch
```
Create a commit incrementing the patch number
### ios minor
```
fastlane ios minor
```
Create a commit incrementing the minor version number
### ios major
```
fastlane ios major
```
Create a commit incrementing the major version number

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
