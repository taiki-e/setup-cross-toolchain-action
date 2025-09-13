#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'

x() {
  (
    set -x
    "$@"
  )
}
retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
bail() {
  printf '::error::%s\n' "$*"
  exit 1
}
warn() {
  printf '::warning::%s\n' "$*"
}
_sudo() {
  if type -P sudo >/dev/null; then
    sudo "$@"
  else
    "$@"
  fi
}

export DEBIAN_FRONTEND=noninteractive
export CARGO_NET_RETRY=10
export RUSTUP_MAX_RETRIES=10

# As a general rule, we use the latest stable version or one previous stable
# version as the default runner version.
# NB: Sync with readme.
# https://github.com/taiki-e/dockerfiles/pkgs/container/qemu-user
default_qemu_version='10.1'
# https://dl.winehq.org/wine-builds/ubuntu/pool/main/w/wine/
default_wine_version='10.0.0.0'

if [[ $# -gt 0 ]]; then
  bail "invalid argument '$1'"
fi

target="${INPUT_TARGET:?}"
runner="${INPUT_RUNNER:-}"

host=$(rustc -vV | grep -E '^host:' | cut -d' ' -f2)
rustc_version=$(rustc -vV | grep -E '^release:' | cut -d' ' -f2)
rustc_minor_version="${rustc_version#*.}"
rustc_minor_version="${rustc_minor_version%%.*}"

api_level=''
sys_version=''
if [[ "${target}" == *"@"* ]]; then
  case "${target}" in
    *-android*)
      api_level="${target#*@}"
      ;;
    *-freebsd* | *-netbsd*)
      sys_version="${target#*@}"
      ;;
    *) bail "versioned target triple is currently only supported on BSDs and Android" ;;
  esac
  target="${target%@*}"
else
  # NB: Sync with readme.
  case "${target}" in
    *-android*)
      api_level=21
      # https://github.com/rust-lang/rust/pull/120593 increased min api level of 32-bit targets to 21.
      if [[ "${rustc_minor_version}" -lt 82 ]]; then
        api_level=''
      fi
      ;;
    *-freebsd*)
      # FreeBSD have binary compatibility with previous releases.
      # Therefore, the default is the minimum supported version.
      # https://github.com/taiki-e/rust-cross-toolchain/blob/HEAD/tools/build-docker.sh
      case "${target}" in
        powerpc* | riscv64*) sys_version=13 ;;
        *) sys_version=12 ;;
      esac
      ;;
    *-netbsd*)
      # NetBSD have binary compatibility with previous releases.
      # Therefore, the default is the minimum supported version.
      # https://github.com/taiki-e/rust-cross-toolchain/blob/HEAD/tools/build-docker.sh
      # https://github.com/rust-lang/rust/pull/103709 increased version used for prebuilt artifacts to 9.0.
      if [[ "${rustc_minor_version}" -ge 67 ]]; then
        case "${target}" in
          aarch64_be-*) sys_version=10 ;;
          *) sys_version=9 ;;
        esac
      else
        case "${target}" in
          aarch64-*) sys_version=9 ;;
          aarch64_be-*) sys_version=10 ;;
          *) sys_version=8 ;;
        esac
      fi
      ;;
  esac
fi
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper=$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")
rustup_target_list=$(rustup target list | cut -d' ' -f1)

