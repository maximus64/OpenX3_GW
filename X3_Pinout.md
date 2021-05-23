# Xecuter 3 pinout

## LPC BUS

- LAD0 - 34 - B3 ( Blown on my board move to pin 21 - B9)
- LAD2 - 36 - B1
- LAD1 - 35 - B2
- LCLK - 38 - CLK1
- LAD3 - 37 - B0

- D0 Mosfet (low - pull GND) - 22 - B8


## Power SW

- Font panel power - 39 - CLK2
- Font panel eject - 41 - C0


## Flash pinout

- CE Big - 17 - B12
- CE Bak - 19 - B11
- OE - 15 - B14
- WE - 16 - B13

- A0 - 14 - B15
- A1 - 11 - A15
- A2 - 10 - A14
- A3 -  9 - A13
- A4 -  8 - A12
- A5 -  6 - A11
- A6 -  5 - A10
- A7 -  4 - A9
- A8 -  3 - A8
- A9 - 100 - A7
- A10 - 99 - A6
- A11 - 98 - A5
- A12 - 97 - A4
- A13 - 94 - A3
- A14 - 93 - A2
- A15 - 92 - A1
- A16 - 91 - A0
- A17 - 87 - D0
- A18 - 86 - D1 (only big flash)
- A19 - 85 - D2 (only big flash)
- A20 - 84 - D3 (only big flash)

- DQ0 - 78 - D7
- DQ1 - 72 - D8
- DQ2 - 71 - D9
- DQ3 - 61 - C15
- DQ4 - 60 - C14
- DQ5 - 59 - C13
- DQ6 - 50 - C7
- DQ7 - 49 - C6

## LCD pinout:
- D0 - 70 - IOG5
- D1 - 69 - IOG6
- D2 - 67 - IOG8
- D3 - 66 - IOG10
- D4 - 58 - IOF8
- D5 - 53 - IOF0
- D6 - 48 - IOE10
- D7 - 47 - IOE8
- RS - 44 - C3
- RW - 65 - D14
- E  - 64 - D15
- K  - 20 - B10

## Front panel pinout:
- Write Protect - 12 - I_2
- Bank 1 - 23 - I_3
- Bank 2 - 27 - I_4
- Bank 3 - 28 - B7
- Bank 4 - 29 - B6
- Logo Red - 30 - B5 (active low, X3 CE: pin 31)
- Logo Blue - 31 - B4 (active low, X3 CE: pin 30)


## X3 Bank switch setting

NOTE: 0 is ON position in X3 front panel. Without front panel connect it will pull up to 4b'1111 (2MB bank)

256k:
- bank 1 - 0 0 0 0
- bank 2 - 1 0 0 0
- bank 3 - 0 1 0 0
- bank 4 - 1 1 0 0
- bank 5 - 0 0 1 0
- bank 6 - 1 0 1 0
- bank 7 - 0 1 1 0
- bank 8 - 1 1 1 0

512k:
- bank 12 - 0 0 0 1
- bank 34 - 1 0 0 1
- bank 56 - 0 1 0 1
- bank 78 - 1 1 0 1

1MB:
- bank 1234 - 0 0 1 1
- bank 5678 - 1 0 1 1

2MB:
- bank 12345678 - 1 1 1 1
