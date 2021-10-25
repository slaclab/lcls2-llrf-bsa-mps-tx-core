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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity BsaMpsMsgTxPacker is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- BSA/MPS Interface
      usrClk       : in  sl;
      usrRst       : in  sl;
      timingStrobe : in  sl;            -- 1MHz strobe, single cycle
      timeStamp    : in  slv(63 downto 0);
      userValue    : in  slv(127 downto 0);
      bsaQuantity  : in  Slv32Array(11 downto 0);
      bsaSevr      : in  Slv2Array(11 downto 0);
      mpsPermit    : in  slv(7 downto 0);
      -- TX Data Interface
      txClk        : in  sl;
      txRst        : in  sl;
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType);
end BsaMpsMsgTxPacker;

architecture rtl of BsaMpsMsgTxPacker is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);

   type StateType is (
      IDLE_S,
      VERSION_S,
      USER_S,
      TS_S,
      MPS_S,
      BSA_SEVR_S,
      BSA_DATA_S);

   type RegType is record
      mpsPermit   : slv(7 downto 0);
      timeStamp   : slv(63 downto 0);
      userValue   : slv(127 downto 0);
      bsaQuantity : Slv32Array(11 downto 0);
      bsaSevr     : Slv2Array(11 downto 0);
      wrd         : natural range 0 to 7;
      cnt         : natural range 0 to 11;
      txMaster    : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      mpsPermit   => (others => '0'),
      timeStamp   => (others => '0'),
      userValue   => (others => '0'),
      bsaQuantity => (others => (others => '0')),
      bsaSevr     => (others => (others => '0')),
      wrd         => 0,
      cnt         => 0,
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;

   signal txRstSync : sl;
   signal usrReset  : sl;

begin

   comb : process (bsaQuantity, bsaSevr, mpsPermit, r, timeStamp, timingStrobe,
                   txSlave, userValue, usrReset) is
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
               v.timeStamp   := timeStamp;
               v.userValue   := userValue;
               v.bsaQuantity := bsaQuantity;
               v.bsaSevr     := bsaSevr;
               v.mpsPermit   := mpsPermit;
               -- Next State
               v.state       := VERSION_S;
            end if;
         ----------------------------------------------------------------------
         when VERSION_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(15 downto 8) := x"01";  -- Version 1
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               -- Next State
               v.state                       := USER_S;
            end if;
         ----------------------------------------------------------------------
         when USER_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(15 downto 0) := r.userValue((r.wrd*16)+15 downto (r.wrd*16));
               -- Check the counter
               if (r.wrd = 7) then
                  -- Reset the counter
                  v.wrd   := 0;
                  -- Next State
                  v.state := TS_S;
               else
                  -- Increment the counter
                  v.wrd := r.wrd + 1;
               end if;
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
                  v.state := MPS_S;
               else
                  -- Increment the counter
                  v.wrd := r.wrd + 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MPS_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid              := '1';
               v.txMaster.tData(3 downto 0)   := r.mpsPermit(3 downto 0);
               v.txMaster.tData(5 downto 4)   := r.bsaSevr(0);
               v.txMaster.tData(7 downto 6)   := r.bsaSevr(1);
               v.txMaster.tData(9 downto 8)   := r.bsaSevr(2);
               v.txMaster.tData(11 downto 10) := r.bsaSevr(3);
               v.txMaster.tData(13 downto 12) := r.bsaSevr(4);
               v.txMaster.tData(15 downto 14) := r.bsaSevr(5);
               -- Next State
               v.state                        := BSA_SEVR_S;
            end if;
         ----------------------------------------------------------------------
         when BSA_SEVR_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid              := '1';
               v.txMaster.tData(3 downto 0)   := r.mpsPermit(7 downto 4);
               v.txMaster.tData(5 downto 4)   := r.bsaSevr(6);
               v.txMaster.tData(7 downto 6)   := r.bsaSevr(7);
               v.txMaster.tData(9 downto 8)   := r.bsaSevr(8);
               v.txMaster.tData(11 downto 10) := r.bsaSevr(9);
               v.txMaster.tData(13 downto 12) := r.bsaSevr(10);
               v.txMaster.tData(15 downto 14) := r.bsaSevr(11);
               -- Next State
               v.state                        := BSA_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when BSA_DATA_S =>
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
      if (usrReset = '1') then
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

   U_RstSync : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => usrClk,
         asyncRst => txRst,
         syncRst  => txRstSync);

   usrReset <= usrRst or txRstSync;

   U_StoreThenForward : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,   -- Using TREADY for flow control
         VALID_THOLD_G       => 0,  -- 0 = only when frame ready (prevent tValid gap in outbound frame)
         -- FIFO configurations
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,  -- ASYNC FIFO
         FIFO_ADDR_WIDTH_G   => 6,      -- 2^6 = 64 > fixed packet size = 41
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
