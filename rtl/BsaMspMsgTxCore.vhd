-------------------------------------------------------------------------------
-- File       : BsaMspMsgTxCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Core Module
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

library lcls2_llrf_bsa_mps_tx_core; 

entity BsaMspMsgTxCore is
   generic (
      TPD_G                 : time       := 1 ns;
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIMULATION_G          : boolean    := false);
   port (
      -- BSA/MPS Interface (usrClk domain)
      usrClk        : in  sl;           -- Must be > 45 MHz
      usrRst        : in  sl;
      timingStrobe  : in  sl;           -- ~1MHz strobe, single cycle
      timeStamp     : in  slv(63 downto 0);
      userValue     : in  slv(127 downto 0);
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
      bsaSevr0      : in  slv(1 downto 0);
      bsaSevr1      : in  slv(1 downto 0);
      bsaSevr2      : in  slv(1 downto 0);
      bsaSevr3      : in  slv(1 downto 0);
      bsaSevr4      : in  slv(1 downto 0);
      bsaSevr5      : in  slv(1 downto 0);
      bsaSevr6      : in  slv(1 downto 0);
      bsaSevr7      : in  slv(1 downto 0);
      bsaSevr8      : in  slv(1 downto 0);
      bsaSevr9      : in  slv(1 downto 0);
      bsaSevr10     : in  slv(1 downto 0);
      bsaSevr11     : in  slv(1 downto 0);
      mpsPermit     : in  slv(3 downto 0);
      -- GTX's Clock and Reset
      cPllRefClk    : in  sl;           -- 185.714 MHz 
      stableClk     : in  sl;           -- GTX's stable clock reference
      stableRst     : in  sl;
      -- GTX Status/Config Interface   
      cPllLock      : out sl;
      txPreCursor   : in  slv(4 downto 0) := (others => '0');
      txPostCursor  : in  slv(4 downto 0) := (others => '0');
      txDiffCtrl    : in  slv(3 downto 0) := "1111";
      -- GTX Ports
      gtTxP         : out sl;
      gtTxN         : out sl;
      gtRxP         : in  sl;
      gtRxN         : in  sl);
end BsaMspMsgTxCore;

architecture mapping of BsaMspMsgTxCore is

   signal txClk   : sl;
   signal txRst   : sl;
   signal txData  : slv(15 downto 0);
   signal txdataK : slv(1 downto 0);

begin

   ------------
   -- TX Module
   ------------
   U_Tx : entity lcls2_llrf_bsa_mps_tx_core.BsaMpsMsgTxFramer
      generic map (
         TPD_G => TPD_G)
      port map (
         -- BSA/MPS Interface (usrClk domain)
         usrClk          => usrClk,
         usrRst          => usrRst,
         timingStrobe    => timingStrobe,
         timeStamp       => timeStamp,
         userValue       => userValue,
         bsaQuantity(0)  => bsaQuantity0,
         bsaQuantity(1)  => bsaQuantity1,
         bsaQuantity(2)  => bsaQuantity2,
         bsaQuantity(3)  => bsaQuantity3,
         bsaQuantity(4)  => bsaQuantity4,
         bsaQuantity(5)  => bsaQuantity5,
         bsaQuantity(6)  => bsaQuantity6,
         bsaQuantity(7)  => bsaQuantity7,
         bsaQuantity(8)  => bsaQuantity8,
         bsaQuantity(9)  => bsaQuantity9,
         bsaQuantity(10) => bsaQuantity10,
         bsaQuantity(11) => bsaQuantity11,
         bsaSevr(0)      => bsaSevr0,
         bsaSevr(1)      => bsaSevr1,
         bsaSevr(2)      => bsaSevr2,
         bsaSevr(3)      => bsaSevr3,
         bsaSevr(4)      => bsaSevr4,
         bsaSevr(5)      => bsaSevr5,
         bsaSevr(6)      => bsaSevr6,
         bsaSevr(7)      => bsaSevr7,
         bsaSevr(8)      => bsaSevr8,
         bsaSevr(9)      => bsaSevr9,
         bsaSevr(10)     => bsaSevr10,
         bsaSevr(11)     => bsaSevr11,
         mpsPermit       => mpsPermit,
         -- TX Data Interface (txClk domain)
         txClk           => txClk,
         txRst           => txRst,
         txData          => txData,
         txdataK         => txdataK);

   -------------
   -- GTX Module
   -------------
   U_Gtx : entity lcls2_llrf_bsa_mps_tx_core.BsaMpsMsgTxGtx7
      generic map (
         TPD_G                 => TPD_G,
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIMULATION_G          => SIMULATION_G)
      port map (
         -- Clock and Reset
         cPllRefClk   => cPllRefClk,
         stableClk    => stableClk,
         stableRst    => stableRst,
         -- GTX Status/Config Interface   
         cPllLock     => cPllLock,
         txPreCursor  => txPreCursor,
         txPostCursor => txPostCursor,
         txDiffCtrl   => txDiffCtrl,
         -- GTX Interface
         gtTxP        => gtTxP,
         gtTxN        => gtTxN,
         gtRxP        => gtRxP,
         gtRxN        => gtRxN,
         -- TX Interface
         txClk        => txClk,
         txRst        => txRst,
         txData       => txData,
         txDataK      => txDataK);

end architecture mapping;
