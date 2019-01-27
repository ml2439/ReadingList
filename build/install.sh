#! /bin/bash
set -e

bundle install
brew install mint
mint run yonaskolb/xcodegen

if ! bundle exec pod install; then
	bundle exec pod install --repo-update
fi