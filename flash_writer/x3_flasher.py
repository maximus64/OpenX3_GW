#  Copyright © 2021 Khoa Hoang <admin@khoahoang.com>

#  Permission is hereby granted, free of charge, to any person obtaining a
#  copy of this software and associated documentation files (the “Software”),
#  to deal in the Software without restriction, including without limitation
#  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#  and/or sell copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following conditions:

#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.

#  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#  IN THE SOFTWARE.

import urjtag
import argparse
import sys
import time
from time import sleep

INPUT = 0
OUTPUT = 1

# NOTE: These are bit number is DR EXTEST.
# You can get this information from BSDL file
# Control pins
PIN_CE_MAIN = 110
PIN_CE_MAIN_DIR = 109

PIN_CE_BAK = 112
PIN_CE_BAK_DIR = 111

PIN_OE = 104
PIN_OE_DIR = 103

PIN_WE = 106
PIN_WE_DIR = 105

# Address pins
PIN_A0 = 100
PIN_A1 = 150
PIN_A2 = 152
PIN_A3 = 154
PIN_A4 = 158
PIN_A5 = 160
PIN_A6 = 164
PIN_A7 = 166
PIN_A8 = 170
PIN_A9 = 172
PIN_A10 = 176
PIN_A11 = 178
PIN_A12 = 182
PIN_A13 = 184
PIN_A14 = 188
PIN_A15 = 190
PIN_A16 = 194
PIN_A17 = 48
PIN_A18 = 44
PIN_A19 = 42
PIN_A20 = 38
ADDR_BUS = [PIN_A0, PIN_A1, PIN_A2, PIN_A3,
            PIN_A4, PIN_A5, PIN_A6, PIN_A7,
            PIN_A8, PIN_A9, PIN_A10, PIN_A11,
            PIN_A12, PIN_A13, PIN_A14, PIN_A15,
            PIN_A16, PIN_A17, PIN_A18, PIN_A19,
            PIN_A20]

PIN_A0_DIR = 99
PIN_A1_DIR = 149
PIN_A2_DIR = 151
PIN_A3_DIR = 153
PIN_A4_DIR = 157
PIN_A5_DIR = 159
PIN_A6_DIR = 163
PIN_A7_DIR = 165
PIN_A8_DIR = 169
PIN_A9_DIR = 171
PIN_A10_DIR = 175
PIN_A11_DIR = 177
PIN_A12_DIR = 181
PIN_A13_DIR = 183
PIN_A14_DIR = 187
PIN_A15_DIR = 189
PIN_A16_DIR = 193
PIN_A17_DIR = 47
PIN_A18_DIR = 43
PIN_A19_DIR = 41
PIN_A20_DIR = 37

ADDR_BUS_DIR = [PIN_A0_DIR, PIN_A1_DIR, PIN_A2_DIR, PIN_A3_DIR,
                PIN_A4_DIR, PIN_A5_DIR, PIN_A6_DIR, PIN_A7_DIR,
                PIN_A8_DIR, PIN_A9_DIR, PIN_A10_DIR, PIN_A11_DIR,
                PIN_A12_DIR, PIN_A13_DIR, PIN_A14_DIR, PIN_A15_DIR,
                PIN_A16_DIR, PIN_A17_DIR, PIN_A18_DIR, PIN_A19_DIR,
                PIN_A20_DIR]

# Data pins
PIN_D0 = 28
PIN_D1 = 20
PIN_D2 = 18
PIN_D3 = 52
PIN_D4 = 54
PIN_D5 = 56
PIN_D6 = 74
PIN_D7 = 78

DATA_BUS = [PIN_D0, PIN_D1, PIN_D2, PIN_D3,
            PIN_D4, PIN_D5, PIN_D6, PIN_D7]

PIN_D0_DIR = 27
PIN_D1_DIR = 19
PIN_D2_DIR = 17
PIN_D3_DIR = 51
PIN_D4_DIR = 53
PIN_D5_DIR = 55
PIN_D6_DIR = 73
PIN_D7_DIR = 77

DATA_BUS_DIR = [PIN_D0_DIR, PIN_D1_DIR, PIN_D2_DIR, PIN_D3_DIR,
                PIN_D4_DIR, PIN_D5_DIR, PIN_D6_DIR, PIN_D7_DIR]

# Flash parts
AMD_ID = 0x01
AMD_AM29F016D = 0xAD
flashchips =    { (AMD_ID, AMD_AM29F016D) :
                    {
                        "vendor": "AMD",
                        "name": "Am29F016D",
                        "size": 2 * 1024 * 1024,
                        "sector_size": 64 * 1024
                    },
                }


#urjtag.loglevel( urjtag.URJ_LOG_LEVEL_ALL )

urc = urjtag.chain()
urc.cable("usbblaster")

f = urc.get_frequency()
print(f"JTAG frequency: {f}")
#urc.set_frequency(1000000)  # TCK frequency in Hz

urc.tap_detect()

urc.part(0)

print("Enter EXTEST mode...")
urc.set_instruction("EXTEST")
urc.shift_ir()

#urc.shift_dr()


def set_addr(addr):
    for i in range(len(ADDR_BUS)):
        b = (addr >> i) & 1
        urc.set_dr_in(b, ADDR_BUS[i], ADDR_BUS[i])

def set_data(data):
    for i in range(len(DATA_BUS)):
        b = (data >> i) & 1
        urc.set_dr_in(b, DATA_BUS[i], DATA_BUS[i])

