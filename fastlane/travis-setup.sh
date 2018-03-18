#!/bin/sh
fastlane actions setup_travis

# Add git certs HTTPS password to keychain by cloning the certs repo
git config --global credential.helper osxkeychain
git clone https://andrew_bennet:$GIT_CERTS_PASSWORD@bitbucket.org/andrew_bennet/certificates.git
rm -rf certificates

# Travis workaround described in: https://docs.travis-ci.com/user/common-build-problems/#Mac%3A-macOS-Sierra-(10.12)-Code-Signing-Errors
security set-key-partition-list -S apple-tool:,apple: -s -k $MATCH_KEYCHAIN_PASSWORD $MATCH_KEYCHAIN_NAME
