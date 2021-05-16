-- Design Name: openxenium
-- Module Name: openxenium - Behavioral
-- Project Name: OpenXenium. Open Source Xenius modchip CPLD replacement project
-- Target Devices: XC9572XL-10VQ64
--
-- Revision 0.01 - File Created - Ryan Wendland
--
-- Additional Comments:
--
-- OpenXenium is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see .
--
----------------------------------------------------------------------------------
--
--
--**BANK SELECTION**
--Bank selection is controlled by the lower nibble of address REG_00EF.
--A20,A19,A18 are address lines to the parallel flash memory.
--lines marked X means it is not forced by the CPLD for banking purposes.
--This is how is works:
--
--REGISTER 0xEF Bank Commands:
--BANK NAME                  DATA BYTE    A20|A19|A18 ADDRESS OFFSET
--TSOP                       XXXX 0000     X |X |X    N/A.     (This locks up the Xenium to force it to boot from TSOP.)
--XeniumOS(c.well loader)    XXXX 0001     1 |1 |0    0x180000 (This is the default boot state. Contains Cromwell bootloader)
--XeniumOS                   XXXX 0010     1 |0 |X    0x100000 (This is a 512kb bank and contains XeniumOS)
--BANK1 (USER BIOS 256kB)    XXXX 0011     0 |0 |0    0x000000
--BANK2 (USER BIOS 256kB)    XXXX 0100     0 |0 |1    0x040000
--BANK3 (USER BIOS 256kB)    XXXX 0101     0 |1 |0    0x080000
--BANK4 (USER BIOS 256kB)    XXXX 0110     0 |1 |1    0x0C0000
--BANK1 (USER BIOS 512kB)    XXXX 0111     0 |0 |X    0x000000
--BANK2 (USER BIOS 512kB)    XXXX 1000     0 |1 |X    0x080000
--BANK1 (USER BIOS 1MB)      XXXX 1001     0 |X |X    0x000000
--RECOVERY (NOTE 1)          XXXX 1010     1 |1 |1    0x1C0000 
-- 
--
--NOTE 1: The RECOVERY bank can also be actived by the physical switch on the Xenium. This forces bank ten (0b1010) on power up.
--This bank also contains non-volatile storage of settings an EEPROM backup in the smaller sectors at the end of the flash memory.
--The memory map is shown below:
--     (1C0000 to 1DFFFF PROTECTED AREA 128kbyte recovery bios)
--     (1E0000 to 1FBFFF Additional XeniumOS Data)
--     (1FC000 to 1FFFFF Contains eeprom backup, XeniumOS settings)
--
--
--**XENIUM CONTROL WRITE/READ REGISTERS**
--Bits marked 'X' either have no function or an unknown function.
--**0xEF WRITE:**
--X,SCK,CS,MOSI,BANK[3:0]
--
--**0xEF READ:**
--RECOV SWITCH POSITION (0=ACTIVE),X,MISO(Pin 1),MISO (Pin 4),BANK[3:0] 
--
--**0xEE (WRITE)**
--X,X,X,X X,B,G,R (DEFAULT LED ON POWER UP IS RED)
--
--**0xEE (READ)**
--Just returns 0x55 on a real xenium?
--


-- LPC BUS
-- LAD0 - PIN 34 - B3 - Blown (let move to PIN 21 - B9)
-- LAD2 - PIN 36 - B1 - OK
-- LAD1 - PIN 35 - B2 - OK
-- LCLK - PIN 38 - CLK1 - OK
-- LAD3 - PIN 37 - B0 - OK


-- D0 Mosfet (High pull low) - 22 - B8
-- Write Protection SW - 12 - I_2
-- Font panel power - 41 - C0
-- Font panel eject - 39 - CLK2


-- Flash pinout:

-- CE Big - 17 - B12
-- CE Bak - 19 - B11
-- OE - 15 - B14
-- WE - 16 - B13

-- A0 - 14 - B15
-- A1 - 11 - A15
-- A2 - 10 - A14
-- A3 -  9 - A13
-- A4 -  8 - A12
-- A5 -  6 - A11
-- A6 -  5 - A10
-- A7 -  4 - A9
-- A8 -  3 - A8
-- A9 - 100 - A7
-- A10 - 99 - A6
-- A11 - 98 - A5
-- A12 - 97 - A4
-- A13 - 94 - A3
-- A14 - 93 - A2
-- A15 - 92 - A1
-- A16 - 91 - A0
-- A17 - 87 - D0
-- A18 - 86 - D1 (only big flash)
-- A19 - 85 - D2 (only big flash)
-- A20 - 84 - D3 (only big flash)

