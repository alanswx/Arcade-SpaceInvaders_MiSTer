library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Numeric_Std.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity zap_audio is
	Port (
	  Clk : in  std_logic;
	  S1  : in  std_logic_vector(5 downto 0);
	  S2  : in  std_logic_vector(5 downto 0);
	  Aud : out std_logic_vector(15 downto 0);
  	  HEX1 : out std_logic_vector(159 downto 0)
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

 
-- This is a simplified integer mathmatic model that produces similar results to the real thing
--
-- C18 and C19 are capacitors with counters 15 bit range from 0 (empty) to 23250 (full)
--
-- Clocked from 10Mhz 
--
-- C18 changes up/down to get to Accelerator setting (4 bits) * 1550
--       charge add 1 every 945 (2.2 seconds empty to full)
--			discharge subtract 1 every 215 cycles (0.5 seconds from full to empty)
--
--C19 - we use this to drive output in high gear
--
--    low gear 
--			subtract 1 every 8 cycles (fast discharge)
--
--    high gear - timings from you tube!
--       add 1 every 1462 cycles (3.4 seconds) 
--       subtract 1 every 731 cycles (1.7 seconds)
--			
--oscillators all count from 0 to 127 and back down again, with a count derived from C19
--
-- Low Gear
--OSC1 count = Cap / 64
--OSC2 count = Cap / 256
--OSC3 count = (OSC2 count / 2) + (OSC2 count / 4) + (OSC2 count) / 16 (gives * 0.8125 but all bit manipulation)
--
-- High Gear - as above, but using C19 as source
--
-- OSC3 implemented by base 2 logarithm mask lookup OSC1 + OSC2 (bit shifted to give 15 bits)
--
--if enginenoise is turned off, C18 = C19 = 0

architecture Behavioral of zap_audio is

	--type MASK is array(0 to  255) of unsigned(15 downto 0);
	type MASK is array(NATURAL range <>) of std_logic_vector(15 downto 0);
	
	-- logarithmic masks (probabl only need 128)
	constant lookup : MASK := (
		X"0001",X"0003",X"0007",X"000F",X"001F",X"003F",X"007F",X"007F",X"007F",X"00FF",X"00FF",X"00FF",X"00FF",X"01FF",X"01FF",X"01FF",
		X"01FF",X"01FF",X"01FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"03FF",X"07FF",X"07FF",
		X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",X"07FF",
		X"07FF",X"07FF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",
		X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"0FFF",
		X"0FFF",X"0FFF",X"0FFF",X"0FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",
		X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",
		X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",
		X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"1FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",
		X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"3FFF",X"7FFF",X"7FFF",X"7FFF",X"7FFF",X"7FFF");

	-- Signals
	signal Target		: unsigned(14 downto 0) := (others => '0');
	signal Gear       : std_logic_vector(1 downto 0) := (others => '0');

	-- Capacitors	
	signal C18				: unsigned(14 downto 0) := (others => '0'); -- max 28735
	signal C19				: unsigned(14 downto 0) := (others => '0'); -- max 28735
	signal C18Count		: unsigned(9 downto 0) := (others => '0'); -- max 765
	-- charge / discharge rates
	signal C18TargetUp	: unsigned(9 downto 0) := to_unsigned(765,10);
	signal C18TargetDn	: unsigned(9 downto 0) := to_unsigned(174,10);

	signal C19Count		: unsigned(10 downto 0) := (others => '0'); -- max 417
	--signal C19Target		: unsigned(8 downto 0) := (others => '0'); -- max 417

	-- Oscillators
	signal OSC1Out		: unsigned(6 downto 0) := (others => '0');
	signal OSC2Out		: unsigned(6 downto 0) := (others => '0');
	signal OSC3Out		: unsigned(6 downto 0) := (others => '0');
	signal OSC1Count  : unsigned(12 downto 0) := (others => '0');
	signal OSC2Count  : unsigned(10 downto 0) := (others => '0');
	signal OSC3Count  : unsigned(10 downto 0) := (others => '0'); -- max 90
	signal OSC1Up     : std_logic := '1';
	signal OSC2Up     : std_logic := '1';
	signal OSC3Up     : std_logic := '1';
	signal OSC1Target : unsigned(12 downto 0) := (others => '0'); -- range 449 - 7183
	signal OSC2Target : unsigned(10 downto 0) := (others => '0'); -- range 111 - 1907
	signal OSC3Target : unsigned(10 downto 0) := (others => '0'); -- max 90


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

-- Mikes version

Engine : process(clk)
variable OSCIn : unsigned(14 downto 0);
variable X : unsigned(10 downto 0);
variable Rev : std_logic_vector(7 downto 0);
variable Rev16 : std_logic_vector(15 downto 0);
begin
  if(rising_edge(Clk)) then
		-- Where we want C18 to get to
		--Target <= to_unsigned(1915,11) * unsigned(S1(3 downto 0)); -- goes too high frequency around 85 mph on clock, max 105
		Target <= to_unsigned(1550,11) * unsigned(S1(3 downto 0)); -- so rescale down to where it sounds OK ?

		-- Feed for oscillators and target for C19
		if (S1(5) = '1') then
			OSCIn := C18;
		else
			OSCIn := C19;
		end if;

		-- Step amounts
		if (Gear(1) /= S1(5) or Gear(0) /= S1(4)) then
			Gear <= S1(5 downto 4);
			
			if (S1(5) = '1') then
				-- Low Gear
				C18TargetUp <= to_unsigned(945,10); -- 2.2 seconds to charge (765)
				C18TargetDn <= to_unsigned(215,10); -- 0.5 seconds to discharge (174)
			else
				if S1(4)='1' then
					-- High Gear
					C18TargetUp <= to_unsigned(945,10);
					C18TargetDn <= to_unsigned(215,10);
				end if;
			end if;
			
		end if;
		
		if S2(1)='1' then -- Engine noise off
		
			C18Count <= (others => '0');
			C19Count <= (others => '0');
			C18 <= (others => '0');
			C19 <= (others => '0');
		
			OSC1Count <= (others => '0');
			OSC1Target <= (others => '0'); 
			OSC2Count <= (others => '0');
			OSC2Target <= (others => '0'); 
			OSC3Count <= (others => '0');
			OSC3Target <= (others => '0'); 
			
			Aud <= (others => '0');
			
		else

			-- C18 Capacitor (controlled by Target)
			if Target > C18 and C18Count = C18TargetUp then
				C18Count <= (others => '0');
				C18 <= C18 + 1;
			else
				if Target < C18  and C18Count = C18TargetDn then
					C18Count <= (others => '0');
					C18 <= C18 - 1;
				else
					C18Count <= C18Count + 1;
				end if;
			end if;

			if (S1(5) = '1') then
				-- Low Gear, discharges C19
				if C19Count = to_unsigned(8,10) and C19 /= 0 then
					C19Count <= (others => '0');
					C19 <= C19 - 1;
				end if;
			else
				-- High Gear, C19 wants to equal output over 3.1 seconds
				-- really done by feedback, but simpler this way
				if Target > C19 and C19Count = 1462 then
					C19Count <= (others => '0');
					C19 <= C19 + 1;
				else
					if Target < C19 and C19Count = 731 then
						C19 <= C19 - 1;
					else
						C19Count <= C19Count + 1;
					end if;
				end if;
			end if;
		
		end if;

		
		-- Oscillators
		if OSC1Count = OSC1Target then
			OSC1Count <= (others => '0');
			OSC1Target <= (to_unsigned(7631,13) - OSCIn(14 downto 2));
			--OSC1Target <= C19(14 downto 6); -- Next target
			if OSC1Up='1' then
				-- Counting up
				if OSC1Out = 127 then
					OSC1Up <= '0';
				else
					OSC1Out <= OSC1Out + 1;
				end if;
			else
				-- Counting down
				if OSC1Out = 0 then
					OSC1Up <= '1';
				else
					OSC1Out <= OSC1Out - 1;
				end if;
			end if;
		else
			OSC1Count <= OSC1Count + 1;
		end if;

		if OSC2Count = OSC2Target then
			OSC2Count <= (others => '0');
			OSC2Target <= (to_unsigned(1907,11) - OSCIn(14 downto 4));
			--OSC2Target <= C19(14 downto 8); -- Next target
			if OSC2Up='1' then
				-- Counting up
				if OSC2Out = 127 then
					OSC2Up <= '0';
				else
					OSC2Out <= OSC2Out + 1;
				end if;
			else
				-- Counting down
				if OSC2Out = 0 then
					OSC2Up <= '1';
				else
					OSC2Out <= OSC2Out - 1;
				end if;
			end if;
		else
			OSC2Count <= OSC2Count + 1;
		end if;

		if OSC3Count = OSC3Target then
			OSC3Count <= (others => '0');
			X := (to_unsigned(953,11) - OSCIn(14 downto 5)); 		-- OSC2/2
			OSC3Target <= X + X(9 downto 1) + X(9 downto 4); -- (OSC2 count / 2) + (OSC2 count / 4) + (OSC2 count) / 16
			--OSC3Target <= '0' & C19(14 downto 9) + C19(14 downto 10) + C19(14 downto 12); 
			IF S2(1)='1' then
			--if OSC3Target=1488 then
				OSC3Out <= (others => '0');
			else
				if OSC3Up='1' then
					-- Counting up
					if OSC3Out = 127 then
						OSC3Up <= '0';
					else
						OSC3Out <= OSC3Out + 1;
					end if;
				else
					-- Counting down
					if OSC3Out = 0 then
						OSC3Up <= '1';
					else
						OSC3Out <= OSC3Out - 1;
					end if;
				end if;
			end if;
		else
			OSC3Count <= OSC3Count + 1;
		end if;
		
		-- Output
		Rev := std_logic_vector(('0' &OSC1Out) + OSC2Out);									-- Add OSC1 and OSC2 together
		Rev16(15) := '0';																				-- extend to 16 bits 
		Rev16(14 downto 7) := Rev(7 downto 0);
		Rev16(6 downto 0) := Rev(7 downto 1); 									
		Aud <= Rev16 and lookup(to_integer(unsigned(OSC3Out(6 downto 0) & '0')));	-- Mask volume according to OSC3
		
									-- Debug info to overlay
		HEX1(4 downto 0) <= "10000"; -- Space
		HEX1(8 downto 5) <= "0000";
		HEX1(12 downto 10) <= std_logic_vector(OSC3Target(10 downto 8));
		HEX1(18 downto 15) <= std_logic_vector(OSC3Target(7 downto 4));
		HEX1(23 downto 20) <= std_logic_vector(OSC3Target(3 downto 0));
		HEX1(29 downto 25) <= "10000"; -- Space
		HEX1(32 downto 30) <= std_logic_vector(C19(14 downto 12));
		HEX1(38 downto 35) <= std_logic_vector(C19(11 downto 8));
		HEX1(43 downto 40) <= std_logic_vector(C19(7 downto 4));
		HEX1(48 downto 45) <= std_logic_vector(C19(3 downto 0));
		HEX1(54 downto 50) <= "10000"; -- Space
	end if;
end process;











-- Original code (may keep some of it)


  
--***********************Explosion*****************************

-- Implement a Pseudo Random Noise Generator
--	p_explosion_pseudo : process
--	begin
--	  wait until rising_edge(Clk);
--	  if (Clk480_ena = '1') then
--		if (ExShift = x"0000") then
--		  ExShift <= "0000000010101001";
--		else
--		  ExShift(0) <= Exshift(14) xor ExShift(15);
--		  ExShift(15 downto 1)  <= ExShift (14 downto 0);
--		end if;
--	  end if;
--	end process;
--	Explo <= ExShift(0);
--
--	p_explosion_adsr : process
--	begin
--	  wait until rising_edge(Clk);
--	  if (Clk480_ena = '1') then
--		if (TrigEx = '1') then
--		  ExCnt <= "1000000000";
--		  Ex <= "100";
--		elsif (ExCnt(9) = '1') then
--		  ExCnt <= ExCnt + "1";
--		  if ExCnt(8 downto 0) = '0' & x"64" then -- 100
--			Ex <= "010";
--		  elsif ExCnt(8 downto 0) = '0' & x"c8" then -- 200
--			Ex <= "001";
--		  elsif ExCnt(8 downto 0) = '1' & x"2c" then -- 300
--			Ex <= "000";
--		  end if;
--		end if;
--	  end if;
--	end process;
--
---- Implement the trigger for The Explosion Sound
--	p_explosion_trig : process
--	begin
--	  wait until rising_edge(Clk);
--	  if (S1(0) = '1') and (s1_t1(0) = '0') then -- rising_edge
--		TrigEx <= '1';
--	  elsif (Clk480_ena = '1') then
--		TrigEx <= '0';
--	  end if;
--	end process;
--
--	p_screech_trig : process
--	begin
--	  wait until rising_edge(Clk);
--	  if (S1(2) = '1') and (s1_t1(2) = '0') then -- rising_edge
--		TrigScreech <= '1';
--	  elsif (Clk480_ena = '1') then
--		TrigScreech <= '0';
--	  end if;
--	end process;
--	
--	p_afterblow_trig : process
--	begin
--	  wait until rising_edge(Clk);
--	  if (S1(3) = '1') and (s1_t1(3) = '0') then -- rising_edge
--		TrigAfterBlow <= '1';
--	  elsif (Clk480_ena = '1') then
--		TrigAfterBlow <= '0';
--	  end if;
--	end process;

end Behavioral;