install_apt_packages() {
  if [[ ${#apt_packages[@]} -gt 0 ]]; then
    retry _sudo apt-get -o Acquire::Retries=10 -qq update
    if ! retry _sudo apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends "${apt_packages[@]}"; then
      # Workaround for https://github.com/taiki-e/setup-cross-toolchain-action/issues/15
      _sudo apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 upgrade -y
      _sudo apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends "${apt_packages[@]}"
    fi
    apt_packages=()
  fi
}
install_llvm() {
  # https://github.com/taiki-e/dockerfiles/blob/998a9ad25ae76314d9439681de4d5fe70bb25430/build-base/apt.Dockerfile#L68
  printf '::group::Install LLVM\n'
  if ! type -P curl >/dev/null; then
    apt_packages+=(ca-certificates curl)
  fi
  if ! type -P gpg >/dev/null; then
    apt_packages+=(gnupg)
  fi
  install_apt_packages
  codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
  case "${codename}" in
    bionic) llvm_version=13 ;;
    noble) llvm_version=18 ;;
    trixie) llvm_version=19 ;;
    # TODO: update to 21
    *) llvm_version=15 ;;
  esac
  case "${codename}" in
    noble | trixie) ;;
    *)
      _sudo mkdir -pm755 -- /etc/apt/keyrings
      retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor \
        | _sudo tee -- /etc/apt/keyrings/llvm-snapshot.gpg >/dev/null
      _sudo tee -- "/etc/apt/sources.list.d/llvm-toolchain-${codename}-${llvm_version}.list" >/dev/null \
        <<<"deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${llvm_version} main"
      ;;
  esac
  apt_packages+=(
    clang-"${llvm_version}"
    libc++-"${llvm_version}"-dev
    libc++abi-"${llvm_version}"-dev
    libclang-"${llvm_version}"-dev
    lld-"${llvm_version}"
    llvm-"${llvm_version}"
    llvm-"${llvm_version}"-dev
  )
  install_apt_packages
  for tool in /usr/bin/clang*-"${llvm_version}" /usr/bin/llvm-*-"${llvm_version}" /usr/bin/*lld*-"${llvm_version}" /usr/bin/wasm-ld-"${llvm_version}"; do
    local link="${tool%"-${llvm_version}"}"
    _sudo update-alternatives --install "${link}" "${link##*/}" "${tool}" 100
  done
  printf '::endgroup::\n'
}
install_rust_cross_toolchain() {
  printf '::group::Install toolchain\n'
  rust_cross_toolchain_used=1
  toolchain_dir=/usr/local
  # TODO: distribute rust-cross-toolchain without docker
  if ! type -P docker >/dev/null; then
    apt_packages+=(docker.io)
    if grep -Eq '^ID=debian$' /etc/os-release; then
      version_id=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2)
      case "${version_id//\"/}" in
        [0-9] | 1[0-2]) ;;
        *) apt_packages+=(docker-cli) ;;
      esac
    fi
    install_apt_packages
  fi
  # https://github.com/taiki-e/rust-cross-toolchain/pkgs/container/rust-cross-toolchain
  local arch
  case "${host}" in
    x86_64*) arch=amd64 ;;
    aarch64-*) arch=arm64v8 ;;
    *) bail "unrecognized host '${host}'" ;;
  esac
  retry docker create --name rust-cross-toolchain "ghcr.io/taiki-e/rust-cross-toolchain:${target}${sys_version}-dev-${arch}"
  mkdir -p -- .setup-cross-toolchain-action-tmp
  docker cp -- "rust-cross-toolchain:/${target}" .setup-cross-toolchain-action-tmp/toolchain
  case "${target}" in
    aarch64-pc-windows-gnullvm)
      docker cp -- "rust-cross-toolchain:/opt/wine-arm64" .setup-cross-toolchain-action-tmp/wine-arm64
      _sudo cp -r -- .setup-cross-toolchain-action-tmp/wine-arm64 /opt/wine-arm64
      ;;
  esac
  docker rm -f -- rust-cross-toolchain >/dev/null
  _sudo cp -r -- .setup-cross-toolchain-action-tmp/toolchain/. "${toolchain_dir}"/
  rm -rf -- ./.setup-cross-toolchain-action-tmp
  # https://github.com/taiki-e/rust-cross-toolchain/blob/a92f4cc85408460235b024933451f0350e08b726/docker/test/entrypoint.sh#L47
  case "${target}" in
    aarch64_be-unknown-linux-gnu | armeb-unknown-linux-gnueabi* | arm-unknown-linux-gnueabihf) sysroot_dir="/usr/local/${target}/libc" ;;
    riscv32gc-unknown-linux-gnu) sysroot_dir="${toolchain_dir}/sysroot" ;;
    loongarch64-unknown-linux-gnu)
      sysroot_dir="${toolchain_dir}/target/usr"
      printf '%s\n' "LD_LIBRARY_PATH=${toolchain_dir}/target/usr/lib64:${toolchain_dir}/${target}/lib:${LD_LIBRARY_PATH:-}" >>"${GITHUB_ENV}"
      ;;
    *) sysroot_dir="${toolchain_dir}/${target}" ;;
  esac
  case "${target}" in
    *-android*)
      if [[ -n "${api_level}" ]]; then
        case "${target}" in
          arm* | thumb*) cc_target=armv7a-linux-androideabi ;;
          *) cc_target="${target}" ;;
        esac
        cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${cc_target}${api_level}-clang
CC_${target_lower}=${cc_target}${api_level}-clang
CXX_${target_lower}=${cc_target}${api_level}-clang++
AR_${target_lower}=llvm-ar
RANLIB_${target_lower}=llvm-ranlib
AR=llvm-ar
NM=llvm-nm
STRIP=llvm-strip
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
EOF
      else
        cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${target}-clang
CC_${target_lower}=${target}-clang
CXX_${target_lower}=${target}-clang++
AR_${target_lower}=llvm-ar
RANLIB_${target_lower}=llvm-ranlib
AR=llvm-ar
NM=llvm-nm
STRIP=llvm-strip
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
EOF
      fi
      ;;
    wasm32-wasi)
      # Do not use prefixed Clang for wasi due to rustc 1.68.0 bug: https://github.com/rust-lang/rust/pull/109156
      cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=clang
CC_${target_lower}=clang
CXX_${target_lower}=clang++
AR_${target_lower}=llvm-ar
RANLIB_${target_lower}=llvm-ranlib
AR=llvm-ar
NM=llvm-nm
STRIP=llvm-strip
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
EOF
      ;;
    *)
      if type -P "${target}-gcc" >/dev/null; then
        cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${target}-gcc