-- DQ0 - 78 - D7
-- DQ1 - 72 - D8
-- DQ2 - 71 - D9
-- DQ3 - 61 - C15
-- DQ4 - 60 - C14
-- DQ5 - 59 - C13
-- DQ6 - 50 - C7
-- DQ7 - 49 - C6

-- LCD:
-- D0 - 70 - IOG5
-- D1 - 69 - IOG6
-- D2 - 67 - IOG8
-- D3 - 66 - IOG10
-- D4 - 58 - IOF8
-- D5 - 53 - IOF0
-- D6 - 48 - IOE10
-- D7 - 47 - IOE8

 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
ENTITY openxenium IS
   PORT (
      FLASH_CE_MAIN : OUT STD_LOGIC;
      FLASH_CE_BAK : OUT STD_LOGIC;
      FLASH_WE : OUT STD_LOGIC;
      FLASH_OE : OUT STD_LOGIC;
      FLASH_ADDRESS : OUT STD_LOGIC_VECTOR (20 DOWNTO 0);
      FLASH_DQ : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);

      LPC_LAD : INOUT STD_LOGIC_VECTOR (3 DOWNTO 0);
      LPC_CLK : IN STD_LOGIC;
      -- LPC_RST : IN STD_LOGIC; X3 doesn't have this signal

      XENIUM_D0 : OUT STD_LOGIC;

      -- X3 parallel bus LCD
      LCD_DAT : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
   );

END openxenium;

ARCHITECTURE Behavioral OF openxenium IS

   TYPE LPC_STATE_MACHINE IS (
   WAIT_START, 
   CYCTYPE_DIR, 
   ADDRESS, 
   WRITE_DATA0, 
   WRITE_DATA1, 
   READ_DATA0, 
   READ_DATA1, 
   TAR1, 
   TAR2, 
   SYNCING, 
   SYNC_COMPLETE, 
   TAR_EXIT
   );
 
   TYPE CYC_TYPE IS (
   IO_READ, --Default state
   IO_WRITE, 
   MEM_READ, 
   MEM_WRITE
   );

   -- X3 doesn't have this signal. Active low
   CONSTANT LPC_RST : STD_LOGIC := '1';
   CONSTANT XENIUM_RECOVERY : STD_LOGIC := '0';
   CONSTANT HEADER_4 : STD_LOGIC := '0';
   CONSTANT HEADER_1 : STD_LOGIC := '0';

   SIGNAL LPC_CURRENT_STATE : LPC_STATE_MACHINE := WAIT_START;
   SIGNAL CYCLE_TYPE : CYC_TYPE := IO_READ;

   SIGNAL LPC_ADDRESS : STD_LOGIC_VECTOR (20 DOWNTO 0); --LPC Address is actually 32bits for memory IO, but we only need 20.

   --XENIUM IO REGISTERS. BITS MARKED 'X' HAVE AN UNKNOWN FUNCTION OR ARE UNUSED. NEEDS MORE RE.
   --Bit masks are all shown upper nibble first.
 
   --IO WRITE/READ REGISTERS SIGNALS
   CONSTANT XENIUM_00EE : STD_LOGIC_VECTOR (7 DOWNTO 0) := x"EE"; --CONSTANT (RGB LED Control Register)
   CONSTANT XENIUM_00EF : STD_LOGIC_VECTOR (7 DOWNTO 0) := x"EF"; --CONSTANT (SPI and Banking Control Register)
   SIGNAL REG_00EE_WRITE : STD_LOGIC_VECTOR (7 DOWNTO 0) := "00000001"; --X,X,X,X X,B,G,R. Red is default LED colour
   SIGNAL REG_00EF_WRITE : STD_LOGIC_VECTOR (7 DOWNTO 0) := "00000001"; --X,SCK,CS,MOSI, BANKCONTROL[3:0]. Bank 1 is default.
   SIGNAL REG_00EF_READ : STD_LOGIC_VECTOR (7 DOWNTO 0) := "01010101"; --Input signal
   SIGNAL REG_00EE_READ : STD_LOGIC_VECTOR (7 DOWNTO 0) := "01010101"; --Input signal
   SIGNAL READBUFFER : STD_LOGIC_VECTOR (7 DOWNTO 0); --I buffer Memory and IO reads to reduce pin to pin delay in CPLD which caused issues
 
   SIGNAL COUNTER : STD_LOGIC_VECTOR (11 DOWNTO 0);

   --R/W SIGNAL FOR FLASH MEMORY
   SIGNAL sFLASH_DQ : STD_LOGIC_VECTOR (7 DOWNTO 0) := "ZZZZZZZZ";
 
   --TSOPBOOT IS SET TO '1' WHEN YOU REQUEST TO BOOT FROM TSOP. THIS PREVENTS THE CPLD FROM DRIVING D0.
   --D0LEVEL is inverted and connected to the D0 output pad. This allows the CPLD to latch/release the D0/LFRAME signal.
   SIGNAL TSOPBOOT : STD_LOGIC := '0';
   SIGNAL D0LEVEL : STD_LOGIC := '0';
 
   --GENERIC COUNTER USED TO TRACK ADDRESS AND SYNC COUNTERS.
   SIGNAL COUNT : INTEGER RANGE 0 TO 7;

