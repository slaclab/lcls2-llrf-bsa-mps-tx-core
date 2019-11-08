-------------------------------------------------------------------------------
-- File       : BsaMpsMsgTxFramer.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: TX Data Framer
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 LLRF Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 LLRF Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library lcls2_llrf_bsa_mps_tx_core; 

entity BsaMpsMsgTxFramer is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- BSA/MPS Interface (usrClk domain)
      usrClk       : in  sl;
      usrRst       : in  sl;
      timingStrobe : in  sl;
      timeStamp    : in  slv(63 downto 0);
      userValue    : in  slv(127 downto 0);
      bsaQuantity  : in  Slv32Array(11 downto 0);
      bsaSevr      : in  Slv2Array(11 downto 0);
      mpsPermit    : in  slv(3 downto 0);
      -- TX Data Interface (txClk domain)
      txClk        : in  sl;
      txRst        : in  sl;
      txData       : out slv(15 downto 0);
      txDataK      : out slv(1 downto 0));
end BsaMpsMsgTxFramer;

architecture rtl of BsaMpsMsgTxFramer is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant K28_5_C       : slv(7 downto 0)     := "10111100";  -- K28.5, 0xBC
   constant K28_1_C       : slv(7 downto 0)     := "00111100";  -- K28.1, 0x3C
   constant K28_2_C       : slv(7 downto 0)     := "01011100";  -- K28.2, 0x5C
   constant DLY_C         : positive            := 3;

   type StateType is (
      IDLE_S,
      DATA_S,
      CRC0_S,
      CRC1_S,
      CRC2_S,
      CRC3_S,
      CRC4_S);

   type RegType is record
      txData   : Slv16Array(DLY_C downto 0);
      txDataK  : Slv2Array(DLY_C downto 0);
      crcValid : sl;
      crcRst   : sl;
      crcData  : slv(15 downto 0);
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      txData   => (others => (K28_2_C & K28_1_C)),
      txDataK  => (others => "11"),
      crcValid => '0',
      crcRst   => '1',
      crcData  => (others => '0'),
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal crcResult   : slv(31 downto 0);
   signal sAxisMaster : AxiStreamMasterType;
   signal sAxisSlave  : AxiStreamSlaveType;

begin

   ---------------------
   -- Data Packer Module
   ---------------------
   U_Packer : entity lcls2_llrf_bsa_mps_tx_core.BsaMpsMsgTxPacker
      generic map (
         TPD_G => TPD_G)
      port map (
         -- BSA/MPS Interface
         usrClk       => usrClk,
         usrRst       => usrRst,
         timingStrobe => timingStrobe,
         timeStamp    => timeStamp,
         userValue    => userValue,
         bsaQuantity  => bsaQuantity,
         bsaSevr      => bsaSevr,
         mpsPermit    => mpsPermit,
         -- TX Data Interface
         txClk        => txClk,
         txRst        => txRst,
         mAxisMaster  => sAxisMaster,
         mAxisSlave   => sAxisSlave);

   comb : process (crcResult, r, sAxisMaster, txRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Shift Register
      v.txDataK(DLY_C downto 1) := r.txDataK(DLY_C-1 downto 0);
      v.txData(DLY_C downto 1)  := r.txData(DLY_C-1 downto 0);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Send IDLE pattern
            v.txDataK(0) := "11";
            v.txData(0)  := (K28_2_C & K28_1_C);
            -- Reset the CRC module
            v.crcValid   := '0';
            v.crcRst     := '1';
            -- Check for alignment
            if (sAxisMaster.tValid = '1') and (ssiGetUserSof(AXIS_CONFIG_C, sAxisMaster) = '1') then
               -- Send Start of Frame pattern
               v.txDataK(0)             := "01";
               v.txData(0)(7 downto 0)  := K28_5_C;
               v.txData(0)(15 downto 8) := sAxisMaster.tData(15 downto 8);
               -- Start the CRC engine
               v.crcValid               := '1';
               v.crcRst                 := '0';
               -- Next state
               v.state                  := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Move the data
            v.txDataK(0) := "00";
            v.txData(0)  := sAxisMaster.tData(15 downto 0);
            -- Check for end of frame
            if (sAxisMaster.tLast = '1') then
               -- Next state
               v.state := CRC0_S;
            end if;
         ----------------------------------------------------------------------
         when CRC0_S =>                 -- End of datagram @ v.txData(1)
            -- Send IDLE pattern
            v.txDataK(0) := "11";
            v.txData(0)  := (K28_2_C & K28_1_C);
            -- Stop sending data to CRC engine
            v.crcValid   := '0';
            -- Next state
            v.state      := CRC1_S;
         ----------------------------------------------------------------------
         when CRC1_S =>                 -- End of datagram @ v.txData(2)
            -- Send IDLE pattern
            v.txDataK(0) := "11";
            v.txData(0)  := (K28_2_C & K28_1_C);
            -- Next state
            v.state      := CRC2_S;
         ----------------------------------------------------------------------
         when CRC2_S =>                 -- End of datagram @ v.txData(3)
            -- Send IDLE pattern
            v.txDataK(0) := "11";
            v.txData(0)  := (K28_2_C & K28_1_C);
            -- Next state
            v.state      := CRC3_S;
         ----------------------------------------------------------------------
         when CRC3_S =>
            -- Send CRC (overwrite last element of shift register)
            v.txDataK(DLY_C) := "00";
            v.txData(DLY_C)  := crcResult(15 downto 0);
            -- Next state
            v.state          := CRC4_S;
         ----------------------------------------------------------------------
         when CRC4_S =>
            -- Send CRC (overwrite last element of shift register)
            v.txDataK(DLY_C) := "00";
            v.txData(DLY_C)  := crcResult(31 downto 16);
            -- Next state
            v.state          := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- Move the TX data to CRC
      v.crcData := v.txdata(0);

      -- Reset
      if (txRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;
      txdata     <= r.txdata(DLY_C);
      txDataK    <= r.txDataK(DLY_C);

   end process comb;

   seq : process (txClk) is
   begin
      if rising_edge(txClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   --------------------
   -- CRC Engine
   --------------------
   U_Crc32 : entity surf.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 2)
      port map (
         crcClk       => txClk,
         crcReset     => r.crcRst,
         crcDataWidth => "001",         -- 2 bytes 
         crcDataValid => r.crcValid,
         crcIn        => r.crcData,
         crcOut       => crcResult);

end rtl;