def set_data_dir(d):
    for a in DATA_BUS_DIR:
        urc.set_dr_in(d, a, a)

def set_addr_dir(d):
    for a in ADDR_BUS_DIR:
        urc.set_dr_in(d, a, a)

def get_data():
    val = 0
    for i in range(8):
        b = urc.get_dr_out(DATA_BUS[i], DATA_BUS[i])
        val |= b << i
    return val

# set up control pins
urc.set_dr_in(OUTPUT, PIN_CE_BAK_DIR, PIN_CE_BAK_DIR)
urc.set_dr_in(OUTPUT, PIN_CE_MAIN_DIR, PIN_CE_MAIN_DIR)
urc.set_dr_in(1, PIN_CE_BAK, PIN_CE_BAK) #choose backup flash for now
urc.set_dr_in(0, PIN_CE_MAIN, PIN_CE_MAIN)

urc.set_dr_in(OUTPUT, PIN_OE_DIR, PIN_OE_DIR)
urc.set_dr_in(1, PIN_OE, PIN_OE)

urc.set_dr_in(OUTPUT, PIN_WE_DIR, PIN_WE_DIR)
urc.set_dr_in(1, PIN_WE, PIN_WE)

# setup data address bus
set_addr(0)
set_addr_dir(OUTPUT)
set_data(0)
set_data_dir(INPUT)

def flash_write(addr, val):
    set_data_dir(OUTPUT)
    urc.set_dr_in(1, PIN_WE, PIN_WE)
    urc.set_dr_in(1, PIN_OE, PIN_OE)
    set_addr(addr)
    set_data(val)

    # toggle WE
    urc.shift_dr()
    urc.set_dr_in(0, PIN_WE, PIN_WE)
    urc.shift_dr()
    urc.set_dr_in(1, PIN_WE, PIN_WE)

def flash_read(addr):
    set_data_dir(INPUT)
    urc.set_dr_in(1, PIN_WE, PIN_WE)
    urc.set_dr_in(0, PIN_OE, PIN_OE)
    set_addr(addr)
    urc.shift_dr()

    # read data
    urc.shift_dr()
    data = get_data()
    return data

def flash_reset():
    flash_write(0x5555, 0xf0)
    flash_write(0x5555, 0xaa)
    flash_write(0x2aaa, 0x55)
    flash_write(0x5555, 0xf0)

def flash_readid():
    # flash read id
    flash_write(0x5555, 0xaa)
    flash_write(0x2aaa, 0x55)
    flash_write(0x5555, 0x90)

    chipid = [0, 0]
    chipid[0] = flash_read(0)
    chipid[1] = flash_read(1)
    return chipid

def flash_erase_sector(sa):
    flash_write(0x5555, 0xaa)
    flash_write(0x2aaa, 0x55)
    flash_write(0x5555, 0x80)
    flash_write(0x5555, 0xaa)
    flash_write(0x2aaa, 0x55)
    flash_write(sa, 0x30)

    start = time.time()
    while True:
        c = flash_read(sa)
        if c == 0xff:
            break
        if time.time() - start > 10:
            raise Exception("Erase timeout. address: 0x%x status: 0x%02x" % (sa, c))

def flash_program(addr, data):
    flash_write(0x5555, 0xaa)
    flash_write(0x2aaa, 0x55)
    flash_write(0x5555, 0xa0)
    flash_write(addr, data)

    start = time.time()
    while True:
        c = flash_read(addr)
        if c == data:
            break
        if time.time() - start > 10:
            raise Exception("Program timeout. address: 0x%x status: 0x%02x" % (addr, c))

def main(args):
    flash_reset()
    chipid = flash_readid()
    flash_reset()
    print("Detected flash Manufacture ID: %02x Device ID: %02x" % (chipid[0], chipid[1]))
    flashinfo = flashchips[tuple(chipid)]
    print("Vendor: %s Name: %s" % (flashinfo["vendor"], flashinfo["name"]))
    print("Flash size: %d sector size: %d" % (flashinfo["size"], flashinfo["sector_size"]))
    flash_size = flashinfo["size"]
    sector_size = flashinfo["sector_size"]

    if args.r:
        f = open(args.f[0], 'wb')
        start = args.offset
        length = flash_size if args.length < 0 else args.length
        for i in range(start, start+length):
            f.write(bytes([flash_read(i)]))
            print("reading 0x%08x" % i)
        f.close()
        return 0
    elif args.w:
        f = open(args.f[0], 'rb')
        f.seek(0,2) # move the cursor to the end of the file
        fsize = f.tell()
        f.seek(0,0)

        start = args.offset
        length = fsize if args.length < 0 else args.length

        for i in range(start, start+length):
            b = ord(f.read(1))
            if i % sector_size == 0:
                print("Erasing sector 0x%x" % i)
                flash_reset()
                flash_erase_sector(i)
                flash_reset()
            print("writing 0x%08x" % i)
            flash_program(i, b)
        f.close()
        return 0
    else:
        print("unknow command")
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', nargs=1, required=True, help='output/input filename')
    parser.add_argument('-r', action='store_true', help='read flash')
    parser.add_argument('-w', action='store_true', help='write flash')
    parser.add_argument('--offset', type=int, default=0, help='start offset')
    parser.add_argument('--length', type=int, default=-1, help='read/len')
    parser.add_argument('--backup', action='store_true', default=False, help='select backup flash chip')
    args = parser.parse_args()

    exit(main(args))

