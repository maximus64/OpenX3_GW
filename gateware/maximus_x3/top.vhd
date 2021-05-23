-- Design Name: openx3
-- Module Name: openx3 - Behavioral
-- Project Name: OpenX3. Open Source Xecuter 3 modchip CPLD replacement project
-- Target Devices: LC4128V-75T100C / LC4256V-75T100C
--
-- Customize for Xecuter 3 by @maximus64 (Khoa Hoang)
--
-- Based on OpenXenium project by Ryan Wendland
-- (https://github.com/Ryzee119/OpenXenium/blob/master/Firmware/openxenium.vhd)
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
 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
ENTITY openx3 IS
   PORT (
      FLASH_CE_MAIN : OUT STD_LOGIC;
      FLASH_CE_BAK : OUT STD_LOGIC;
      FLASH_WE : OUT STD_LOGIC;
      FLASH_OE : OUT STD_LOGIC;
      FLASH_ADDRESS : OUT STD_LOGIC_VECTOR (20 DOWNTO 0);
      FLASH_DQ : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);

      LPC_LAD : INOUT STD_LOGIC_VECTOR (3 DOWNTO 0);
      LPC_CLK : IN STD_LOGIC;

      TSOP_D0 : OUT STD_LOGIC;

      -- X3 parallel bus LCD
      LCD_DAT : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
      LCD_RS : OUT STD_LOGIC;
      LCD_RW : OUT STD_LOGIC;
      LCD_E : OUT STD_LOGIC;
      LCD_K : OUT STD_LOGIC;

      -- Power / Eject button to sel boot mode
      PWR_BTN : IN STD_LOGIC;
      EJECT_BTN : IN STD_LOGIC;

      -- X3 front panel
      FP_BANK_DIP : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
      FP_WRITE_PROTECT : IN STD_LOGIC;
      FP_LOGO_BLUE : OUT STD_LOGIC;
      FP_LOGO_RED : OUT STD_LOGIC
   );

END openx3;

