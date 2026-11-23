#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/regression
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror -Isrc tests/key_sequence_test.cpp -o build/regression/key_sequence_test
build/regression/key_sequence_test

if [[ "$(uname -s)" == Darwin ]]; then
  swiftc macos/Sources/Core/{FilterEngine,Settings,AutoStartManager}.swift tests/macos/main.swift \
    -o build/regression/macos_test
  build/regression/macos_test
fi
