
-- Version : 0300
-- The latest version of this file can be found at:
--      http://www.fpgaarcade.com
-- minor tidy up by MikeJ
-------------------------------------------------------------------------------
-- Company:
-- Engineer:    PaulWalsh
--
-- Create Date:    08:45:29 11/04/05
-- Design Name:
-- Module Name:    Invaders Audio
-- Project Name:   Space Invaders
-- Target Device:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity zap_audio is
	Port (
	  Clk : in  std_logic;
	  S1  : in  std_logic_vector(5 downto 0);
	  S2  : in  std_logic_vector(5 downto 0);
	  Aud : out std_logic_vector(7 downto 0)
	  );
end;
 --* Port 3: (S1)
 --* bit 0= sound freq
 --* bit 1= sound freq
 --* bit 2= sound freq
 --* bit 3= sound freq
 --* bit 4= HI SHIFT MODIFIER
 --* bit 5= LO SHIFT MODIFIER
 --* bit 6= NC
 --* bit 7= NC
 --*
 --* Port 5: (S2)
 --* bit 0= BOOM sound
 --* bit 1= ENGINE sound
 --* bit 2= Screeching Sound
 --* bit 3= after car blows up, before it appears again
 --* bit 4= NC
 --* bit 5= coin counter
 --* bit 6= NC
 --* bit 7= NC

architecture Behavioral of zap_audio is

  signal ClkDiv5      : std_logic:='0';
  signal ClkDiv       : unsigned(10 downto 0) := (others => '0');
  signal ClkDiv2      : std_logic_vector(7 downto 0) := (others => '0');
  signal Clk7680_ena  : std_logic;
  signal Clk480_ena   : std_logic;
  signal Clk240_ena   : std_logic;
  signal Clk60_ena    : std_logic;

  signal s1_t1        : std_logic_vector(5 downto 0);
  signal s2_t1        : std_logic_vector(5 downto 0);
  signal tempsum      : std_logic_vector(7 downto 0);

  signal vco_cnt      : std_logic_vector(3 downto 0);

  signal TriDir1      : std_logic;
  signal Fnum         : std_logic_vector(3 downto 0);
  signal comp         : std_logic;

  signal SS           : std_logic;

  signal Excnt        : std_logic_vector(9 downto 0);
  signal ExShift      : std_logic_vector(15 downto 0);
  signal Ex           : std_logic_vector(2 downto 0);
  signal Explo        : std_logic;



  signal TrigSH       : std_logic;
  signal SHCnt        : std_logic_vector(8 downto 0);
  signal SH           : std_logic_vector(7 downto 0);
  signal SauHit       : std_logic_vector(8 downto 0);
  signal SHitTri      : std_logic_vector(5 downto 0);

  signal TrigIH       : std_logic;
  signal IHDir        : std_logic;
  signal IHDir1       : std_logic;
  signal IHCnt        : std_logic_vector(8 downto 0);
  signal IH           : std_logic_vector(7 downto 0);
  signal InHit        : std_logic_vector(8 downto 0);
  signal IHitTri      : std_logic_vector(5 downto 0);


  signal TrigMis      : std_logic;
  signal MisShift     : std_logic_vector(15 downto 0);
  signal MisCnt       : std_logic_vector(8 downto 0);
  signal miscnt1      : unsigned(7 downto 0);
  signal Mis          : std_logic_vector(2 downto 0);
  signal Missile      : std_logic;

  signal EnBG         : std_logic;
  signal BGFnum       : std_logic_vector(7 downto 0);
  signal BGCnum       : std_logic_vector(7 downto 0);
  signal bg_cnt       : unsigned(7 downto 0);
  signal BG           : std_logic;

  signal TrigEx       : std_logic;
  signal TrigEngine    : std_logic;
  signal TrigScreech   : std_logic;
  signal TrigAfterBlow : std_logic;

begin

p_clk_div5: process(Clk)
begin
  if(rising_edge(Clk)) then
    ClkDiv5 <= not ClkDiv5 ;
  end if;
end process p_clk_div5;

