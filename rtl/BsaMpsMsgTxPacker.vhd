-------------------------------------------------------------------------------
-- File       : BsaMpsMsgTxPacker.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: TX Data Packer
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity BsaMpsMsgTxPacker is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- BSA/MPS Interface
      usrClk        : in  sl;
      usrRst        : in  sl;
      timingStrobe  : in  sl;
      timeStamp     : in  slv(63 downto 0);
      bsaQuantity0  : in  slv(31 downto 0);
      bsaQuantity1  : in  slv(31 downto 0);
      bsaQuantity2  : in  slv(31 downto 0);
      bsaQuantity3  : in  slv(31 downto 0);
      bsaQuantity4  : in  slv(31 downto 0);
      bsaQuantity5  : in  slv(31 downto 0);
      bsaQuantity6  : in  slv(31 downto 0);
      bsaQuantity7  : in  slv(31 downto 0);
      bsaQuantity8  : in  slv(31 downto 0);
      bsaQuantity9  : in  slv(31 downto 0);
      bsaQuantity10 : in  slv(31 downto 0);
      bsaQuantity11 : in  slv(31 downto 0);
      mpsPermit     : in  slv(3 downto 0);
      -- TX Data Interface
      txClk         : in  sl;
      txRst         : in  sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);
end BsaMpsMsgTxPacker;

architecture rtl of BsaMpsMsgTxPacker is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);

   type StateType is (
      IDLE_S,
      TS_S,
      BSA_S,
      MPS_S);

   type RegType is record
      mpsPermit   : slv(3 downto 0);
      timeStamp   : slv(63 downto 0);
      bsaQuantity : Slv32Array(11 downto 0);
      wrd         : natural range 0 to 3;
      cnt         : natural range 0 to 11;
      txMaster    : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      mpsPermit   => (others => '0'),
      timeStamp   => (others => '0'),
      bsaQuantity => (others => (others => '0')),
      wrd         => 0,
      cnt         => 0,
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;

begin

   comb : process (bsaQuantity0, bsaQuantity1, bsaQuantity10, bsaQuantity11,
                   bsaQuantity2, bsaQuantity3, bsaQuantity4, bsaQuantity5,
                   bsaQuantity6, bsaQuantity7, bsaQuantity8, bsaQuantity9,
                   mpsPermit, r, timeStamp, timingStrobe, txSlave, usrRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the signals      
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check the timing strobe
            if (timingStrobe = '1') then
               -- Saves the values
               v.timeStamp       := timeStamp;
               v.bsaQuantity(0)  := bsaQuantity0;
               v.bsaQuantity(1)  := bsaQuantity1;
               v.bsaQuantity(2)  := bsaQuantity2;
               v.bsaQuantity(3)  := bsaQuantity3;
               v.bsaQuantity(4)  := bsaQuantity4;
               v.bsaQuantity(5)  := bsaQuantity5;
               v.bsaQuantity(6)  := bsaQuantity6;
               v.bsaQuantity(7)  := bsaQuantity7;
               v.bsaQuantity(8)  := bsaQuantity8;
               v.bsaQuantity(9)  := bsaQuantity9;
               v.bsaQuantity(10) := bsaQuantity10;
               v.bsaQuantity(11) := bsaQuantity11;
               v.mpsPermit       := mpsPermit;
               -- Next State
               v.state           := MPS_S;
            end if;
         ----------------------------------------------------------------------
         when MPS_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid              := '1';
               v.txMaster.tData(7 downto 0)   := x"00";
               v.txMaster.tData(11 downto 8)  := r.mpsPermit;
               v.txMaster.tData(15 downto 12) := x"0";
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               -- Next State
               v.state                        := TS_S;
            end if;
         ----------------------------------------------------------------------
         when TS_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(15 downto 0) := r.timeStamp((r.wrd*16)+15 downto (r.wrd*16));
               -- Check the counter
               if (r.wrd = 3) then
                  -- Reset the counter
                  v.wrd   := 0;
                  -- Next State
                  v.state := BSA_S;
               else
                  -- Increment the counter
                  v.wrd := r.wrd + 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BSA_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(15 downto 0) := r.bsaQuantity(r.cnt)((r.wrd*16)+15 downto (r.wrd*16));
               -- Check the counter
               if (r.wrd = 1) then
                  -- Reset the counter
                  v.wrd := 0;
                  -- Check the counter
                  if (r.cnt = 11) then
                     -- Reset the counter
                     v.cnt            := 0;
                     -- Terminate the AXIS frame
                     v.txMaster.tLast := '1';
                     -- Next State
                     v.state          := IDLE_S;
                  else
                     -- Increment the counter
                     v.cnt := r.cnt + 1;
                  end if;
               else
                  -- Increment the counter
                  v.wrd := r.wrd + 1;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (usrRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (usrClk) is
   begin
      if rising_edge(usrClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Fifo : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 0,      -- 0 = only when frame ready
         -- FIFO configurations
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 6,      -- requires min. 29 deep FIFO
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk    => usrClk,
         sAxisRst    => usrRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
