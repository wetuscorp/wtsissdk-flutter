#!/usr/bin/env bash
set -euo pipefail

version=$(sed -n 's/^version: //p' pubspec.yaml)
test "$version" = "0.5.0-alpha.1" || { echo "Unexpected wrapper version: $version" >&2; exit 1; }
grep -Fq "implementation 'co.wetus:wts-sdk:${version}'" android/build.gradle
grep -Fq "s.dependency 'WtsSDK', '${version}'" ios/wts_sdk.podspec
grep -Fq "exact: \"${version}\"" ios/wts_sdk/Package.swift