CC_${target_lower}=${target}-gcc
CXX_${target_lower}=${target}-g++
AR_${target_lower}=${target}-ar
RANLIB_${target_lower}=${target}-ranlib
STRIP=${target}-strip
OBJDUMP=${target}-objdump
EOF
      elif type -P "${target}-clang" >/dev/null; then
        cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${target}-clang
CC_${target_lower}=${target}-clang
CXX_${target_lower}=${target}-clang++
AR_${target_lower}=llvm-ar
RANLIB_${target_lower}=llvm-ranlib
AR=llvm-ar
NM=llvm-nm
STRIP=llvm-strip
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
EOF
      else
        bail "internal error: no linker found for ${target}"
      fi
      ;;
  esac
  printf '::endgroup::\n'
}
install_qemu() {
  if [[ ! "${qemu_version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    bail "unrecognized QEMU version '${qemu_version}'"
  fi
  if [[ -z "${rust_cross_toolchain_used:-}" ]]; then
    qemu_bin_dir=/usr/bin
  else
    qemu_bin_dir="${toolchain_dir}/bin"
    rm -f -- "${qemu_bin_dir}/qemu-${qemu_arch}"
  fi
  printf '::group::Instal QEMU\n'
  # https://github.com/taiki-e/dockerfiles/pkgs/container/qemu-user
  qemu_user_tag=":${qemu_version}"
  case "${qemu_version}" in
    8.0)
      case "${qemu_arch}" in
        # Use 8.0.2 instead of 8.0.3 for ppc64{,le}. 8.0.3 is broken for them due to incomplete backport of 8.1 patches.
        ppc64*) qemu_user_tag=@sha256:552a32adda13312fe6a33cf09855ebe46c8de52df927c86f14f727cbe574c7c9 ;;
      esac
      ;;
    9.0)
      case "${qemu_arch}" in
        # Use 9.0.2+ds-1 instead of 9.0.2+ds-2 for armeb. 9.0.2+ds-2 is broken for them.
        armeb) qemu_user_tag=@sha256:5f5b065ca1db760f33def2602f4f8468f91fd9b11c48393c5d6cd0553800df82 ;;
      esac
      ;;
  esac
  # TODO: distribute rust-cross-toolchain without docker
  if ! type -P docker >/dev/null; then
    apt_packages+=(docker.io)
    if grep -Eq '^ID=debian$' /etc/os-release; then
      version_id=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2)
      case "${version_id//\"/}" in
        [0-9] | 1[0-2]) ;;
        *) apt_packages+=(docker-cli) ;;
      esac
    fi
    install_apt_packages
  fi
  retry docker create --name qemu-user "ghcr.io/taiki-e/qemu-user${qemu_user_tag}"
  mkdir -p -- .setup-cross-toolchain-action-tmp
  docker cp -- "qemu-user:/usr/bin/qemu-${qemu_arch}" ".setup-cross-toolchain-action-tmp/qemu-${qemu_arch}"
  docker rm -f -- qemu-user >/dev/null
  _sudo mv -- ".setup-cross-toolchain-action-tmp/qemu-${qemu_arch}" "${qemu_bin_dir}"/
  rm -rf -- ./.setup-cross-toolchain-action-tmp
  printf '::endgroup::\n'
  x "qemu-${qemu_arch}" --version
}
# Refs: https://github.com/qemu/qemu/blob/v10.1.0/scripts/qemu-binfmt-conf.sh
register_binfmt() {
  printf '::group::Register binfmt\n'
  if [[ ! -d /proc/sys/fs/binfmt_misc ]]; then
    _sudo /sbin/modprobe binfmt_misc
  fi
  if [[ ! -f /proc/sys/fs/binfmt_misc/register ]]; then
    # TODO: return with failure instead of exit for unprivileged containers
    _sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
  fi
  case "$1" in
    qemu-user)
      local url='https://raw.githubusercontent.com/qemu/qemu/f8b2f64e2336a28bf0d50b6ef8a7d8c013e9bcf3/scripts/qemu-binfmt-conf.sh'
      if ! type -P curl >/dev/null; then
        apt_packages+=(ca-certificates curl)
        install_apt_packages
      fi
      retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -o __qemu-binfmt-conf.sh "${url}"
      sed -Ei "s/i386_magic/qemu_target_list=\"${qemu_arch}\"\\ni386_magic/" ./__qemu-binfmt-conf.sh
      chmod +x ./__qemu-binfmt-conf.sh
      _sudo ./__qemu-binfmt-conf.sh --qemu-path "${qemu_bin_dir}" --persistent yes
      rm -- ./__qemu-binfmt-conf.sh
      printf '::endgroup::\n'
      return
      ;;
    wasmtime)
      local magic='\x00asm'
      local mask='\xff\xff\xff\xff'
      ;;
    wine)
      local magic='MZ'
      local mask=''
      ;;
    *) bail "internal error: unrecognized register_binfmt argument '$1'" ;;
  esac
  printf '%s\n' "Setting ${runner_path} as binfmt interpreter for ${target}"
  _sudo tee -- /proc/sys/fs/binfmt_misc/register >/dev/null \
    <<<":${target}:M::${magic}:${mask}:${runner_path}:F"
  printf '::endgroup::\n'
}

