#!/usr/bin/env bash
# Smoke-tests a built cpputest-clang image from inside it. It checks the tree a
# bump changes, not any project built on the image: each tool answers, and
# CppUTest builds, links and runs a test with Clang as a position-independent
# executable; the trees copied from cpputest-freertos are each named by a
# variable; and both wolfSSL libraries link and run from Clang. See README.md.
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

echo "== upstream trees"
tree_variables=(FREERTOS_KERNEL_PATH FREERTOS_PLUS_TCP_PATH FREERTOS_PLUS_FAT_PATH
    LWIP_PATH FATFS_PATH LITTLEFS_PATH MBEDTLS_DIR WOLFSSL_DIR WOLFSSL_BASELINE_DIR
    WOLFSSL_SOURCE_DIR CMSIS_PATH CMSIS_FREERTOS_PATH)
named=()
for variable in "${tree_variables[@]}"; do
    path="${!variable:-}"
    if [ -z "${path}" ] || [ ! -d "${path}" ]; then
        echo "${variable} does not name a directory: '${path}'" >&2
        exit 1
    fi
    printf '%-22s %s\n' "${variable}" "${path}"
    named+=("${path}")
done

# A tree cpputest-freertos adds arrives through the copy whether or not this
# image names it, and a tree nothing names switches no pack on. /opt/freertos
# holds trees rather than being one.
for path in /opt/* /opt/freertos/*; do
    [ "${path}" = /opt/freertos ] && continue
    found=no
    for candidate in "${named[@]}"; do
        [ "${candidate}" = "${path}" ] && found=yes
    done
    if [ "${found}" = no ]; then
        echo "${path} was copied in but no variable names it" >&2
        exit 1
    fi
done

echo "== wolfSSL from Clang"
cat > "${work}/wolfssl.c" <<'SOURCE'
#include <wolfssl/options.h>
#include <wolfssl/ssl.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    int ok = (wolfSSL_Init() == WOLFSSL_SUCCESS) &&
             (strcmp(wolfSSL_lib_version(), LIBWOLFSSL_VERSION_STRING) == 0);
    printf("%s\n", wolfSSL_lib_version());
    wolfSSL_Cleanup();
    return ok ? 0 : 1;
}
SOURCE
source_version="$(grep LIBWOLFSSL_VERSION_STRING "${WOLFSSL_SOURCE_DIR}/wolfssl/version.h")"
for install in "${WOLFSSL_DIR}" "${WOLFSSL_BASELINE_DIR}"; do
    library_version="$(grep LIBWOLFSSL_VERSION_STRING "${install}/include/wolfssl/version.h")"
    if [ "${library_version}" != "${source_version}" ]; then
        echo "${install} is ${library_version}, the source tree ${source_version}" >&2
        exit 1
    fi
    clang -Werror -I"${install}/include" "${work}/wolfssl.c" \
        "${install}/lib/libwolfssl.a" -lm -lpthread -o "${work}/wolfssl"
    printf '%-22s ' "${install}"
    "${work}/wolfssl"
done

echo "== smoke passed"
