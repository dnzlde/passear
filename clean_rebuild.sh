#!/bin/bash

set -x

flutter clean
pushd ios
rm -rf Pods Podfile.lock build

popd
flutter pub get

pushd ios
pod install

popd
flutter build ios

flutter run --release -d oy

set +x