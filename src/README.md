**I2C DesignWare**

Builds and loads the Synopsys DesignWare I2C driver (`i2c-designware-platform`) for the running Unraid kernel, which Unraid does not ship. Needed for the I2C pins on boards like the ODROID-H3. Modules are rebuilt automatically in Docker after an OS update. Buses appear as `/dev/i2c-designware-N`.
