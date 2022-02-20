# setup-cross-toolchain

[![build status](https://img.shields.io/github/workflow/status/taiki-e/setup-cross-toolchain/CI/main?style=flat-square&logo=github)](https://github.com/taiki-e/setup-cross-toolchain/actions)

GitHub Action for setup toolchains for cross compilation and cross testing for Rust.

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow: Basic usage](#example-workflow-basic-usage)
  - [Example workflow: Basic usage (multiple targets)](#example-workflow-basic-usage-multiple-targets)
- [Platform Support](#platform-support)
  - [Linux (GNU)](#linux-gnu)
- [Related Projects](#related-projects)
- [License](#license)

## Usage

### Inputs

| Name     | Required | Description                                                                      | Type   | Default        |
|----------|:--------:|----------------------------------------------------------------------------------|--------|----------------|
| target   | **true** | Target triple                                                                    | String |                |

### Example workflow: Basic usage

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain@v1
        with:
          target: aarch64-unknown-linux-gnu
      # setup-cross-toolchain sets the `CARGO_BUILD_TARGET` environment variable,
      # so there is no need for an explicit `--target` flag.
      - run: cargo test --verbose
```

### Example workflow: Basic usage (multiple targets)

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
      - uses: actions/checkout@v2
      - name: Install Rust
        run: rustup update stable
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain@v1
        with:
          target: ${{ matrix.target }}
      - run: cargo test --verbose
```

## Platform Support

### Linux (GNU)

| C++ | test |
| --- | ---- |
| ✓ (libstdc++) | ✓ (qemu) |

**Supported targets**:

| target | host  |
| ------ | ----- |
| `aarch64-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `arm-unknown-linux-gnueabi` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `armv5te-unknown-linux-gnueabi` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `armv7-unknown-linux-gnueabi` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `armv7-unknown-linux-gnueabihf` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `i586-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `i686-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `mips-unknown-linux-gnu` | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2] |
| `mips64-unknown-linux-gnuabi64` | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2] |
| `mips64el-unknown-linux-gnuabi64` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `mipsel-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `mipsisa32r6el-unknown-linux-gnu` (tier3) | ubuntu-latest/ubuntu-20.04 [1] |
| `mipsisa64r6el-unknown-linux-gnuabi64` (tier3) | ubuntu-latest/ubuntu-20.04 [1] |
| `powerpc-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `powerpc64-unknown-linux-gnu` | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2] |
| `powerpc64le-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `riscv64gc-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1] <!--, ubuntu-18.04 [2]--> |
| `s390x-unknown-linux-gnu` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `sparc64-unknown-linux-gnu` | <!-- ubuntu-latest/ubuntu-20.04 [1],--> ubuntu-18.04 [2] |
| `thumbv7neon-unknown-linux-gnueabihf` | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |
| `x86_64-unknown-linux-gnu` [3] | ubuntu-latest/ubuntu-20.04 [1], ubuntu-18.04 [2] |

[1] GCC 9, glibc 2.31<br>
[2] GCC 7, glibc 2.27<br>
[3] no-op<br>

## Related Projects

- [rust-cross-toolchain]: Toolchains for cross compilation and cross testing for Rust.
- [install-action]: GitHub Action for installing development tools.

[install-action]: https://github.com/taiki-e/install-action
[rust-cross-toolchain]: https://github.com/taiki-e/rust-cross-toolchain

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
