# Usage: lcd-test.py BUS ADDR [line1 .. line4]
# Minimal HD44780 over PCF8574 (4-bit mode) - same protocol as Hardkernel's lcddriver.py
import sys, time
from smbus2 import SMBus

BL, EN, RS = 0x08, 0x04, 0x01
ROWS = (0x80, 0xC0, 0x94, 0xD4)

class LCD:
    def __init__(self, bus, addr):
        self.bus, self.addr = SMBus(bus), addr
        for c in (0x33, 0x32, 0x28, 0x0C, 0x06, 0x01):
            self.cmd(c)
        time.sleep(0.005)

    def _write4(self, v):
        self.bus.write_byte(self.addr, v | BL)
        self.bus.write_byte(self.addr, v | BL | EN); time.sleep(0.0005)
        self.bus.write_byte(self.addr, (v | BL) & ~EN); time.sleep(0.0001)

    def _send(self, v, mode=0):
        self._write4(mode | (v & 0xF0))
        self._write4(mode | ((v << 4) & 0xF0))

    def cmd(self, c): self._send(c)

    def line(self, row, text):
        self.cmd(ROWS[row])
        for ch in text.ljust(20)[:20]:
            self._send(ord(ch), RS)

if __name__ == "__main__":
    # bus: number (11) or device path (/dev/i2c-designware-0); addr: hex (27)
    bus = int(sys.argv[1]) if sys.argv[1].isdigit() else sys.argv[1]
    addr = int(sys.argv[2], 16)
    lcd = LCD(bus, addr)
    for i, t in enumerate(sys.argv[3:7]):
        lcd.line(i, t)