BEGIN
   --ASSIGN THE IO TO SIGNALS BASED ON REQUIRED BEHAVIOUR
   --TODO: maximus force boot main flash for now
   FLASH_CE_MAIN <= '0';
   FLASH_CE_BAK <= '1';

   FLASH_ADDRESS <= LPC_ADDRESS;

   --LAD lines can be either input or output
   --The output values depend on variable states of the LPC transaction
   --Refer to the Intel LPC Specification Rev 1.1
   LPC_LAD <= "0000" WHEN LPC_CURRENT_STATE = SYNC_COMPLETE ELSE
              "0101" WHEN LPC_CURRENT_STATE = SYNCING ELSE
              "1111" WHEN LPC_CURRENT_STATE = TAR2 ELSE
              "1111" WHEN LPC_CURRENT_STATE = TAR_EXIT ELSE
              READBUFFER(3 DOWNTO 0) WHEN LPC_CURRENT_STATE = READ_DATA0 ELSE --This has to be lower nibble first!
              READBUFFER(7 DOWNTO 4) WHEN LPC_CURRENT_STATE = READ_DATA1 ELSE 
              "ZZZZ";

   --FLASH_DQ is mapped to the data byte sent by the Xbox in MEM_WRITE mode, else its just an input
   FLASH_DQ <= sFLASH_DQ WHEN CYCLE_TYPE = MEM_WRITE ELSE "ZZZZZZZZ";
   
   --Write Enable for Flash Memory Write (Active low)
   --Minimum pulse width 90ns.
   --Address is latched on the falling edge of WE.
   --Data is latched on the rising edge of WE.
   FLASH_WE <= '0' WHEN CYCLE_TYPE = MEM_WRITE AND
               (LPC_CURRENT_STATE = TAR1 OR
               LPC_CURRENT_STATE = TAR2 OR
               LPC_CURRENT_STATE = SYNCING) ELSE '1';

   --Output Enable for Flash Memory Read (Active low)
   --Output Enable must be pulled low for 50ns before data is valid for reading
   FLASH_OE <= '0' WHEN CYCLE_TYPE = MEM_READ AND
               (LPC_CURRENT_STATE = TAR1 OR
               LPC_CURRENT_STATE = TAR2 OR
               LPC_CURRENT_STATE = SYNCING OR
               LPC_CURRENT_STATE = SYNC_COMPLETE OR
               LPC_CURRENT_STATE = READ_DATA0 OR
               LPC_CURRENT_STATE = READ_DATA1 OR
               LPC_CURRENT_STATE = TAR_EXIT) ELSE '1';

   --D0 has the following behaviour
   --Held low on boot to ensure it boots from the LPC then released when definitely booting from modchip.
   --When soldered to LFRAME it will simulate LPC transaction aborts for 1.6.
   --Released for TSOP booting.
   --NOTE: XENIUM_D0 is an output to a mosfet driver. '0' turns off the MOSFET releasing D0
   --and a value of '1' turns on the MOSFET forcing it to ground. This is why I invert D0LEVEL before mapping it.
