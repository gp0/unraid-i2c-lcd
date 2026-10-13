# unraid-i2c-lcd

Unraid plugin that provides the **Synopsys DesignWare I2C driver** (`i2c-designware-core`, `i2c-designware-platform`), which the stock Unraid kernel does not include. Without it, the I2C pins on boards like the **ODROID-H3/H3+** (Intel Jasper Lake LPSS I2C) are unusable, e.g. for the [Hardkernel I2C 20x4 LCD](https://wiki.odroid.com/odroid-h3/application_note/i2c_20x4_lcd).

## Install

Plugins → Install Plugin:

```
https://raw.githubusercontent.com/gp0/unraid-i2c-lcd/main/plugin/i2c-designware.plg
```

The first install builds the modules (~1–3 min, in the background). Progress: `/var/log/i2c-designware.log`.

## How it works

- **Build** (`build.sh`): runs in a throwaway `gcc:<major>` container. Downloads the matching kernel.org source, applies Unraid's own config from `/usr/src/linux-<kver>-Unraid/config`, enables the DesignWare modules and builds only `drivers/i2c/busses`. The build image is removed afterwards. Unraid modules are unsigned and built without modversions, so a matching vermagic is all that is needed; the script verifies it.
- **Cache**: `/boot/config/plugins/i2c-designware/<kver>/*.ko` on the flash drive (builds for the three most recent kernels are kept).
- **Boot**: Unraid reinstalls the plugin from flash, which `insmod`s the cached modules for the running kernel.
- **After an OS update**: no cached modules for the new kernel → rebuilt automatically on the `docker_started` event, then loaded. A notification is raised if the build fails.
- **Stable device names**: a udev rule adds `/dev/i2c-designware-N` (N = controller index) since the `/dev/i2c-<n>` numbers shift with load order.

## Using it

Pass the bus to a container:

```
docker run --device /dev/i2c-designware-0 ...
```

Quick LCD test (HD44780 + PCF8574 backpack at `0x27`):

```
docker run --rm --device /dev/i2c-designware-0 -v /path/to/tools/lcd-test.py:/t.py:ro alpine:3.22 \
  sh -c "apk add -q i2c-tools py3-pip && pip install -q --break-system-packages smbus2 \
         && i2cdetect -y -r /dev/i2c-designware-0 \
         && python3 /t.py /dev/i2c-designware-0 27 'Hello' 'from' 'Unraid'"
```

On the ODROID-H3 the LCD header pins are on `i2c-designware-0`.

## Limitations

- Needs Docker running and internet access (kernel.org, Docker Hub) once per new Unraid version; the driver is unavailable until that build finishes.
- Relies on Unraid shipping its kernel config in `/usr/src` and not enforcing module signatures (true as of 7.3.3).

## Development

Scripts live in `src/`; `./mkplg.sh [version]` embeds them into `plugin/i2c-designware.plg` (version defaults to today). Add an entry to `CHANGES.md` first. Test on a server without pushing:

```
scp plugin/i2c-designware.plg root@tower:/tmp/ && ssh root@tower plugin install /tmp/i2c-designware.plg forced   # "forced" reinstalls the same version
```
