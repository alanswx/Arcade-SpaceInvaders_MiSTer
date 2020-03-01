library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;


entity invaders_blank is
	port(
		CLK               : in    std_logic;
		Rst_n_s           : in    std_logic;
		HSync             : in    std_logic;
		VSync             : in    std_logic;
		O_HBLANK          : out   std_logic;
		O_VBLANK          : out   std_logic
		);
end invaders_blank;

architecture rtl of invaders_blank is

	signal hblank          : std_logic;
	signal vblank          : std_logic;
	signal HCnt            : std_logic_vector(11 downto 0);
	signal VCnt            : std_logic_vector(11 downto 0);
	signal HSync_t1        : std_logic;
begin	
	
  p_overlay : process(Rst_n_s, Clk)
	variable HStart : boolean;
  begin
	if Rst_n_s = '0' then
	  HCnt <= (others => '0');
	  VCnt <= (others => '0');
	  HSync_t1 <= '0';
	  hblank <='1';
	  vblank <='1';
	elsif Clk'event and Clk = '1' then
	  HSync_t1 <= HSync;
	  HStart := (HSync_t1 = '0') and (HSync = '1');
	  if HStart then
		HCnt <= (others => '0');
	  else
		HCnt <= HCnt + "1";
	  end if;

	  if (VSync = '0') then
		VCnt <= (others => '0');
	  elsif HStart then
		VCnt <= VCnt + "1";
	  end if;
          if (HCnt = 538) then  -- 511
             hblank<='1';
          end if;
          if (HCnt = 27) then  -- 27?
             hblank<='0';
          end if;

	  if (Vcnt = 32) then
		  vblank<='0';
	  end if;
	  if (Vcnt = 255) then
		  vblank<='1';
	  end if;


	end if;
  end process;

  O_VBLANK  <= vblank;
  O_HBLANK  <= hblank;

end;
