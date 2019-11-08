-------------------------------------------------------------------------------
-- File       : BsaMpsMsgTxGtx7.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: GTX7 Wrapper
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

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity BsaMpsMsgTxGtx7 is
   generic (
      TPD_G                 : time       := 1 ns;
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIMULATION_G          : boolean    := false);
   port (
      -- Clock and Reset
      cPllRefClk   : in  sl;            -- 185.714 MHz 
      stableClk    : in  sl;
      stableRst    : in  sl;
      -- GTX Status/Config Interface   
      cPllLock     : out sl;
      txPreCursor  : in  slv(4 downto 0) := (others => '0');
      txPostCursor : in  slv(4 downto 0) := (others => '0');
      txDiffCtrl   : in  slv(3 downto 0) := "1111";
      -- GTX Interface
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        : in  sl;
      gtRxN        : in  sl;
      -- TX Interface
      txClk        : out sl;
      txRst        : out sl;
      txData       : in  slv(15 downto 0);
      txDataK      : in  slv(1 downto 0));
end BsaMpsMsgTxGtx7;

architecture mapping of BsaMpsMsgTxGtx7 is

   signal txOutClkOut : sl;
   signal txRstL      : sl;
   signal clk         : sl;
   signal rst         : sl;

begin

   txClk <= clk;
   txRst <= rst;

   U_BUFG : BUFG
      port map (
         I => txOutClkOut,
         O => clk);

   process(clk)
   begin
      if rising_edge(clk) then
         rst <= not(txRstL) after TPD_G;
      end if;
   end process;

   U_Gtx7Core : entity surf.Gtx7Core
      generic map (
         -- SIM Generics
         TPD_G                    => TPD_G,
         SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
         SIMULATION_G             => SIMULATION_G,
         -- CPLL Settings
         CPLL_REFCLK_SEL_G        => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G             => 2,
         CPLL_FBDIV_45_G          => 5,
         CPLL_REFCLK_DIV_G        => 1,
         RXOUT_DIV_G              => 1,
         TXOUT_DIV_G              => 1,
         RX_CLK25_DIV_G           => 10,
         TX_CLK25_DIV_G           => 10,
         PMA_RSV_G                => x"00018480",
         RX_OS_CFG_G              => "0000010000000",
         RXCDR_CFG_G              => x"03000023ff20400020",
         -- Configure PLL sources         
         TX_PLL_G                 => "CPLL",
         RX_PLL_G                 => "CPLL",
         -- Configure Data widths
         TX_EXT_DATA_WIDTH_G      => 16,
         TX_INT_DATA_WIDTH_G      => 20,
         TX_8B10B_EN_G            => true,
         RX_EXT_DATA_WIDTH_G      => 16,
         RX_INT_DATA_WIDTH_G      => 20,
         RX_8B10B_EN_G            => true,
         TX_BUF_EN_G              => true,
         -- Configure Buffer usage
         TX_OUTCLK_SRC_G          => "OUTCLKPMA",
         TX_DLY_BYPASS_G          => '1',
         TX_PHASE_ALIGN_G         => "NONE",
         TX_BUF_ADDR_MODE_G       => "FULL",
         RX_BUF_EN_G              => true,
         RX_OUTCLK_SRC_G          => "OUTCLKPMA",
         RX_USRCLK_SRC_G          => "RXOUTCLK",
         RX_DLY_BYPASS_G          => '1',
         RX_DDIEN_G               => '0',
         RX_BUF_ADDR_MODE_G       => "FULL",
         -- Configure RX comma alignment
         RX_ALIGN_MODE_G          => "GT",
         ALIGN_COMMA_DOUBLE_G     => "FALSE",
         ALIGN_COMMA_ENABLE_G     => "1111111111",
         ALIGN_COMMA_WORD_G       => 2,
         ALIGN_MCOMMA_DET_G       => "TRUE",
         ALIGN_MCOMMA_VALUE_G     => "0110000011",  -- K28.1
         ALIGN_MCOMMA_EN_G        => '1',
         ALIGN_PCOMMA_DET_G       => "TRUE",
         ALIGN_PCOMMA_VALUE_G     => "1001111100",  -- K28.1
         ALIGN_PCOMMA_EN_G        => '1',
         SHOW_REALIGN_COMMA_G     => "FALSE",
         RXSLIDE_MODE_G           => "AUTO",
         -- Configure Clock Correction
         CLK_CORRECT_USE_G        => "TRUE",
         CBCC_DATA_SOURCE_SEL_G   => "DECODED",
         CLK_COR_SEQ_2_USE_G      => "FALSE",
         CLK_COR_KEEP_IDLE_G      => "TRUE",  -- Need atleast one IDLE to align to the end of WIB frame
         CLK_COR_MAX_LAT_G        => 35,
         CLK_COR_MIN_LAT_G        => 32,
         CLK_COR_PRECEDENCE_G     => "TRUE",
         CLK_COR_REPEAT_WAIT_G    => 8,  -- Must be greater than the 6 IDLE bytes per frame
         CLK_COR_SEQ_LEN_G        => 2,
         CLK_COR_SEQ_1_ENABLE_G   => "0011",
         CLK_COR_SEQ_1_1_G        => "0100111100",  -- K28.1 
         CLK_COR_SEQ_1_2_G        => "0101011100",  -- K28.2
         CLK_COR_SEQ_1_3_G        => "0000000000",
         CLK_COR_SEQ_1_4_G        => "0000000000",
         CLK_COR_SEQ_2_ENABLE_G   => "0000",
         CLK_COR_SEQ_2_1_G        => "0000000000",
         CLK_COR_SEQ_2_2_G        => "0000000000",
         CLK_COR_SEQ_2_3_G        => "0000000000",
         CLK_COR_SEQ_2_4_G        => "0000000000",
         -- Configure Clock Correction
         RX_CHAN_BOND_EN_G        => true,  -- For some unknown reason, channel bonding required to make the clock correction to work
         RX_CHAN_BOND_MASTER_G    => true,
         CHAN_BOND_KEEP_ALIGN_G   => "FALSE",
         CHAN_BOND_MAX_SKEW_G     => 10,
         CHAN_BOND_SEQ_LEN_G      => 1,
         CHAN_BOND_SEQ_1_ENABLE_G => "0011",
         CHAN_BOND_SEQ_1_1_G      => "0100111100",  -- K28.1 
         CHAN_BOND_SEQ_1_2_G      => "0101011100",  -- K28.2
         CHAN_BOND_SEQ_1_3_G      => "0000000000",
         CHAN_BOND_SEQ_1_4_G      => "0000000000",
         CHAN_BOND_SEQ_2_ENABLE_G => "0000",
         CHAN_BOND_SEQ_2_1_G      => "0000000000",
         CHAN_BOND_SEQ_2_2_G      => "0000000000",
         CHAN_BOND_SEQ_2_3_G      => "0000000000",
         CHAN_BOND_SEQ_2_4_G      => "0000000000",
         CHAN_BOND_SEQ_2_USE_G    => "FALSE",
         -- RX Equalizer Attributes
         RX_EQUALIZER_G           => "DFE",
         RX_DFE_KL_CFG2_G         => X"301148AC",
         RX_CM_TRIM_G             => "010",
         RX_DFE_LPM_CFG_G         => x"0954",
         RXDFELFOVRDEN_G          => '1',
         RXDFEXYDEN_G             => '1')
      port map (
         stableClkIn      => stableClk,
         cPllRefClkIn     => cPllRefClk,
         cPllLockOut      => cPllLock,
         qPllRefClkIn     => '0',
         qPllClkIn        => '0',
         qPllLockIn       => '1',
         qPllRefClkLostIn => open,
         qPllResetOut     => open,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxOutClkOut      => open,
         rxUsrClkIn       => '0',
         rxUsrClk2In      => '0',
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '0',
         rxUserResetIn    => '0',
         rxResetDoneOut   => open,
         rxDataValidIn    => '1',
         rxSlideIn        => '0',
         rxDataOut        => open,
         rxCharIsKOut     => open,
         rxDecErrOut      => open,
         rxDispErrOut     => open,
         rxPolarityIn     => '0',
         rxBufStatusOut   => open,
         rxChBondLevelIn  => "000",
         rxChBondIn       => "00000",
         rxChBondOut      => open,
         txOutClkOut      => txOutClkOut,
         txUsrClkIn       => clk,
         txUsrClk2In      => clk,
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         txUserResetIn    => stableRst,
         txResetDoneOut   => txRstL,
         txDataIn         => txData,
         txCharIsKIn      => txDataK,
         txPolarityIn     => '0',
         txBufStatusOut   => open,
         txPowerDown      => "00",
         rxPowerDown      => "11",
         loopbackIn       => "000",
         txPreCursor      => txPreCursor,
         txPostCursor     => txPostCursor,
         txDiffCtrl       => txDiffCtrl);

end mapping;
