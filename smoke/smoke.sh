#!/usr/bin/env bash
# Smoke-tests a built cpputest-clang image from inside it. It checks the tree a
# bump changes, not any project built on the image: each tool answers, and
# CppUTest builds, links and runs a test with Clang as a position-independent
# executable. See README.md.
#
# Usage, from the repository root:
#   docker run --rm -v "$PWD:/smoke:ro" <image> /smoke/smoke/smoke.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

echo "== tools"
for tool in cc c++ clang clang++ make cmake clang-format clang-tidy cppcheck \
    include-what-you-use lcov gdb gh git; do
    version="$("${tool}" --version 2>&1 | sed -n 1p)" || {
        echo "${tool}: ${version}" >&2
        exit 1
    }
    printf '%-22s %s\n' "${tool}" "${version}"
done

echo "== CppUTest"
clang++ -fPIE -pie "${here}/AllTests.cpp" -I"${CPPUTEST_HOME}/include" \
    -L"${CPPUTEST_HOME}/lib" -lCppUTest -o "${work}/AllTests"
"${work}/AllTests"

echo "== smoke passed"
