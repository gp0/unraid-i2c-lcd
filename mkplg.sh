#!/bin/bash
# Assemble plugin/i2c-designware.plg from src/ (files are embedded inline).
# Usage: mkplg.sh [version]   (default: today, yyyy.mm.dd)
set -euo pipefail
cd "$(dirname "$0")"

NAME=i2c-designware
VERSION=${1:-$(date +%Y.%m.%d)}
DEST=/usr/local/emhttp/plugins/$NAME
OUT=plugin/$NAME.plg

inline() { # <dest-path> <src-file> <mode>
  grep -q ']]>' "$2" && { echo "$2 contains ]]>" >&2; exit 1; }
  printf '<FILE Name="%s" Mode="%s">\n<INLINE>\n<![CDATA[\n' "$1" "$3"
  cat "$2"
  printf ']]>\n</INLINE>\n</FILE>\n\n'
}

{
cat <<HEAD
<?xml version='1.0' standalone='yes'?>
<!DOCTYPE PLUGIN>

<PLUGIN
  name="$NAME"
  author="gp0"
  version="$VERSION"
  pluginURL="https://raw.githubusercontent.com/gp0/unraid-i2c-lcd/main/$OUT"
  support="https://github.com/gp0/unraid-i2c-lcd/issues"
  min="7.0.0"
  icon="microchip"
>

<CHANGES>
<![CDATA[
$(cat CHANGES.md)
]]>
</CHANGES>

<!--
The plugin manager skips files that already exist, so clear old ones for updates.
-->
<FILE Run="/bin/bash">
<INLINE>
rm -rf $DEST
</INLINE>
</FILE>

HEAD

inline "$DEST/README.md"               src/README.md                 0644
inline "$DEST/99-i2c-designware.rules"  src/99-i2c-designware.rules   0644
for f in src/scripts/*; do inline "$DEST/scripts/$(basename "$f")" "$f" 0755; done
for f in src/event/*;   do inline "$DEST/event/$(basename "$f")"   "$f" 0755; done

cat <<'TAIL'
<!--
The 'install' script.
-->
<FILE Run="/bin/bash">
<INLINE>
<![CDATA[
mkdir -p /boot/config/plugins/i2c-designware
/usr/local/emhttp/plugins/i2c-designware/scripts/ensure.sh
tail -n 5 /var/log/i2c-designware.log 2>/dev/null
]]>
</INLINE>
</FILE>

<!--
The 'remove' script.
-->
<FILE Run="/bin/bash" Method="remove">
<INLINE>
<![CDATA[
rmmod i2c_designware_platform i2c_designware_core 2>/dev/null
rm -f /etc/udev/rules.d/99-i2c-designware.rules
udevadm control --reload
rm -rf /usr/local/emhttp/plugins/i2c-designware
rm -rf /boot/config/plugins/i2c-designware
]]>
</INLINE>
</FILE>

</PLUGIN>
TAIL
} > "$OUT"
echo "wrote $OUT ($VERSION)"