setup_linux_host() {
  apt_packages=()
  if [[ "${host}" == "${target}" ]]; then
    # TODO: can we reduce the setup time by providing an option to skip installing packages for C++?
    # TODO: other lang? https://packages.ubuntu.com/search?lang=en&suite=noble&arch=any&searchon=names&keywords=13-aarch64-linux-gnu
    if ! type -P g++ >/dev/null; then
      apt_packages+=(g++)
      install_apt_packages
    fi
  else
    case "${target}" in
      *-linux-gnu*)
        # https://github.com/taiki-e/rust-cross-toolchain/blob/a92f4cc85408460235b024933451f0350e08b726/docker/linux-gnu.sh
        case "${target}" in
          # (tier3) Toolchains for aarch64_be-linux-gnu/armeb-linux-gnueabi/riscv32-linux-gnu is not available in APT.
          # https://github.com/taiki-e/rust-cross-toolchain/blob/a92f4cc85408460235b024933451f0350e08b726/docker/linux-gnu.sh#L17
          aarch64_be-unknown-linux-gnu | armeb-unknown-linux-gnueabi* | riscv32gc-unknown-linux-gnu | loongarch64-unknown-linux-gnu) install_rust_cross_toolchain ;;
          arm-unknown-linux-gnueabihf)
            # (tier2) Ubuntu's gcc-arm-linux-gnueabihf is v7
            # https://github.com/taiki-e/rust-cross-toolchain/blob/a92f4cc85408460235b024933451f0350e08b726/docker/linux-gnu.sh#L55
            bail "target '${target}' not yet supported; consider using armv7-unknown-linux-gnueabihf for testing armhf or arm-unknown-linux-gnueabi for testing Armv6"
            ;;
          *)
            case "${target}" in
              arm*hf | thumb*hf) cc_target=arm-linux-gnueabihf ;;
              arm* | thumb*) cc_target=arm-linux-gnueabi ;;
              riscv??gc-*) cc_target="${target/gc-unknown/}" ;;
              sparc-*)
                # Toolchain for sparc-linux-gnu is not available in APT,
                # but we can use -m32 with sparc64-linux-gnu multilib.
                cc_target=sparc-linux-gnu
                apt_target=sparc64-linux-gnu
                multilib=1
                ;;
              *) cc_target="${target/-unknown/}" ;;
            esac
            apt_target="${apt_target:-"${cc_target/i586/i686}"}"
            case "${target}" in
              aarch64* | arm64*) dpkg_arch=arm64 ;;
              arm*hf | thumb*hf) dpkg_arch=armhf ;;
              arm* | thumb*) dpkg_arch=armel ;;
              i?86-*) dpkg_arch=i386 ;;
              m68k-*) dpkg_arch=m68k ;;
              mips-*) dpkg_arch=mips ;;
              mips64el-*) dpkg_arch=mips64el ;;
              mipsel-*) dpkg_arch=mipsel ;;
              powerpc-*spe) dpkg_arch=powerpcspe ;;
              powerpc-*) dpkg_arch=powerpc ;;
              powerpc64-*) dpkg_arch=ppc64 ;;
              powerpc64le-*) dpkg_arch=ppc64el ;;
              riscv64gc-*) dpkg_arch=riscv64 ;;
              s390x-*) dpkg_arch=s390x ;;
              sparc-*) dpkg_arch=sparc ;;
              sparc64-*) dpkg_arch=sparc64 ;;
              x86_64*x32) dpkg_arch=x32 ;;
              x86_64*) dpkg_arch=amd64 ;;
            esac
            if [[ -z "${use_qemu}" ]]; then
              case "${host}" in
                aarch64-*)
                  case "${target}" in
                    armv7*hf | thumbv7*hf)
                      _sudo dpkg --add-architecture "${dpkg_arch}"
                      # TODO: can we reduce the setup time by providing an option to skip installing packages for C++?
                      # TODO: other lang?
                      apt_packages+=("libstdc++6:${dpkg_arch}")
                      ;;
                  esac
                  ;;
              esac
            fi
            # TODO: can we reduce the setup time by providing an option to skip installing packages for C++?
            # TODO: other lang? https://packages.ubuntu.com/search?lang=en&suite=noble&arch=any&searchon=names&keywords=13-aarch64-linux-gnu
            apt_packages+=("g++-${multilib:+multilib-}${apt_target/_/-}")
            # https://github.com/taiki-e/rust-cross-toolchain/blob/fcb7a7e6ca14333d93c528f34a1def5a38745b3a/docker/test/entrypoint.sh
            sysroot_dir="/usr/${apt_target}"
            case "${target}" in
              sparc-*)
                cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${target}-gcc
CC_${target_lower}=${target}-gcc
CXX_${target_lower}=${target}-g++
EOF
                ;;
              *)
                cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${apt_target}-gcc
