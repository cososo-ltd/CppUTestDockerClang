FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
LABEL Description="Image for running CppUTest with Clang"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Clang 19 comes from Debian itself; only the GitHub CLI needs a repository.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates gnupg wget \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        > /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake clang-19 clang-format-19 clang-tidy-19 cmake cppcheck gdb gh git lcov libclang-19-dev libssl-dev libtool llvm-19-dev make sudo zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set clang-19 as the default cc, c++, clang-format, and clang-tidy
RUN update-alternatives --install /usr/bin/cc          cc          /usr/bin/clang-19        100 \
 && update-alternatives --install /usr/bin/c++         c++         /usr/bin/clang++-19      100 \
 && update-alternatives --install /usr/bin/clang       clang       /usr/bin/clang-19        100 \
 && update-alternatives --install /usr/bin/clang++     clang++     /usr/bin/clang++-19      100 \
 && update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-19 100 \
 && update-alternatives --install /usr/bin/clang-tidy  clang-tidy  /usr/bin/clang-tidy-19   100

# Build CppUTest with Clang, with -fPIC so it links cleanly into PIE executables
WORKDIR /home/cpputest
RUN git clone --depth 1 --branch v4.0 https://github.com/cpputest/cpputest.git . \
 && autoreconf . -i \
 && CC=clang-19 CXX=clang++-19 CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
 && make install

ENV CPPUTEST_HOME=/home/cpputest

WORKDIR /home/legacy-build
RUN git clone https://github.com/jwgrenning/legacy-build.git . \
 && git submodule update --init \
 && bash test/all-tests.sh

# Build include-what-you-use against clang-19. The clang_19 branch matches
# the installed Clang's library ABI; mismatched IWYU/Clang versions silently
# produce wrong include suggestions because IWYU embeds Clang's parser.
WORKDIR /tmp/iwyu
RUN git clone --depth 1 --branch clang_19 https://github.com/include-what-you-use/include-what-you-use.git . \
 && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/usr/lib/llvm-19 -DCMAKE_INSTALL_PREFIX=/usr/local \
 && cmake --build build --parallel "$(nproc)" \
 && cmake --install build \
 && cd / && rm -rf /tmp/iwyu

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN mkdir -p /home/src \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/cpputest /home/legacy-build /home/src

USER ${USERNAME}

WORKDIR /home/src