ARCHITECTURE Behavioral OF openx3 IS

   TYPE LPC_STATE_MACHINE IS (
   INIT_CHIP,
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

   CONSTANT XENIUM_RECOVERY : STD_LOGIC := '0';
   CONSTANT HEADER_4 : STD_LOGIC := '0';
   CONSTANT HEADER_1 : STD_LOGIC := '0';

   SIGNAL LPC_CURRENT_STATE : LPC_STATE_MACHINE := INIT_CHIP;
   SIGNAL CYCLE_TYPE : CYC_TYPE := IO_READ;

   SIGNAL LPC_ADDRESS : STD_LOGIC_VECTOR (20 DOWNTO 0); --LPC Address is actually 32bits for memory IO, but we only need 20.

   --XENIUM IO REGISTERS. BITS MARKED 'X' HAVE AN UNKNOWN FUNCTION OR ARE UNUSED. NEEDS MORE RE.
   --Bit masks are all shown upper nibble first.
 
   --IO WRITE/READ REGISTERS SIGNALS
   CONSTANT X3_VERSION_F500 : STD_LOGIC_VECTOR (15 DOWNTO 0) := x"F500"; --CONSTANT (Xecuter 3 Version Register: 0xF500)
   -- (Read only)
   -- Must return 0xe1 otherwise X3 bios will refuse to boot
   CONSTANT X3_CONTROL_F501 : STD_LOGIC_VECTOR (15 DOWNTO 0) := x"F501"; --CONSTANT (Xecuter 3 Control Register: 0xF501)
   -- Bits: (R/W)
   -- 0-3 - DIP switch bank selection (read only)
   -- 4 - unknow (unused?)
   -- 5 - unknow (set when chip disable - one is probably LPC FSM reset while the other control D0)
   -- 6 - unknow (set when chip disable - note ^)
   -- 7 - backup flash select (set when flashing backup bios)
   CONSTANT X3_SW_BANK_F502 : STD_LOGIC_VECTOR (15 DOWNTO 0) := x"F502"; --CONSTANT (Xecuter 3 Status Register: 0xF502)
   -- Bits: (R/W)
   -- 0-3 - Software bank selection
   -- 7 - Sofware bank select if set, otherwise dip switch bank sel

   SIGNAL BANK_SEL : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0000";
   SIGNAL SW_BANK : STD_LOGIC := '0';
   SIGNAL RECOVERY_BOOT : STD_LOGIC := '0';
   SIGNAL WRITE_PROTECT : STD_LOGIC := '0';

   SIGNAL READBUFFER : STD_LOGIC_VECTOR (7 DOWNTO 0); --I buffer Memory and IO reads to reduce pin to pin delay in CPLD which caused issues
 
   --R/W SIGNAL FOR FLASH MEMORY
   SIGNAL sFLASH_DQ : STD_LOGIC_VECTOR (7 DOWNTO 0) := "ZZZZZZZZ";
 
   --TSOPBOOT IS SET TO '1' WHEN YOU REQUEST TO BOOT FROM TSOP. THIS PREVENTS THE CPLD FROM DRIVING D0.
   --D0LEVEL connected to the D0 output pad. This allows the CPLD to latch/release the D0/LFRAME signal.
   SIGNAL TSOPBOOT : STD_LOGIC := '0';
   SIGNAL D0LEVEL : STD_LOGIC := '0';
 
   --GENERIC COUNTER USED TO TRACK ADDRESS AND SYNC COUNTERS.
   SIGNAL COUNT : INTEGER RANGE 0 TO 7;
   SIGNAL TEST_REG : STD_LOGIC_VECTOR (7 DOWNTO 0) := "00000000";
BEGIN
   --ASSIGN THE IO TO SIGNALS BASED ON REQUIRED BEHAVIOUR
   -- Flash CE is active low
   FLASH_CE_MAIN <= '0' WHEN RECOVERY_BOOT = '0' ELSE '1';
   FLASH_CE_BAK <= '0' WHEN RECOVERY_BOOT = '1' ELSE '1';

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
   --NOTE: TSOP_D0 is an output to a mosfet driver. '1' turns off the MOSFET releasing D0
   --and a value of '0' turns on the MOSFET forcing it to ground.
   TSOP_D0 <= '1' WHEN TSOPBOOT = '1' ELSE
                '0' WHEN CYCLE_TYPE = MEM_READ ELSE
                '0' WHEN CYCLE_TYPE = MEM_WRITE ELSE
                D0LEVEL;

-- DEBUG signal
--   LCD_DAT(3 DOWNTO 0) <= BANK_SEL;
--   LCD_DAT(4) <= RECOVERY_BOOT;
--   LCD_DAT(5) <= WRITE_PROTECT;
--   LCD_DAT(6) <= TSOPBOOT;
--   LCD_DAT(7) <= D0LEVEL;
   LCD_DAT <= TEST_REG;

   -- X3 front panel LED (Note: active low)
   FP_LOGO_BLUE <= '0' WHEN TSOPBOOT = '0' OR RECOVERY_BOOT = '1' ELSE '1';
   FP_LOGO_RED <= '0' WHEN TSOPBOOT = '1' OR RECOVERY_BOOT = '1' ELSE '1';

PROCESS (LPC_CLK) BEGIN

   IF (rising_edge(LPC_CLK)) THEN 

      CASE LPC_CURRENT_STATE IS
         WHEN INIT_CHIP =>
            LPC_CURRENT_STATE <= WAIT_START;
            BANK_SEL <= FP_BANK_DIP;
            IF PWR_BTN = '0' AND EJECT_BTN = '0' THEN
               -- Both power and eject held boot recovery
               RECOVERY_BOOT <= '1';
               TSOPBOOT <= '0';
            ELSIF PWR_BTN = '0' AND EJECT_BTN = '1' THEN
               -- Power button held: boot TSOP
               RECOVERY_BOOT <= '0';
               TSOPBOOT <= '1';
            ELSE
               RECOVERY_BOOT <= '0';
               TSOPBOOT <= '0';
            END IF;
         WHEN WAIT_START => 
            IF LPC_LAD = "0000" AND TSOPBOOT = '0' THEN
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
               --BANK CONTROL
               CASE BANK_SEL IS
                  -- 256KB banks
                  WHEN "0000" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "000"; --256kb bank 1
                  WHEN "0001" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "001"; --256kb bank 2
                  WHEN "0010" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "010"; --256kb bank 3
                  WHEN "0011" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "011"; --256kb bank 4
                  WHEN "0100" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "100"; --256kb bank 5
                  WHEN "0101" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "101"; --256kb bank 6
                  WHEN "0110" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "110"; --256kb bank 7
                  WHEN "0111" =>
                      LPC_ADDRESS(20 DOWNTO 18) <= "111"; --256kb bank 8
                  -- 512KB banks
                  WHEN "1000" =>
                      LPC_ADDRESS(20 DOWNTO 19) <= "00"; --512kb bank 12
                  WHEN "1001" =>
                      LPC_ADDRESS(20 DOWNTO 19) <= "01"; --512kb bank 34
                  WHEN "1010" =>
                      LPC_ADDRESS(20 DOWNTO 19) <= "10"; --512kb bank 56
                  WHEN "1011" =>
                      LPC_ADDRESS(20 DOWNTO 19) <= "11"; --512kb bank 78
                  -- 1MB banks
                  WHEN "1100" =>
                      LPC_ADDRESS(20) <= '0'; --1MB bank 1234
                  WHEN "1101" =>
                      LPC_ADDRESS(20) <= '1'; --1MB bank 5678
                  -- Default bank or when x3 front panel disconnect
                  WHEN "1111" =>
                      LPC_ADDRESS(20) <= '0'; --1MB bank 1234
                  -- Other - Full flash access
                  WHEN OTHERS =>
               END CASE;
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
            IF CYCLE_TYPE = IO_WRITE THEN
                IF LPC_ADDRESS(15 DOWNTO 0) = X3_SW_BANK_F502 THEN
                    BANK_SEL <= LPC_LAD;
                ELSIF LPC_ADDRESS(15 DOWNTO 0) = X3_CONTROL_F501 THEN
                    TEST_REG(3 DOWNTO 0) <= LPC_LAD;
                END IF;
            ELSIF CYCLE_TYPE = MEM_WRITE THEN
               sFLASH_DQ(3 DOWNTO 0) <= LPC_LAD;
            END IF;
            LPC_CURRENT_STATE <= WRITE_DATA1;
         WHEN WRITE_DATA1 => 
            IF CYCLE_TYPE = IO_WRITE THEN
                IF LPC_ADDRESS(15 DOWNTO 0) = X3_SW_BANK_F502 THEN
                    SW_BANK <= LPC_LAD(3);
                ELSIF LPC_ADDRESS(15 DOWNTO 0) = X3_CONTROL_F501 THEN
                    TEST_REG(7 DOWNTO 4) <= LPC_LAD;
                END IF;
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
                  IF LPC_ADDRESS(15 DOWNTO 0) = X3_VERSION_F500 THEN
                      READBUFFER <= x"E1";
                  ELSIF LPC_ADDRESS(15 DOWNTO 0) = X3_CONTROL_F501 THEN
                      READBUFFER(7 DOWNTO 4) <= "0000";
                      READBUFFER(3 DOWNTO 0) <= FP_BANK_DIP;
                  ELSIF LPC_ADDRESS(15 DOWNTO 0) = X3_SW_BANK_F502 THEN
                      READBUFFER <= SW_BANK & "000" & BANK_SEL;
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
            CYCLE_TYPE <= IO_READ;
            LPC_CURRENT_STATE <= WAIT_START;
      END CASE;
   END IF;
END PROCESS;
END Behavioral;