CC_${target_lower}=${apt_target}-gcc
CXX_${target_lower}=${apt_target}-g++
EOF
                ;;
            esac
            cat >>"${GITHUB_ENV}" <<EOF
AR_${target_lower}=${apt_target}-ar
RANLIB_${target_lower}=${apt_target}-ranlib
STRIP=${apt_target}-strip
OBJDUMP=${apt_target}-objdump
PKG_CONFIG_PATH=/usr/lib/${apt_target}/pkgconfig:${PKG_CONFIG_PATH:-}
PKG_CONFIG_SYSROOT_DIR=${sysroot_dir}
EOF
            ;;
        esac
        ;;
      *-linux-musl*)
        sys_version=1.2
        # https://github.com/rust-lang/rust/pull/107129
        if [[ "${rustc_minor_version}" -lt 71 ]]; then
          case "${target}" in
            hexagon-*) ;;
            *) sys_version=1.1 ;;
          esac
        fi
        install_rust_cross_toolchain
        ;;
      *-linux-uclibc*)
        install_rust_cross_toolchain
        ;;
      *-android*)
        # https://dl.google.com/android/repository/sys-img/android/sys-img.xml
        install_rust_cross_toolchain
        case "${runner}" in
          none) ;;
          *)
            if ! type -P curl >/dev/null; then
              apt_packages+=(ca-certificates curl)
            fi
            if ! type -P unzip >/dev/null; then
              apt_packages+=(unzip)
            fi
            if ! type -P e2cp >/dev/null; then
              apt_packages+=(e2tools)
            fi
            install_apt_packages
            _sudo mkdir -p -- /system/{bin,lib,lib64}
            # /data may conflict with the existing directory.
            data_dir="${HOME}/.setup-cross-toolchain-action/data"
            mkdir -p -- "${data_dir}"
            case "${target}" in
              aarch64* | arm64*)
                lib_target=aarch64-linux-android
                arch=arm64-v8a
                ;;
              arm* | thumb*)
                lib_target=arm-linux-androideabi
                arch=armeabi-v7a
                ;;
              i686-*)
                lib_target=i686-linux-android
                arch=x86
                ;;
              x86_64*)
                lib_target=x86_64-linux-android
                arch=x86_64
                ;;
              *) bail "unrecognized target '${target}'" ;;
            esac
            img_api_level=24
            case "${target}" in
              aarch64* | arm* | thumb*) revision=r07 ;;
              i686-* | x86_64*) revision=r08 ;;
              *) bail "unrecognized target '${target}'" ;;
            esac
            file="${arch}-${img_api_level}_${revision}.zip"
            prefix=''
            case "${target}" in
              x86_64* | aarch64* | arm64*) prefix='64' ;;
            esac
            # Note that due to the Android SDK license, rust-cross-toolchain cannot redistribute sys-img distributed by Google.
            retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -O "https://dl.google.com/android/repository/sys-img/android/${file}"
            unzip -q "${file}" "${arch}/system.img"
            for bin in "linker${prefix}" sh; do
              _sudo e2cp -p "${arch}/system.img:/bin/${bin}" "/system/bin/"
            done
            for lib in "${toolchain_dir}/sysroot/usr/lib/${lib_target}/${img_api_level}"/*.so; do
              _sudo e2cp -p "${arch}/system.img:/lib${prefix}/${lib##*/}" "/system/lib${prefix}/"
            done
            _sudo cp -- "${toolchain_dir}/sysroot/usr/lib/${lib_target}/libc++_shared.so" "/system/lib${prefix}/"
            rm -- "${file}"
            rm -rf -- "${arch}"
            cat >>"${GITHUB_ENV}" <<EOF
ANDROID_DATA=${data_dir}
ANDROID_DNS_MODE=local
ANDROID_ROOT=/system
TMPDIR=/tmp
EOF
            ;;
        esac
        ;;
      *-freebsd*)
        install_rust_cross_toolchain
        install_llvm
        ;;
      *-netbsd* | *-illumos*)
        install_rust_cross_toolchain
        ;;
      *-wasi*)
        install_rust_cross_toolchain
        # https://github.com/taiki-e/rust-cross-toolchain/blob/fcb7a7e6ca14333d93c528f34a1def5a38745b3a/docker/test/entrypoint.sh#L174
        printf 'CXXSTDLIB=c++\n' >>"${GITHUB_ENV}"
        case "${runner}" in
          '' | wasmtime)
            printf '%s\n' "CARGO_TARGET_${target_upper}_RUNNER=${target}-runner" >>"${GITHUB_ENV}"
            x wasmtime --version
            runner_path="${toolchain_dir}/bin/${target}-runner"
            register_binfmt wasmtime
            ;;
          none) ;;
          *) bail "unrecognized runner '${runner}'" ;;
        esac
        ;;
      *-windows-gnu*)
        arch="${target%%-*}"
        case "${target}" in
          *-gnullvm*) install_rust_cross_toolchain ;;
          *)
            apt_target="${arch}-w64-mingw32"
            apt_packages+=("g++-mingw-w64-${arch/_/-}")
            sysroot_dir="/usr/${apt_target}"
            cat >>"${GITHUB_ENV}" <<EOF
