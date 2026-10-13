#!/bin/bash
# Load cached DesignWare I2C modules for the running kernel.
# Exit codes: 0 = loaded (or already loaded), 2 = no modules cached for this kernel.
set -uo pipefail

KVER=$(uname -r)
CACHE=${CACHE:-/boot/config/plugins/i2c-designware}
DIR=$CACHE/$KVER
RULES=/etc/udev/rules.d/99-i2c-designware.rules
PLUGIN=/usr/local/emhttp/plugins/i2c-designware

log() { echo "$(date '+%F %T') load[$KVER]: $*"; }

modprobe i2c-dev

if ! cmp -s "$PLUGIN/99-i2c-designware.rules" "$RULES"; then
  cp "$PLUGIN/99-i2c-designware.rules" "$RULES"
  udevadm control --reload
fi

if ! grep -q '^i2c_designware_platform ' /proc/modules; then
  [ -f "$DIR/i2c-designware-core.ko" ] && [ -f "$DIR/i2c-designware-platform.ko" ] || exit 2
  grep -q '^i2c_designware_core ' /proc/modules || insmod "$DIR/i2c-designware-core.ko" || exit 1
  insmod "$DIR/i2c-designware-platform.ko" || exit 1
  log "modules loaded"
fi

udevadm trigger --subsystem-match=i2c-dev
udevadm settle
for l in /dev/i2c-designware-*; do
  [ -e "$l" ] && log "$l -> $(readlink "$l")"
done

# Keep cached builds for the three most recent kernels (current always kept).
ls -1dt "$CACHE"/*/ 2>/dev/null | grep -v "/$KVER/$" | tail -n +3 | xargs -r rm -rf
exit 0