--    XENIUM_D0 <= '0' WHEN TSOPBOOT = '1' ELSE
--                 '1' WHEN CYCLE_TYPE = MEM_READ ELSE
--                 '1' WHEN CYCLE_TYPE = MEM_WRITE ELSE
--                 NOT D0LEVEL; 
   -- TODO: fix me Force D0 low for now
   XENIUM_D0 <= '0';
 
   REG_00EF_READ <= XENIUM_RECOVERY & '0' & HEADER_4 & HEADER_1 & REG_00EF_WRITE(3 DOWNTO 0);

   -- Heart beat
   LCD_DAT(7) <= COUNTER(11);
   LCD_DAT(3 DOWNTO 0) <= "0000" WHEN LPC_CURRENT_STATE = WAIT_START ELSE
                          "0001" WHEN LPC_CURRENT_STATE = CYCTYPE_DIR ELSE
                          "0010" WHEN LPC_CURRENT_STATE = ADDRESS ELSE
                          "0011" WHEN LPC_CURRENT_STATE = WRITE_DATA0 ELSE
                          "0100" WHEN LPC_CURRENT_STATE = WRITE_DATA1 ELSE
                          "0101" WHEN LPC_CURRENT_STATE = READ_DATA0 ELSE
                          "0110" WHEN LPC_CURRENT_STATE = READ_DATA1 ELSE
                          "0111" WHEN LPC_CURRENT_STATE = ADDRESS ELSE
                          "1000" WHEN LPC_CURRENT_STATE = TAR1 ELSE
                          "1001" WHEN LPC_CURRENT_STATE = TAR2 ELSE
                          "1010" WHEN LPC_CURRENT_STATE = SYNCING ELSE
                          "1011" WHEN LPC_CURRENT_STATE = SYNC_COMPLETE ELSE
                          "1100" WHEN LPC_CURRENT_STATE = TAR_EXIT ELSE
                          "1111";
   LCD_DAT(6 DOWNTO 4) <= LPC_LAD(2 DOWNTO 0);

