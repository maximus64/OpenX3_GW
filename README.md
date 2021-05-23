# X3 CE JTAG flash tool + custom gateware

I have a blown Xecuter 3 CE laying around and this is my attempt to repurpose it.

My X3 CE modchip has the LAD0 pin blown on the LPC bus making the chip unusable. This is the state of how I got it from the previous owner. Solder a JTAG adapter to the test points and the Lattice CLPD chip is still functional. I created a custom HDL code based on the OpenXenium project to re-route the LAD0 pin to a different pin on the chip. Note: this is quick and dirty PoC. Still need some work to make it usable. In its current state it able to boot Cromwell and Stock Bios :)

Team-Donkey reversed the Xecuter X3 and schematic is available at: https://github.com/bolwire/OpenX3_Public
This schematic is very close to the Xecuter 3 CE modchip but one major difference is the CPLD is LC4128V instead of LC4256V. Pinout seems to match my Xecuter 3 CE board.

## Flash Writer
Python script that uses the JTAG boundary scan mode to reprogram the parallel flash on the Xecuter 3

## Thanks
- @Ryzee119 - OpenXenium project
- @xbox7878 - reversing the X3 IO registers
