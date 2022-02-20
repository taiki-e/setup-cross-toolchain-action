#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

x() {
    local cmd="$1"
    shift
    (
        set -x
        "${cmd}" "$@"
    )
}
bail() {
    echo "::error::$*"
    exit 1
}
warn() {
    echo "::warning::$*"
}

if [[ $# -gt 0 ]]; then
    bail "invalid argument '$1'"
fi

target="${INPUT_TARGET:?}"
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper="$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")"
host=$(rustc -Vv | grep host | sed 's/host: //')

target_list=$(rustup target list)
if grep <<<"${target_list}" -Eq "^${target}( |$)"; then
    rustup target add "${target}" &>/dev/null
else
    # for -Z build-std
    rustup component add rust-src &>/dev/null
    echo "BUILD_STD=-Z build-std" >>"${GITHUB_ENV}"
fi
echo "CARGO_BUILD_TARGET=${target}" >>"${GITHUB_ENV}"

case "${host}" in
    x86_64-unknown-linux-gnu)
        case "${target}" in
            x86_64-unknown-linux-gnu) ;;
            *-linux-gnu*)
                # https://github.com/taiki-e/rust-cross-toolchain/blob/main/docker/linux-gnu.sh
                case "${target}" in
                    aarch64_be-unknown-linux-gnu)
                        # (tier3) Toolchains for aarch64_be-linux-gnu is not available in APT.
                        # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/linux-gnu.sh#L40
                        bail "target '${target}' not yet supported; consider using aarch64-unknown-linux-gnu for testing aarch64"
                        ;;
                    arm-unknown-linux-gnueabihf)
                        # (tier2) Ubuntu's gcc-arm-linux-gnueabihf enables armv7 by default
                        # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/linux-gnu.sh#L55
                        bail "target '${target}' not yet supported; consider using armv7-unknown-linux-gnueabihf for testing armhf"
                        ;;
                    riscv32gc-unknown-linux-gnu)
                        # (tier3) Toolchains for riscv32-linux-gnu is not available in APT.
                        # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/linux-gnu.sh#L69
                        # Suggest riscv64 because instructions available on riscv32 are also available on riscv64,
                        # so testing in riscv64 may cover riscv32-related code.
                        bail "target '${target}' not yet supported; consider using riscv64gc-unknown-linux-gnu for testing RISC-V"
                        ;;
                    sparc-unknown-linux-gnu)
                        # (tier3) Setup is tricky, and fails to build test.
                        # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/linux-gnu.Dockerfile#L44
                        # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/test/test.sh#L241
                        bail "target '${target}' not yet supported"
                        ;;
                esac
                case "${target}" in
                    arm*hf | thumbv7neon-*) cc_target=arm-linux-gnueabihf ;;
                    arm*) cc_target=arm-linux-gnueabi ;;
                    riscv32gc-* | riscv64gc-*) cc_target="${target/gc-unknown/}" ;;
                    sparc-*)
                        cc_target=sparc-linux-gnu
                        apt_target=sparc64-linux-gnu
                        multilib=1
                        ;;
                    *) cc_target="${target/-unknown/}" ;;
                esac
                apt_target="${apt_target:-"${cc_target/i586/i686}"}"
                sudo apt-get -o Acquire::Retries=10 -qq update
                # TODO: can we reduce the setup time by providing an option to skip installing packages for C++?
                sudo apt-get -o Acquire::Retries=10 -qq -o Dpkg::Use-Pty=0 install -y \
                    "g++-${multilib:+multilib-}${apt_target/_/-}"

                # https://github.com/taiki-e/rust-cross-toolchain/blob/main/docker/test/entrypoint.sh
                echo "CARGO_TARGET_${target_upper}_LINKER=${apt_target}-gcc" >>"${GITHUB_ENV}"
                echo "CC_${target_lower}=${apt_target}-gcc" >>"${GITHUB_ENV}"
                echo "CXX_${target_lower}=${apt_target}-g++" >>"${GITHUB_ENV}"
                echo "AR_${target_lower}=${apt_target}-ar" >>"${GITHUB_ENV}"
                echo "STRIP=${apt_target}-strip" >>"${GITHUB_ENV}"
                echo "OBJDUMP=${apt_target}-objdump" >>"${GITHUB_ENV}"
                ;;
            *) bail "unsupported target '${target}'" ;;
        esac

        case "${target}" in
            x86_64-unknown-linux-gnu) ;;
            *-unknown-linux-*)
                # https://github.com/taiki-e/rust-cross-toolchain/blob/590d6cb4d3a72c26c5096f2ad3033980298cd4aa/docker/test/entrypoint.sh#L251
                # We basically set the newer and more powerful CPU as the
                # default QEMU_CPU so that we can test more CPU features.
                # In some contexts, we want to test for a specific CPU,
                # so respect user-set QEMU_CPU.
                case "${target}" in
                    aarch64-* | aarch64_be-*)
                        qemu_arch="${target%%-*}"
                        qemu_cpu=a64fx
                        ;;
                    arm* | thumbv7neon-*)
                        qemu_arch=arm
                        case "${target}" in
                            # ARMv6: https://en.wikipedia.org/wiki/ARM11
                            arm-* | armv6-*) qemu_cpu=arm11mpcore ;;
                            # ARMv4: https://en.wikipedia.org/wiki/StrongARM
                            armv4t-*) qemu_cpu=sa1110 ;;
                            # ARMv5TE
                            armv5te-*) qemu_cpu=arm1026 ;;
                            # ARMv7-A+NEONv2
                            armv7-* | thumbv7neon-*) qemu_cpu=cortex-a15 ;;
                            *) bail "unrecognized target '${target}'" ;;
                        esac
                        ;;
                    i*86-*) qemu_arch=i386 ;;
                    hexagon-*) qemu_arch=hexagon ;;
                    m68k-*) qemu_arch=m68k ;;
                    mips-* | mipsel-*) qemu_arch="${target%%-*}" ;;
                    mips64-* | mips64el-*)
                        qemu_arch="${target%%-*}"
                        # As of qemu 6.1, only Loongson-3A4000 supports MSA instructions with mips64r5.
                        qemu_cpu=Loongson-3A4000
                        ;;
                    mipsisa32r6-* | mipsisa32r6el-*)
                        qemu_arch="${target%%-*}"
                        qemu_arch="${qemu_arch/isa32r6/}"
                        qemu_cpu=mips32r6-generic
                        ;;
                    mipsisa64r6-* | mipsisa64r6el-*)
                        qemu_arch="${target%%-*}"
                        qemu_arch="${qemu_arch/isa64r6/64}"
                        qemu_cpu=I6400
                        ;;
                    powerpc-*spe)
                        qemu_arch=ppc
                        qemu_cpu=e500v2
                        ;;
                    powerpc-*)
                        qemu_arch=ppc
                        qemu_cpu=Vger
                        ;;
                    powerpc64-*)
                        qemu_arch=ppc64
                        qemu_cpu=power10
                        ;;
                    powerpc64le-*)
                        qemu_arch=ppc64le
                        qemu_cpu=power10
                        ;;
                    riscv32gc-* | riscv64gc-*) qemu_arch="${target%%gc-*}" ;;
                    s390x-*) qemu_arch=s390x ;;
                    sparc-*) qemu_arch=sparc32plus ;;
                    sparc64-*) qemu_arch=sparc64 ;;
                    x86_64-*)
                        qemu_arch=x86_64
                        # qemu does not seem to support emulating x86_64 CPU features on x86_64 hosts.
                        # > qemu-x86_64: warning: TCG doesn't support requested feature
                        #
                        # A way that works well for emulating x86_64 CPU features on x86_64 hosts is to use Intel SDE.
                        # https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html
                        # It is not OSS, but it is licensed under Intel Simplified Software License and redistribution is allowed.
                        # https://www.intel.com/content/www/us/en/developer/articles/license/pre-release-license-agreement-for-software-development-emulator.html
                        # https://www.intel.com/content/www/us/en/developer/articles/license/onemkl-license-faq.html
                        ;;
                    *) bail "unrecognized target '${target}'" ;;
                esac
                if [[ -n "${qemu_cpu:-}" ]] && [[ -z "${QEMU_CPU:-}" ]]; then
                    echo "QEMU_CPU=${qemu_cpu}" >>"${GITHUB_ENV}"
                fi
                case "${target}" in
                    *-linux-gnu*) qemu_ld_prefix="/usr/${apt_target}" ;;
                esac
                if [[ -n "${qemu_ld_prefix:-}" ]] && [[ -z "${QEMU_LD_PREFIX:-}" ]]; then
                    echo "QEMU_LD_PREFIX=${qemu_ld_prefix}" >>"${GITHUB_ENV}"
                fi
                echo "CARGO_TARGET_${target_upper}_RUNNER=qemu-${qemu_arch}" >>"${GITHUB_ENV}"
                # https://github.com/taiki-e/dockerfiles/pkgs/container/qemu-user
                docker create --name qemu-user ghcr.io/taiki-e/qemu-user
                sudo docker cp qemu-user:/usr/bin/qemu-${qemu_arch} /usr/bin/qemu-${qemu_arch}
                docker rm -f qemu-user >/dev/null
                x qemu-${qemu_arch} --version
                ;;
        esac
        ;;
    *) bail "unsupported host '${host}'" ;;
esac