CARGO_TARGET_${target_upper}_LINKER=${apt_target}-gcc-posix
CC_${target_lower}=${apt_target}-gcc-posix
CXX_${target_lower}=${apt_target}-g++-posix
AR_${target_lower}=${apt_target}-ar
RANLIB_${target_lower}=${apt_target}-ranlib
STRIP=${apt_target}-strip
OBJDUMP=${apt_target}-objdump
EOF
            ;;
        esac
        case "${runner}" in
          none) ;;
          *)
            printf '%s\n' "CARGO_TARGET_${target_upper}_RUNNER=${target}-runner" >>"${GITHUB_ENV}"
            case "${target}" in
              aarch64* | arm64*)
                wine_root=/opt/wine-arm64
                wine_exe="${wine_root}"/bin/wine
                qemu_arch=aarch64
                if [[ -n "${INPUT_WINE:-}" ]]; then
                  warn "specifying Wine version for AArch64 Windows is not yet supported"
                fi
                case "${runner}" in
                  '' | wine) ;;
                  wine@*) bail "specifying Wine version for AArch64 Windows is not yet supported" ;;
                  *) bail "unrecognized runner '${runner}'" ;;
                esac
                _sudo cp -- "${wine_root}"/lib/ld-linux-aarch64.so.1 /lib/
                qemu_version="${INPUT_QEMU:-"${default_qemu_version}"}"
                install_qemu
                x "${wine_exe}" --version
                wineboot="${wine_root}/bin/wineserver"
                ;;
              i686-* | x86_64*)
                wine_exe=wine
                # https://wiki.winehq.org/Ubuntu
                # https://wiki.winehq.org/Debian
                # https://dl.winehq.org/wine-builds
                # https://wiki.winehq.org/Wine_User%27s_Guide#Wine_from_WineHQ
                codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
                case "${runner}" in
                  '' | wine) wine_version="${INPUT_WINE:-"${default_wine_version}"}" ;;
                  wine@*) wine_version="${runner#*@}" ;;
                  *) bail "unrecognized runner '${runner}'" ;;
                esac
                _sudo dpkg --add-architecture i386
                if [[ "${codename}" == 'noble' ]] && [[ "${wine_version}" == '9.0.0.0' ]]; then
                  # winehq supports Ubuntu 24.04 but Wine 9.0.0 is not available in it
                  # https://dl.winehq.org/wine-builds/ubuntu/dists/noble/main/binary-amd64
                  apt_packages+=(wine wine32 wine64)
                else
                  distro=$(grep -E '^ID=' /etc/os-release | cut -d= -f2)
                  _sudo mkdir -pm755 -- /etc/apt/keyrings
                  if ! type -P curl >/dev/null; then
                    apt_packages+=(ca-certificates curl)
                    install_apt_packages
                  fi
                  retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://dl.winehq.org/wine-builds/winehq.key \
                    | _sudo tee -- /etc/apt/keyrings/winehq-archive.key >/dev/null
                  retry curl --proto '=https' --tlsv1.2 -fsSLR --retry 10 --retry-connrefused "https://dl.winehq.org/wine-builds/${distro}/dists/${codename}/winehq-${codename}.sources" \
                    | _sudo tee -- "/etc/apt/sources.list.d/winehq-${codename}.sources" >/dev/null
                  if [[ "${wine_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
                    wine_branch=stable
                  elif [[ "${wine_version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
                    wine_branch=devel
                  else
                    bail "unrecognized Wine version '${wine_version}'"
                  fi
                  # The suffix is 1 in most cases, rarely 2.
                  # https://dl.winehq.org/wine-builds/ubuntu/dists/noble/main/binary-amd64
                  # https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/main/binary-amd64
                  # https://dl.winehq.org/wine-builds/ubuntu/dists/focal/main/binary-amd64
                  wine_build_suffix=1
                  apt_packages+=(
                    "winehq-${wine_branch}=${wine_version}~${codename}-${wine_build_suffix}"
                    "wine-${wine_branch}=${wine_version}~${codename}-${wine_build_suffix}"
                    "wine-${wine_branch}-amd64=${wine_version}~${codename}-${wine_build_suffix}"
                    "wine-${wine_branch}-i386=${wine_version}~${codename}-${wine_build_suffix}"
                    "wine-${wine_branch}-dev=${wine_version}~${codename}-${wine_build_suffix}"
                  )
                fi
                install_apt_packages
                x wine --version
                wineboot=wineboot
                ;;
              *) bail "internal error: unrecognized target '${target}'" ;;
            esac
            case "${target}" in
              *-gnullvm*) winepath="${toolchain_dir}/${target}/bin" ;;
              *)
                gcc_lib=$(basename -- "$(ls -d -- "/usr/lib/gcc/${apt_target}"/*posix)")
                winepath="/usr/lib/gcc/${apt_target}/${gcc_lib};/usr/${apt_target}/lib"
                ;;
            esac
            runner_path="/usr/local/bin/${target}-runner"
            cat >".${target}-runner.tmp" <<EOF
#!/bin/sh
set -eu
export HOME=/tmp/home
mkdir -p -- "\${HOME}"/.wine
export WINEPREFIX=/tmp/wine
mkdir -p -- "\${WINEPREFIX}"
if [ ! -e /tmp/WINEBOOT ]; then
    ${wineboot} &>/dev/null
    touch -- /tmp/WINEBOOT
fi
export WINEPATH="${winepath};\${WINEPATH:-}"
exec ${wine_exe} "\$@"
EOF
            chmod +x ".${target}-runner.tmp"
            _sudo mv -- ".${target}-runner.tmp" "${runner_path}"
            register_binfmt wine
            ;;
        esac
        ;;
      *) bail "target '${target}' is not supported yet on Linux host" ;;
    esac
  fi
  if [[ -n "${sysroot_dir:-}" ]]; then
    printf '%s\n' "BINDGEN_EXTRA_CLANG_ARGS_${target_lower}=--sysroot=${sysroot_dir}" >>"${GITHUB_ENV}"
  fi

  if [[ -n "${use_qemu}" ]]; then
    # https://github.com/taiki-e/rust-cross-toolchain/blob/fcb7a7e6ca14333d93c528f34a1def5a38745b3a/docker/test/entrypoint.sh#L307
    # We basically set the newer and more powerful CPU as the
    # default QEMU_CPU so that we can test more CPU features.
    # In some contexts, we want to test for a specific CPU,
    # so respect user-set QEMU_CPU.
    case "${target}" in
      aarch64* | arm64*)
        case "${target}" in
          aarch64_be-*) qemu_arch=aarch64_be ;;
          *) qemu_arch=aarch64 ;;
        esac
        case "${qemu_version}" in
          7.* | 8.0) default_qemu_cpu=a64fx ;; # Armv8.2-A + SVE
          *) default_qemu_cpu=neoverse-v1 ;;   # Armv8.4-A + SVE + more features (https://developer.arm.com/Processors/Neoverse%20V1)
        esac
        ;;
      arm* | thumb*)
        case "${target}" in
          armeb* | thumbeb*) qemu_arch=armeb ;;
          *) qemu_arch=arm ;;
        esac
        ;;
      i?86-*) qemu_arch=i386 ;;
      hexagon-*) qemu_arch=hexagon ;;
      loongarch64-*) qemu_arch=loongarch64 ;;
      m68k-*) qemu_arch=m68k ;;
      mips-* | mipsel-*) qemu_arch="${target%%-*}" ;;
      mips64-* | mips64el-*)
        qemu_arch="${target%%-*}"
        # As of QEMU 6.1, only Loongson-3A4000 supports MSA instructions with mips64r5.
        default_qemu_cpu=Loongson-3A4000
        ;;
      mipsisa32r6-* | mipsisa32r6el-*)
        qemu_arch="${target%%-*}"
        qemu_arch="${qemu_arch/isa32r6/}"
        default_qemu_cpu=mips32r6-generic
        ;;
      mipsisa64r6-* | mipsisa64r6el-*)
        qemu_arch="${target%%-*}"
        qemu_arch="${qemu_arch/isa64r6/64}"
        default_qemu_cpu=I6400
        ;;
      powerpc-*spe)
        qemu_arch=ppc
        default_qemu_cpu=e500v2
        ;;
      powerpc-*)
        qemu_arch=ppc
        default_qemu_cpu=Vger
        ;;
      powerpc64-* | powerpc64le-*)
        qemu_arch="${target%%-*}"
        qemu_arch="${qemu_arch/powerpc/ppc}"
        default_qemu_cpu=power10
        ;;
      riscv32*) qemu_arch=riscv32 ;;
      riscv64*) qemu_arch=riscv64 ;;
      s390x-*) qemu_arch=s390x ;;
      sparc-*) qemu_arch=sparc32plus ;;
      sparc64-* | sparcv9-*) qemu_arch=sparc64 ;;
      x86_64*)
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
    printf '%s\n' "CARGO_TARGET_${target_upper}_RUNNER=qemu-${qemu_arch}" >>"${GITHUB_ENV}"
    # QEMU's multi-threading support is incomplete and slow.
    printf 'RUST_TEST_THREADS=1\n' >>"${GITHUB_ENV}"
    if [[ -n "${default_qemu_cpu:-}" ]] && [[ -z "${QEMU_CPU:-}" ]]; then
      printf 'QEMU_CPU=%s\n' "${default_qemu_cpu}" >>"${GITHUB_ENV}"
    fi
    case "${target}" in
      *-android*) ;;
      *)
        if [[ -n "${sysroot_dir:-}" ]] && [[ -z "${QEMU_LD_PREFIX:-}" ]]; then
          printf 'QEMU_LD_PREFIX=%s\n' "${sysroot_dir}" >>"${GITHUB_ENV}"
        fi
        ;;
    esac
    install_qemu
    register_binfmt qemu-user
  fi

  install_apt_packages

  case "${target}" in
    sparc-unknown-linux-gnu)
      # https://github.com/taiki-e/rust-cross-toolchain/blob/a92f4cc85408460235b024933451f0350e08b726/docker/linux-gnu.Dockerfile#L44
      # The interpreter for sparc-linux-gnu is /lib/ld-linux.so.2,
      # so lib/ld-linux.so.2 must be target sparc-linux-gnu to run binaries on qemu-user.
      toolchain_dir=/usr
      _sudo rm -rf -- "${toolchain_dir:?}/${apt_target}/lib"
      _sudo rm -rf -- "${toolchain_dir:?}/${apt_target}/lib64"
      _sudo ln -s -- lib32 "${toolchain_dir}/${apt_target}/lib"
      gcc_version="$("${apt_target}"-gcc --version | sed -En '1 s/^.*\) //p')"
      common_flags="-m32 -mv8plus -L${toolchain_dir}/${apt_target}/lib32 -L${toolchain_dir}/${apt_target}/lib/gcc-cross/${apt_target}/${gcc_version}/32"
      cat >"/usr/local/bin/${target}-gcc" <<EOF2
