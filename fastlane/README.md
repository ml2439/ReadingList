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
Run tests
### ios beta
```
fastlane ios beta
```
Increments the build number, commits with a special commit message to trigger CI deploy
### ios deploy
```
fastlane ios deploy
```
Push a new beta build to TestFlight (not externally released)
### ios dsyms
```
fastlane ios dsyms
```
Download DSYMs from iTunes and upload them to Crashlytics
### ios patch
```
fastlane ios patch
```

### ios minor
```
fastlane ios minor
```

### ios major
```
fastlane ios major
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