Sound: entity work.audio
port map(
                Clk_10 => ClkDiv5,
                Reset_n => '1',
                Motor1_n => not TrigEngine,
                Skid1 => TrigScreech,
                Crash_n => not TrigEx,
                NoiseReset_n => '1',
                Attract => '0',
                motorspeed =>  S2(3) & S2(2) & S2(1) & S2(0) ,
                Audio1 => Aud
                );


  -- do a crude addition of all sound samples
	p_clkdiv : process
	begin
	  wait until rising_edge(Clk);
	  Clk7680_ena <= '0';
	  if ClkDiv =  1277 then
		Clk7680_ena <= '1';
		ClkDiv <= (others => '0');
	  else
		ClkDiv <= ClkDiv + 1;
	  end if;
	end process;

	p_clkdiv2 : process
	begin
	  wait until rising_edge(Clk);
	  Clk480_ena <= '0';
	  Clk240_ena <= '0';
	  Clk60_ena  <= '0';

	  if (Clk7680_ena = '1') then
		ClkDiv2 <= ClkDiv2 + 1;

		if (ClkDiv2(3 downto 0) = "0000") then
		  Clk480_ena <= '1';
		end if;

		if (ClkDiv2(4 downto 0) = "00000") then
		  Clk240_ena <= '1';
		end if;

		if (ClkDiv2(7 downto 0) = "00000000") then
		  Clk60_ena <= '1';
		end if;

	  end if;
	end process;

   p_delay : process
   begin
	 wait until rising_edge(Clk);
	 s1_t1 <= S1;
	 s2_t1 <= S2;
   end process;

--***********************Explosion*****************************
-- Implement a Pseudo Random Noise Generator
	p_explosion_pseudo : process
	begin
	  wait until rising_edge(Clk);
	  if (Clk480_ena = '1') then
		if (ExShift = x"0000") then
		  ExShift <= "0000000010101001";
		else
		  ExShift(0) <= Exshift(14) xor ExShift(15);
		  ExShift(15 downto 1)  <= ExShift (14 downto 0);
		end if;
	  end if;
	end process;
	Explo <= ExShift(0);

	p_explosion_adsr : process
	begin
	  wait until rising_edge(Clk);
	  if (Clk480_ena = '1') then
		if (TrigEx = '1') then
		  ExCnt <= "1000000000";
		  Ex <= "100";
		elsif (ExCnt(9) = '1') then
		  ExCnt <= ExCnt + "1";
		  if ExCnt(8 downto 0) = '0' & x"64" then -- 100
			Ex <= "010";
		  elsif ExCnt(8 downto 0) = '0' & x"c8" then -- 200
			Ex <= "001";
		  elsif ExCnt(8 downto 0) = '1' & x"2c" then -- 300
			Ex <= "000";
		  end if;
		end if;
	  end if;
	end process;

-- Implement the trigger for The Explosion Sound
	p_explosion_trig : process
	begin
	  wait until rising_edge(Clk);
	  if (S1(0) = '1') and (s1_t1(0) = '0') then -- rising_edge
		TrigEx <= '1';
	  elsif (Clk480_ena = '1') then
		TrigEx <= '0';
	  end if;
	end process;
	p_engine_trig : process
	begin
	  wait until rising_edge(Clk);
	  if (S1(1) = '1') and (s1_t1(1) = '0') then -- rising_edge
		TrigEngine <= '1';
	  elsif (Clk480_ena = '1') then
		TrigEngine <= '0';
	  end if;
	end process;
	p_screech_trig : process
	begin
	  wait until rising_edge(Clk);
	  if (S1(2) = '1') and (s1_t1(2) = '0') then -- rising_edge
		TrigScreech <= '1';
	  elsif (Clk480_ena = '1') then
		TrigScreech <= '0';
	  end if;
	end process;
	p_afterblow_trig : process
	begin
	  wait until rising_edge(Clk);
	  if (S1(3) = '1') and (s1_t1(3) = '0') then -- rising_edge
		TrigAfterBlow <= '1';
	  elsif (Clk480_ena = '1') then
		TrigAfterBlow <= '0';
	  end if;
	end process;



end Behavioral;
