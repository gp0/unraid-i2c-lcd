#!/bin/bash
# Build the Synopsys DesignWare I2C modules for an Unraid kernel.
# Compiles inside a throwaway container using kernel.org sources plus
# Unraid's own kernel config from /usr/src/linux-<kver>/config.
#
# Usage: build.sh [kernel-release]   (default: running kernel)
set -euo pipefail

KVER=${1:-$(uname -r)}
BASE=${KVER%-Unraid}
SRC=/usr/src/linux-$KVER
CACHE=${CACHE:-/boot/config/plugins/i2c-designware}
OUT=$CACHE/$KVER

log() { echo "$(date '+%F %T') build[$KVER]: $*"; }

[ -f "$SRC/config" ] || { log "missing $SRC/config"; exit 1; }

# Match the compiler major version Unraid used, e.g. CONFIG_GCC_VERSION=160200 -> gcc:16
GCC_MAJOR=$(sed -n 's/^CONFIG_GCC_VERSION=\([0-9]*\)[0-9]\{4\}$/\1/p' "$SRC/config")
IMAGE=${IMAGE:-gcc:${GCC_MAJOR:-latest}}

PULLED=0
docker image inspect "$IMAGE" >/dev/null 2>&1 || PULLED=1

mkdir -p "$CACHE"
TMP=$(mktemp -d "$CACHE/.build-XXXXXX")
cleanup() {
  rm -rf "$TMP"
  if [ "$PULLED" = 1 ]; then docker rmi -f "$IMAGE" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

log "building with $IMAGE"
docker run --rm \
  -v "$SRC:/unraid:ro" \
  -v "$TMP:/out" \
  -e BASE="$BASE" -e DEBIAN_FRONTEND=noninteractive \
  "$IMAGE" bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y -qq flex bison bc libelf-dev libssl-dev xz-utils curl kmod >/dev/null

    major=${BASE%%.*}
    cd /usr/src
    curl -fsSL "https://cdn.kernel.org/pub/linux/kernel/v${major}.x/linux-${BASE}.tar.xz" | tar xJ
    cd "linux-${BASE}"

    cp /unraid/config .config
    scripts/config --module I2C_DESIGNWARE_CORE --module I2C_DESIGNWARE_PLATFORM \
                   --disable I2C_DESIGNWARE_PCI --disable I2C_DESIGNWARE_SLAVE
    make -s olddefconfig
    grep -q "^CONFIG_I2C_DESIGNWARE_PLATFORM=m" .config

    make -s -j"$(nproc)" modules_prepare
    # No Module.symvers without a full kernel build; symbols resolve at load time.
    KBUILD_MODPOST_WARN=1 make -s -j"$(nproc)" M=drivers/i2c/busses modules 2>&1 \
      | grep -vE "undefined!|Module.symvers|unresolved symbol|dependencies or modversions|KBUILD_MODPOST_WARN|at your own risk" || true

    for m in drivers/i2c/busses/i2c-designware-core.ko drivers/i2c/busses/i2c-designware-platform.ko; do
      strip --strip-debug "$m"
      cp "$m" /out/
    done
  '

for m in "$TMP"/*.ko; do
  vm=$(modinfo -F vermagic "$m")
  case "$vm" in
    "$KVER "*) ;;
    *) log "vermagic mismatch in $(basename "$m"): $vm"; exit 1 ;;
  esac
done

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$TMP"/*.ko "$OUT"/
log "modules cached in $OUT"