#!/bin/sh
set -eu
exec ${toolchain_dir}/bin/${apt_target}-gcc ${common_flags} "\$@"
EOF2
      cat >"/usr/local/bin/${target}-g++" <<EOF2
#!/bin/sh
set -eu
exec ${toolchain_dir}/bin/${apt_target}-g++ ${common_flags} "\$@"
EOF2
      chmod +x "/usr/local/bin/${target}-gcc" "/usr/local/bin/${target}-g++"
      ;;
  esac
}

case "${host}" in
  *-linux-gnu*)
    use_qemu=''
    qemu_version="${INPUT_QEMU:-"${default_qemu_version}"}"
    case "${target}" in
      *-linux-* | *-android*)
        case "${runner}" in
          '')
            if [[ "${host}" != "${target}" ]]; then
              case "${host}" in
                x86_64*)
                  case "${target}" in
                    # On x86 with SSE2, qemu-user is not used by default.
                    x86_64* | i686-*) ;;
                    *) use_qemu=1 ;;
                  esac
                  ;;
                aarch64-*)
                  case "${target}" in
                    aarch64-*) ;;
                    armv7*hf | thumbv7*hf)
                      if ! lscpu | grep -Eq 'CPU.*32-bit'; then
                        use_qemu=1
                      fi
                      ;;
                    *) use_qemu=1 ;;
                  esac
                  ;;
                *) bail "unrecognized host '${host}' for target '${target}'" ;;
              esac
            fi
            ;;
          native | none) ;;
          qemu-user) use_qemu=1 ;;
          qemu-user@*)
            use_qemu=1
            qemu_version="${runner#*@}"
            ;;
          *) bail "unrecognized runner '${runner}'" ;;
        esac
        ;;
      *-freebsd* | *-netbsd* | *-illumos*)
        # Runners for BSDs and illumos are not supported yet.
        # We are currently testing the uploaded artifacts manually with Cirrus CI and local VM.
        # https://cirrus-ci.org/guide/FreeBSD
        case "${runner}" in
          '' | none) ;;
          *) bail "unrecognized runner '${runner}'" ;;
        esac
        ;;
      *-wasi*) ;;        # Checked in setup_linux_host
      *-windows-gnu*) ;; # Checked in setup_linux_host
      *) bail "target '${target}' is not supported yet on Linux host" ;;
    esac
    setup_linux_host
    ;;
  # GitHub-provided macOS/Windows runners support cross-compile for other architectures or environments.
  *-darwin*)
    case "${target}" in
      *-apple-*) ;;
      *) bail "target '${target}' is not supported yet on macOS host" ;;
    esac
    case "${runner}" in
      '' | native | none) ;;
      *) bail "unrecognized runner '${runner}'" ;;
    esac
    ;;
  *-windows*)
    case "${target}" in
      *-windows*) ;;
      *) bail "target '${target}' is not supported yet on Windows host" ;;
    esac
    case "${runner}" in
      '' | native | none) ;;
      *) bail "unrecognized runner '${runner}'" ;;
    esac
    ;;
  *) bail "unsupported host '${host}'" ;;
esac

if grep -Eq "^${target}$" <<<"${rustup_target_list}"; then
  if [[ "${target}" != "${host}" ]]; then
    retry rustup target add "${target}"
  fi
  # Note: -Z doctest-xcompile doesn't compatible with -Z build-std yet.
  if [[ "${rustc_version}" =~ nightly|dev ]]; then
    if cargo -Z help | grep -Eq '\bZ doctest-xcompile\b'; then
      printf 'DOCTEST_XCOMPILE=-Zdoctest-xcompile\n' >>"${GITHUB_ENV}"
    fi
  fi
else
  # for -Z build-std
  retry rustup component add rust-src
  printf 'BUILD_STD=-Zbuild-std\n' >>"${GITHUB_ENV}"
fi
printf 'CARGO_BUILD_TARGET=%s\n' "${target}" >>"${GITHUB_ENV}"