--PROCESS (LPC_CLK, LPC_RST) BEGIN
PROCESS (LPC_CLK) BEGIN

   IF (rising_edge(LPC_CLK)) THEN 

      -- Heart beat counter
      COUNTER <= COUNTER + 1;

      CASE LPC_CURRENT_STATE IS
         WHEN WAIT_START => 
            IF LPC_LAD = "0000" THEN-- //TODO: alway boot to modchip AND TSOPBOOT = '0' THEN
               LPC_CURRENT_STATE <= CYCTYPE_DIR;
            END IF;
         WHEN CYCTYPE_DIR => 
            IF LPC_LAD(3 DOWNTO 1) = "000" THEN
               CYCLE_TYPE <= IO_READ;
               COUNT <= 3;
               LPC_CURRENT_STATE <= ADDRESS; 
            ELSIF LPC_LAD(3 DOWNTO 1) = "001" THEN
               CYCLE_TYPE <= IO_WRITE;
               COUNT <= 3;
               LPC_CURRENT_STATE <= ADDRESS;
            ELSIF LPC_LAD(3 DOWNTO 1) = "010" THEN
               CYCLE_TYPE <= MEM_READ;
               COUNT <= 7;
               LPC_CURRENT_STATE <= ADDRESS;
            ELSIF LPC_LAD(3 DOWNTO 1) = "011" THEN
               CYCLE_TYPE <= MEM_WRITE;
               COUNT <= 7;
               LPC_CURRENT_STATE <= ADDRESS;
            ELSE
               LPC_CURRENT_STATE <= WAIT_START; -- Unsupported, reset state machine.
            END IF;
 
         --ADDRESS GATHERING
         WHEN ADDRESS => 
            IF COUNT = 5 THEN
               LPC_ADDRESS(20) <= LPC_LAD(0);
            ELSIF COUNT = 4 THEN
               LPC_ADDRESS(19 DOWNTO 16) <= LPC_LAD;
               --Maximus: force 1MB bank
               --LPC_ADDRESS(20) <= '0'; --1mb bank
               LPC_ADDRESS(20 DOWNTO 18) <= "000"; --256kb bank
            ELSIF COUNT = 3 THEN
               LPC_ADDRESS(15 DOWNTO 12) <= LPC_LAD; 
            ELSIF COUNT = 2 THEN
               LPC_ADDRESS(11 DOWNTO 8) <= LPC_LAD;
            ELSIF COUNT = 1 THEN
               LPC_ADDRESS(7 DOWNTO 4) <= LPC_LAD;
            ELSIF COUNT = 0 THEN
               LPC_ADDRESS(3 DOWNTO 0) <= LPC_LAD;
               IF CYCLE_TYPE = IO_READ OR CYCLE_TYPE = MEM_READ THEN
                  LPC_CURRENT_STATE <= TAR1;
               ELSIF CYCLE_TYPE = IO_WRITE OR CYCLE_TYPE = MEM_WRITE THEN
                  LPC_CURRENT_STATE <= WRITE_DATA0;
               END IF;
            END IF;
            COUNT <= COUNT - 1; 
 
         --MEMORY OR IO WRITES. These all happen lower nibble first. (Refer to Intel LPC spec)
         WHEN WRITE_DATA0 => 
            IF CYCLE_TYPE = IO_WRITE AND LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EE THEN
               REG_00EE_WRITE(3 DOWNTO 0) <= LPC_LAD;
            ELSIF CYCLE_TYPE = IO_WRITE AND LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EF THEN
               REG_00EF_WRITE(3 DOWNTO 0) <= LPC_LAD;
            ELSIF CYCLE_TYPE = MEM_WRITE THEN
               sFLASH_DQ(3 DOWNTO 0) <= LPC_LAD;
            END IF;
            LPC_CURRENT_STATE <= WRITE_DATA1;
         WHEN WRITE_DATA1 => 
            IF CYCLE_TYPE = IO_WRITE AND LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EE THEN
               REG_00EE_WRITE(7 DOWNTO 4) <= LPC_LAD;
            ELSIF CYCLE_TYPE = IO_WRITE AND LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EF THEN
               REG_00EF_WRITE(7 DOWNTO 4) <= LPC_LAD;
            ELSIF CYCLE_TYPE = MEM_WRITE THEN
               sFLASH_DQ(7 DOWNTO 4) <= LPC_LAD;
            END IF;
            LPC_CURRENT_STATE <= TAR1;

         --MEMORY OR IO READS
         WHEN READ_DATA0 => 
            LPC_CURRENT_STATE <= READ_DATA1;
         WHEN READ_DATA1 => 
            LPC_CURRENT_STATE <= TAR_EXIT; 
 

         --TURN BUS AROUND (HOST TO PERIPHERAL)
         WHEN TAR1 => 
            LPC_CURRENT_STATE <= TAR2;
         WHEN TAR2 => 
            LPC_CURRENT_STATE <= SYNCING;
            COUNT <= 6;
            
         --SYNCING STAGE
         WHEN SYNCING =>
            COUNT <= COUNT - 1;    
            --Buffer IO reads during syncing. Helps output timings
            IF COUNT = 1 THEN
               IF CYCLE_TYPE = MEM_READ THEN
                  READBUFFER <= FLASH_DQ;
               ELSIF CYCLE_TYPE = IO_READ THEN
                  IF LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EF THEN
                     READBUFFER <= REG_00EF_READ;
                  ELSIF LPC_ADDRESS(7 DOWNTO 0) = XENIUM_00EE THEN
                     READBUFFER <= REG_00EE_READ;
                  ELSE
                     READBUFFER <= "11111111";
                  END IF;
               END IF;
           ELSIF COUNT = 0 THEN
              LPC_CURRENT_STATE <= SYNC_COMPLETE;
           END IF;
         WHEN SYNC_COMPLETE => 
            IF CYCLE_TYPE = MEM_READ OR CYCLE_TYPE = IO_READ THEN
               LPC_CURRENT_STATE <= READ_DATA0;
            ELSE
               LPC_CURRENT_STATE <= TAR_EXIT;
            END IF;
 
         --TURN BUS AROUND (PERIPHERAL TO HOST)
         WHEN TAR_EXIT => 
            --D0 is held low until a few memory reads
            --This ensures it is booting from the modchip. Genuine Xenium arbitrarily
            --releases after the 5th read. This is always address 0x74
            IF LPC_ADDRESS(7 DOWNTO 0) = x"74" THEN
               D0LEVEL <= '1';
            END IF;
            CYCLE_TYPE <= IO_READ;
            LPC_CURRENT_STATE <= WAIT_START;
      END CASE;
   END IF;
END PROCESS;
END Behavioral;
