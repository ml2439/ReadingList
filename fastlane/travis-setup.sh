#!/bin/sh
# Add git certs HTTPS password to keychain by cloning the certs repo
git config --global credential.helper osxkeychain
git clone https://andrew_bennet:$GIT_CERTS_PASSWORD@bitbucket.org/andrew_bennet/certificates.git
rm -rf certificates
