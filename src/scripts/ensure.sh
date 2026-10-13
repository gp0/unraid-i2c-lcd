#!/bin/bash
# Load the modules, building them first in the background if this kernel has none cached.
PLUGIN=/usr/local/emhttp/plugins/i2c-designware
LOG=/var/log/i2c-designware.log
LOCK=/var/run/i2c-designware.lock

"$PLUGIN/scripts/load.sh" >>"$LOG" 2>&1
rc=$?
[ $rc = 2 ] || exit $rc

if ! docker info >/dev/null 2>&1; then
  echo "$(date '+%F %T') ensure: no modules for $(uname -r) yet, will build once Docker is running" >>"$LOG"
  exit 0
fi

# emhttp waits for event scripts, so build detached.
nohup flock -n "$LOCK" bash -c "
  $PLUGIN/scripts/build.sh && $PLUGIN/scripts/load.sh || \
    /usr/local/emhttp/webGui/scripts/notify -e i2c-designware -i alert \
      -s 'I2C DesignWare build failed' -d 'Kernel $(uname -r) - see $LOG'
" >>"$LOG" 2>&1 </dev/null &
echo "building modules for $(uname -r) in the background, see $LOG"
