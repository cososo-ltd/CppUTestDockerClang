# CppUTest Docker (Clang)

A base Docker image for TDD development with Clang and [CppUTest](http://cpputest.github.io/).
Companion to [CppUTestDocker](https://github.com/cososo-ltd/CppUTestDocker), which provides the GCC variant.

## Contents

- Clang 19 from Debian trixie (the `debian:trixie-slim` base image), set as `cc` and `c++`
- CppUTest v4.0 (compiled with Clang, `-fPIC` for PIE-compatible linking)
- clang-format 19
- clang-tidy 19
- include-what-you-use 0.23 (built from source against clang-19; matched ABI is required for correct suggestions)
- CMake
- cppcheck
- gdb, lcov
- [GitHub CLI (`gh`)](https://cli.github.com/)
- [James Grenning's legacy-build toolkit](https://github.com/jwgrenning/legacy-build)
- The upstream source trees and the two wolfSSL builds that
  [CppUTestFreertosDocker](https://github.com/cososo-ltd/CppUTestFreertosDocker)'s
  host image carries, copied from it at the same paths under `/opt` with the same
  variables: `FREERTOS_KERNEL_PATH`, `FREERTOS_PLUS_TCP_PATH`,
  `FREERTOS_PLUS_FAT_PATH`, `LWIP_PATH`, `FATFS_PATH`, `LITTLEFS_PATH`,
  `MBEDTLS_DIR`, `WOLFSSL_DIR`, `WOLFSSL_BASELINE_DIR`, `WOLFSSL_SOURCE_DIR`,
  `CMSIS_PATH` and `CMSIS_FREERTOS_PATH`

## Where the upstream pins live

The upstream trees are not pinned here. The dockerfile's first stage is the
`cpputest-freertos` host image, pinned by digest, and the image takes its `/opt`
whole, so a Clang build and a GCC build of a project see the same upstream
releases. The tag and SHA of each upstream, and the Renovate rules that move
them, are in CppUTestFreertosDocker alone.

The wolfSSL libraries are the GCC builds that image inherits from the
`cpputest` base. They are static C libraries, which link the same from Clang;
what this image checks is the code compiled against them, and that is compiled
with Clang.

## Keeping the pins current

[Renovate](https://docs.renovatebot.com/), installed on the organisation as
the Mend GitHub App, opens a pull request when the digest either `FROM` line
pins moves - `debian:trixie-slim`, or `cpputest-freertos` when that image
publishes - and for the SHA-pinned actions in the publishing workflow. An
upstream bump therefore reaches this image as a second pull request, after the
one in CppUTestFreertosDocker has merged and published. The publishing workflow builds the image on that pull
request and smokes it (see below). `renovate.json` holds the configuration.

CodeRabbit skips a Renovate pull request (`.coderabbit.yaml`): the build on
the pull request is the check. If a bump needed a hand-pushed change to
build, ask for the review with a `@coderabbitai review` comment.

## What merges itself

A Renovate pull request whose `build-and-push` check passes, smoke included,
merges itself: `renovate.json` sets `automerge`, and branch protection on
`main` requires that check, so GitHub's auto-merge waits for it. The publish
that follows sends solid-syslog its bump pull request, and that one is merged
by hand there. Nobody needs to look at this repository while bumps are green.

Two kinds of pull request come to the maintainer instead, by assignment, which
is a GitHub notification:

- one whose checks fail - Renovate assigns an automerge pull request only then;
- a major of anything, which never merges itself. A Debian major is a
  toolchain move, and a GitHub Action's major is where its inputs change,
  which a pull request cannot exercise for the login, push and notify steps
  that run only on `main`.

A publish that fails on `main` after a green pull request sends no event, so
no bump pull request opens. solid-syslog's weekly Image Drift workflow is the
alarm for that: it fails when a pin there lags this repository's `main` with
no bump pull request to carry it.

## The smoke

The publishing workflow builds the image into the runner's Docker and runs
`smoke/smoke.sh` inside it before anything is pushed, on pull requests and on
`main` alike. It checks what a bump can change, not any project built on the
image:

- every tool listed above answers `--version`;
- CppUTest builds, links and runs a one-test position-independent executable
  with Clang from `CPPUTEST_HOME`;
- every upstream variable names a directory, and every tree copied into `/opt`
  is named by one of them, so a tree `cpputest-freertos` adds fails here until
  this image exports its variable;
- both wolfSSL builds carry the release of the wolfSSL source tree, and a
  program calling them links and runs from Clang.

Whether a project still compiles on a new image is that project's own CI's
question, asked by the bump pull request the publish sends it.

## Usage

Pull the image from the GitHub Container Registry:

```
docker pull ghcr.io/cososo-ltd/cpputest-clang:latest
```

Run tests by mounting your project directory to `/home/src`:

```
docker run -v <path>:/home/src ghcr.io/cososo-ltd/cpputest-clang make
```

The `CPPUTEST_HOME` environment variable is set to `/home/cpputest` inside the container.

For production use and traceability, prefer a specific SHA tag over `latest`. Each build is tagged with the commit SHA it was built from (e.g. `sha-abc1234`). Available tags can be found on the [package page](https://github.com/cososo-ltd/CppUTestDockerClang/pkgs/container/cpputest-clang):

```
docker run -v <path>:/home/src ghcr.io/cososo-ltd/cpputest-clang:sha-<commit-sha> make
```

## Building

The image is built and pushed to the [GitHub Container Registry](https://ghcr.io) automatically on each push to the `main` branch.

Once it is pushed, the workflow sends an `image-published` event to
[solid-syslog](https://github.com/cososo-ltd/solid-syslog), whose Image Bump
workflow opens the pull request that moves every reference onto the new digest
and runs CI on it. The event is sent with a token minted from the release
GitHub App for solid-syslog, from the `RELEASE_PLEASE_APP_ID` and
`RELEASE_PLEASE_PRIVATE_KEY` organisation secrets; the App itself is not
installed here.

To build locally:

```
docker build -t cpputest-clang .
```
