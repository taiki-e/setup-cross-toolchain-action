# setup-cross-toolchain-action

[![release](https://img.shields.io/github/release/taiki-e/setup-cross-toolchain-action?style=flat-square&logo=github)](https://github.com/taiki-e/setup-cross-toolchain-action/releases/latest)
[![github actions](https://img.shields.io/github/actions/workflow/status/taiki-e/setup-cross-toolchain-action/ci.yml?branch=main&style=flat-square&logo=github)](https://github.com/taiki-e/setup-cross-toolchain-action/actions)

GitHub Action for setup toolchains for cross compilation and cross testing for Rust.

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow: Basic usage](#example-workflow-basic-usage)
  - [Example workflow: Multiple targets](#example-workflow-multiple-targets)
  - [Example workflow: Doctest](#example-workflow-doctest)
  - [Example workflow: Tier 3 targets](#example-workflow-tier-3-targets)
- [Platform Support](#platform-support)
  - [Linux (GNU)](#linux-gnu)
  - [Linux (musl)](#linux-musl)
  - [Linux (uClibc)](#linux-uclibc)
  - [Android](#android)
  - [FreeBSD](#freebsd)
  - [NetBSD](#netbsd)
  - [illumos](#illumos)
  - [WASI](#wasi)
  - [Windows (MinGW)](#windows-mingw)
  - [Windows (LLVM MinGW)](#windows-llvm-mingw)
  - [Windows (MSVC)](#windows-msvc)
  - [macOS](#macos)
- [Compatibility](#compatibility)
- [Related Projects](#related-projects)
- [License](#license)

## Usage

### Inputs

| Name     | Required | Description         | Type   | Default |
|----------|:--------:|---------------------|--------|---------|
| target   | **true** | Target triple       | String |         |
| packages | false    | Packages to install | String |         |
| runner   | false    | Test runner         | String |         |

### Example workflow: Basic usage

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64-unknown-linux-gnu
      # setup-cross-toolchain-action sets the `CARGO_BUILD_TARGET` environment variable,
      # so there is no need for an explicit `--target` flag.
      - run: cargo test --verbose
      # `cargo run` also works.
      - run: cargo run --verbose
      # You can also run the cross-compiled binaries directly (via binfmt).
      - run: ./target/aarch64-unknown-linux-gnu/debug/my-app
```

### Example workflow: Installing additional packages

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64-unknown-linux-gnu
          packages: libgbm-dev libxkbcommon-dev libinput-dev libudev-dev libseat-dev
      - run: cargo build
```

> [!NOTE]
> The list of packages can be space seperated, comma seperated or newline seperated.

### Example workflow: Multiple targets

```yaml
jobs:
  test:
    strategy:
      matrix:
        target:
          - aarch64-unknown-linux-gnu
          - riscv64gc-unknown-linux-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
      - run: cargo test --verbose
```

### Example workflow: Doctest

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update nightly && rustup default nightly
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64-unknown-linux-gnu
      - run: cargo test --verbose -Z doctest-xcompile
```

Cross-testing of doctest is currently available only on nightly.
If you want to use stable and nightly in the same matrix, you can use the `DOCTEST_XCOMPILE` environment variable set by this action to enable doctest only in nightly.

```yaml
jobs:
  test:
    strategy:
      matrix:
        rust:
          - stable
          - nightly
        target:
          - aarch64-unknown-linux-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update ${{ matrix.rust }} && rustup default ${{ matrix.rust }}
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
      # On nightly and `-Z doctest-xcompile` is available,
      # `$DOCTEST_XCOMPILE` is `-Zdoctest-xcompile`.
      #
      # On stable, `$DOCTEST_XCOMPILE` is not set.
      # Once `-Z doctest-xcompile` is stabilized, the corresponding flag
      # will be set to `$DOCTEST_XCOMPILE` (if it is available).
      - run: cargo test --verbose $DOCTEST_XCOMPILE
```

### Example workflow: Tier 3 targets

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update nightly && rustup default nightly
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: aarch64_be-unknown-linux-gnu
      - run: cargo test --verbose -Z build-std
```

Cross-compilation of tier 3 targets currently requires nightly to build std.
If you want to use tier 1/2 and tier 3 in the same matrix, you can use the `BUILD_STD` environment variable set by this action to use `-Z build-std` only for tier 3 targets.

```yaml
jobs:
  test:
    strategy:
      matrix:
        target:
          - aarch64-unknown-linux-gnu
          - aarch64_be-unknown-linux-gnu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        run: rustup update nightly && rustup default nightly
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
      # If target is tier 3, `$BUILD_STD` is `-Zbuild-std`.
      # Otherwise, `$BUILD_STD` is not set.
      #
      # Once `Z build-std` is stabilized, the corresponding flag
      # will be set to `$BUILD_STD` (if it is available).
      - run: cargo test --verbose $BUILD_STD
```

## Platform Support

### Linux (GNU)

| C++ | test |
| --- | ---- |
| ✓ (libstdc++) [1] | ✓    |

[1] Except for loongarch64-unknown-linux-gnu

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `aarch64-unknown-linux-gnu`            | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `aarch64_be-unknown-linux-gnu`         | Ubuntu (18.04,        22.04),        Debian (10, 11, 12) [2] | qemu-user                   | tier3 |
| `arm-unknown-linux-gnueabi`            | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `armeb-unknown-linux-gnueabi`          | Ubuntu (18.04,        22.04),        Debian (10, 11, 12) [3] | qemu-user                   | tier3 |
| `armv5te-unknown-linux-gnueabi`        | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `armv7-unknown-linux-gnueabi`          | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `armv7-unknown-linux-gnueabihf`        | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `i586-unknown-linux-gnu`               | Ubuntu (18.04, 20.04, 22.04, 24.04) [1]                      | qemu-user (default), native | [7]   |
| `i686-unknown-linux-gnu`               | Ubuntu (18.04, 20.04, 22.04, 24.04) [1]                      | native (default), qemu-user | [7]   |
| `loongarch64-unknown-linux-gnu`        | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [4] | qemu-user                   | experimental |
| `mips-unknown-linux-gnu`               | Ubuntu (18.04,        22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 [6] |
| `mips64-unknown-linux-gnuabi64`        | Ubuntu (18.04,        22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `mips64el-unknown-linux-gnuabi64`      | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `mipsel-unknown-linux-gnu`             | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 [6] |
| `mipsisa32r6-unknown-linux-gnu`        | Ubuntu               (22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `mipsisa32r6el-unknown-linux-gnu`      | Ubuntu        (20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `mipsisa64r6-unknown-linux-gnuabi64`   | Ubuntu               (22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `mipsisa64r6el-unknown-linux-gnuabi64` | Ubuntu        (20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   | tier3 |
| `powerpc-unknown-linux-gnu`            | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `powerpc64-unknown-linux-gnu`          | Ubuntu (18.04,        22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `powerpc64le-unknown-linux-gnu`        | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `riscv32gc-unknown-linux-gnu`          | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [5] | qemu-user                   |       |
| `riscv64gc-unknown-linux-gnu`          | ubuntu (18.04,        22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `s390x-unknown-linux-gnu`              | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `sparc-unknown-linux-gnu`              | Ubuntu (18.04,        22.04, 24.04), Debian (10,     12) [1] | qemu-user                   | tier3, experimental |
| `sparc64-unknown-linux-gnu`            | Ubuntu (18.04,        22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `thumbv7neon-unknown-linux-gnueabihf`  | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | qemu-user                   |       |
| `x86_64-unknown-linux-gnu`             | Ubuntu (18.04, 20.04, 22.04, 24.04), Debian (10, 11, 12) [1] | native (default), qemu-user |       |

[1] [GCC 7](https://packages.ubuntu.com/en/bionic/gcc), [glibc 2.27](https://packages.ubuntu.com/en/bionic/libc6-dev) for Ubuntu 18.04. [GCC 9](https://packages.ubuntu.com/en/focal/gcc), [glibc 2.31](https://packages.ubuntu.com/en/focal/libc6-dev) for Ubuntu 20.04. [GCC 11](https://packages.ubuntu.com/en/jammy/gcc), [glibc 2.35](https://packages.ubuntu.com/en/jammy/libc6-dev) for Ubuntu 22.04, [glibc 2.39](https://packages.ubuntu.com/en/noble/libc6-dev) for Ubuntu 24.04. [GCC 8](https://packages.debian.org/en/buster/gcc), [glibc 2.28](https://packages.debian.org/en/buster/libc6-dev) for Debian 10. [GCC 10](https://packages.debian.org/en/bullseye/gcc), [glibc 2.31](https://packages.debian.org/en/bullseye/libc6-dev) for Debian 11. [GCC 12](https://packages.debian.org/en/bookworm/gcc), [glibc 2.36](https://packages.debian.org/en/bookworm/libc6-dev) for Debian 12.<br>
[2] GCC 10, glibc 2.31<br>
[3] GCC 7, glibc 2.25<br>
[4] GCC 13, glibc 2.36<br>
[5] GCC 11, glibc 2.33<br>
[6] [Since nightly-2023-07-05](https://github.com/rust-lang/compiler-team/issues/648), mips{,el}-unknown-linux-gnu requires release mode for building std<br>
[7] Not fully supported with containers<br>

<!-- omit in toc -->
#### <a name="qemu-user-runner"></a>qemu-user runner

The current default QEMU version is 9.0.

You can select/pin the version by using `qemu` input option, or `@` syntax in `runner` input option (if both are set, the latter is preferred). For example:

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: aarch64-unknown-linux-gnu
    qemu: '7.2'
```

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: aarch64-unknown-linux-gnu
    runner: qemu@8.1
```

### Linux (musl)

| libc | GCC | C++ | test |
| ---- | --- | --- | ---- |
| musl 1.2.3 / 1.1.24 [1] | 9 | ? (libstdc++) | ✓ |

[1]: [1.2 on Rust 1.71+](https://github.com/rust-lang/rust/pull/107129), otherwise 1.1. 1.1 toolchain is with a patch that fixes CVE-2020-28928.

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `aarch64-unknown-linux-musl`       | x86_64 Linux | qemu-user                   |       |
| `arm-unknown-linux-musleabi`       | x86_64 Linux | qemu-user                   |       |
| `arm-unknown-linux-musleabihf`     | x86_64 Linux | qemu-user                   |       |
| `armv5te-unknown-linux-musleabi`   | x86_64 Linux | qemu-user                   |       |
| `armv7-unknown-linux-musleabi`     | x86_64 Linux | qemu-user                   |       |
| `armv7-unknown-linux-musleabihf`   | x86_64 Linux | qemu-user                   |       |
| `i586-unknown-linux-musl`          | x86_64 Linux | qemu-user (default), native |       |
| `i686-unknown-linux-musl`          | x86_64 Linux | native (default), qemu-user |       |
| `x86_64-unknown-linux-musl`        | x86_64 Linux | native (default), qemu-user |       |

(Other linux-musl targets supported by [rust-cross-toolchain](https://github.com/taiki-e/rust-cross-toolchain#linux-musl) may also work, although this action's CI has not tested them.)

For the `qemu-user` runner, see ["qemu-user runner" section for linux-gnu targets](#qemu-user-runner).

### Linux (uClibc)

| libc | GCC | C++ | test |
| ---- | --- | --- | ---- |
| uClibc-ng 1.0.34 | 10.2.0 | ✓ (libstdc++) | ✓ |

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `armv5te-unknown-linux-uclibceabi` | x86_64 Linux | qemu-user | tier3 |
| `armv7-unknown-linux-uclibceabi`   | x86_64 Linux | qemu-user | tier3 |
| `armv7-unknown-linux-uclibceabihf` | x86_64 Linux | qemu-user | tier3 |
| `mips-unknown-linux-uclibc`        | x86_64 Linux | qemu-user | tier3 [1] |
| `mipsel-unknown-linux-uclibc`      | x86_64 Linux | qemu-user | tier3 [1] |

[1] mips{,el}-unknown-linux-uclibc requires release mode for building std<br>

For the `qemu-user` runner, see ["qemu-user runner" section for linux-gnu targets](#qemu-user-runner).

### Android

| clang | C++ | test |
| ----- | --- | ---- |
| 14 | ✓ (libc++) | ✓ |

**Note:** By making use of these targets you accept the [Android SDK License](https://developer.android.com/studio/terms)

**Supported targets:**

| target | api level | host | runner | note |
| ------ | --------- | ---- | ------ | ---- |
| `aarch64-linux-android`         | 21 (default), 22-24, 26-33 [1] | x86_64 Linux | qemu-user                   |       |
| `arm-linux-androideabi`         | 21 / 19 [2] (default), 21-24, 26-33 [1] | x86_64 Linux | qemu-user                   |       |
| `armv7-linux-androideabi`       | 21 / 19 [2] (default), 21-24, 26-33 [1] | x86_64 Linux | qemu-user                   |       |
| `i686-linux-android`            | 21 / 19 [2] (default), 21-24, 26-33 [1] | x86_64 Linux | native (default), qemu-user |       |
| `thumbv7neon-linux-androideabi` | 21 / 19 [2] (default), 21-24, 26-33 [1] | x86_64 Linux | qemu-user                   |       |
| `x86_64-linux-android`          | 21 (default), 22-24, 26-33 [1] | x86_64 Linux | native (default), qemu-user |       |

[1] This action currently uses the API level 24 system image, so `cargo test` and `cargo run` may not work on API level 26+.
[2]: [21 on Rust 1.82+](https://github.com/rust-lang/rust/pull/120593), otherwise 19.

You can select/pin the API level version by using `@` syntax in `target` option. For example:

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: arm-linux-androideabi@21
```

For the `qemu-user` runner, see ["qemu-user runner" section for linux-gnu targets](#qemu-user-runner).

### FreeBSD

| C++ | test |
| --- | ---- |
| ✓ (libc++) | |

**Supported targets:**

| target | version | host | note |
| ------ | ------- | ---- | ---- |
| `aarch64-unknown-freebsd` | 12.4 (default), 13.3, 14.0 | Ubuntu, Debian [1] | tier3 |
| `i686-unknown-freebsd`    | 12.4 (default), 13.3, 14.0 | Ubuntu, Debian [1] |       |
| `x86_64-unknown-freebsd`  | 12.4 (default), 13.3, 14.0 | Ubuntu, Debian [1] |       |

[1] Clang 13 for Ubuntu 18.04, otherwise Clang 15<br>

(Other FreeBSD targets supported by [rust-cross-toolchain](https://github.com/taiki-e/rust-cross-toolchain#freebsd) may also work, although this action's CI has not tested them.)

You can select/pin the OS version by using `@` syntax in `target` option. For example:

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: x86_64-unknown-freebsd@13
```

Only specifying a major version is supported.

### NetBSD

| GCC | C++ | test |
| --- | --- | ---- |
| 7.5.0 | ✓ (libstdc++) | |

**Supported targets:**

| target | version | host | note |
| ------ | ------- | ---- | ---- |
| `aarch64-unknown-netbsd` | 9.4 (default), 10.0      | x86_64 Linux | tier3 |
| `x86_64-unknown-netbsd`  | 8.2 (default), 9.4, 10.0 | x86_64 Linux |       |

(Other NetBSD targets supported by [rust-cross-toolchain](https://github.com/taiki-e/rust-cross-toolchain#netbsd) may also work, although this action's CI has not tested them.)

You can select/pin the OS version by using `@` syntax in `target` option. For example:

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: x86_64-unknown-netbsd@9
```

Only specifying a major version is supported.

### illumos

| libc | GCC | C++ | test |
| ---- | --- | --- | ---- |
| solaris 2.10 | 8.5.0 | ✓ (libstdc++) | |

**Supported targets:**

| target | host | note |
| ------ | ---- | ---- |
| `x86_64-unknown-illumos` | x86_64 Linux (any libc) | |

### WASI

| libc | Clang | C++ | test |
| ---- | ----- | --- | ---- |
| wasi-sdk 23 (wasi-libc 3f43ea9) | 18 | ? (libc++) | ✓ |

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `wasm32-wasi`   | x86_64 Linux | wasmtime |  |
| `wasm32-wasip1` | x86_64 Linux | wasmtime |  |

(Other WASI targets supported by [rust-cross-toolchain](https://github.com/taiki-e/rust-cross-toolchain#wasi) may also work, although this action's CI has not tested them.)

### Windows (MinGW)

| C++ | test |
| --- | ---- |
| ✓ (libstdc++) | ✓ |

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `x86_64-pc-windows-gnu` | *Windows*, Ubuntu (22.04), Debian (11, 12) [1] | native (Windows host) / wine (Linux host) |  |

[1] [GCC 10](https://packages.ubuntu.com/en/jammy/gcc-mingw-w64-base), [MinGW-w64 8](https://packages.ubuntu.com/en/jammy/mingw-w64-x86-64-dev) for Ubuntu 22.04. [GCC 10](https://packages.debian.org/en/bullseye/gcc-mingw-w64-base), [MinGW-w64 8](https://packages.debian.org/en/bullseye/mingw-w64-x86-64-dev) for Debian 11. [GCC 12](https://packages.debian.org/en/bookworm/gcc-mingw-w64-base), [MinGW-w64 10](https://packages.debian.org/en/bookworm/mingw-w64-x86-64-dev) for Debian 12.<br>

On Windows host, GitHub-provided Windows runners support cross-compile for other architectures or environments, so this action just runs `rustup target add` and/or sets some environment variables.

(Other Windows targets may also work, although this action's CI has not tested them.)

On Linux host, this action installs MinGW toolchain and Wine.

<!-- omit in toc -->
#### <a name="wine-runner"></a>wine runner

The current default Wine version is 9.0.

You can select/pin the version by using `wine` input option, or `@` syntax in `runner` input option (if both are set, the latter is preferred). For example:

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: x86_64-pc-windows-gnu
    wine: '9.3'
```

```yaml
- uses: taiki-e/setup-cross-toolchain-action@v1
  with:
    target: x86_64-pc-windows-gnu
    runner: wine@9.3
```

### Windows (LLVM MinGW)

| libc | Clang | C++ | test |
| ---- | ----- | --- | ---- |
| Mingw-w64 7c9cfe6 | 18 | ✓ (libc++) | ✓ |

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `aarch64-pc-windows-gnullvm` | Ubuntu (22.04) | wine |  |
| `i686-pc-windows-gnullvm` | Ubuntu (22.04) | wine |  |
| `x86_64-pc-windows-gnullvm` | Ubuntu (22.04) | wine |  |

For the `wine` runner for {i686,x86_64}-pc-windows-gnullvm, see ["wine runner" section for windows-gnu targets](#wine-runner).

The `wine` runner for aarch64-pc-windows-gnullvm is AArch64 Wine running on qemu-user; specifying the Wine version is not yet supported, but the QEMU version can be specified by using `qemu` input option like Linux targets.

### Windows (MSVC)

| C++ | test |
| --- | ---- |
| ✓ | ✓ [1] |

[1] Only x86/x86_64 targets

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `aarch64-pc-windows-msvc` | *Windows* |        |  |
| `i586-pc-windows-msvc`    | *Windows* | native |  |
| `i686-pc-windows-msvc`    | *Windows* | native |  |
| `x86_64-pc-windows-msvc`  | *Windows* | native |  |

GitHub-provided Windows runners support cross-compile for other architectures or environments, so this action just runs `rustup target add` and/or sets some environment variables.

(Other Windows targets may also work, although this action's CI has not tested them.)

### macOS

| C++ | test |
| --- | ---- |
| ✓ | ✓ [1] |

[1] For x86_64-apple-darwin all runners and for aarch64-apple-darwin only arm64 runners. (x86_64h-apple-darwin is also x86_64 but build-only because the CPU of GitHub-provided macOS runners is older than Haswell. If you use a large runner or self-hosted runner, you may be able to run the test.)

**Supported targets:**

| target | host | runner | note |
| ------ | ---- | ------ | ---- |
| `aarch64-apple-darwin` | *macOS* | native |       |
| `x86_64-apple-darwin`  | *macOS* | native |       |
| `x86_64h-apple-darwin` | *macOS* | native | tier3 |

GitHub-provided macOS runners support cross-compile for other architectures or environments, so this action just runs `rustup target add` and/or sets some environment variables.

(Other macOS targets may also work, although this action's CI has not tested them.)

## Compatibility

This action has been tested for GitHub-hosted runners (Ubuntu, macOS, Windows) and containers (Ubuntu, Debian).
To use this action in self-hosted runners or in containers, at least the following tools are required:

- bash
- rustup, cargo

`--privileged` option is currently required when using with containers (due to binfmt).

```yaml
container:
  image: '...'
  options: --privileged
```

## Related Projects

- [rust-cross-toolchain]: Toolchains for cross compilation and cross testing for Rust.
- [install-action]: GitHub Action for installing development tools (mainly from GitHub Releases).
- [cache-cargo-install-action]: GitHub Action for `cargo install` with cache.
- [create-gh-release-action]: GitHub Action for creating GitHub Releases based on changelog.
- [upload-rust-binary-action]: GitHub Action for building and uploading Rust binary to GitHub Releases.
- [checkout-action]: GitHub Action for checking out a repository. (Simplified actions/checkout alternative that does not depend on Node.js.)

[cache-cargo-install-action]: https://github.com/taiki-e/cache-cargo-install-action
[checkout-action]: https://github.com/taiki-e/checkout-action
[create-gh-release-action]: https://github.com/taiki-e/create-gh-release-action
[install-action]: https://github.com/taiki-e/install-action
[rust-cross-toolchain]: https://github.com/taiki-e/rust-cross-toolchain
[upload-rust-binary-action]: https://github.com/taiki-e/upload-rust-binary-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
