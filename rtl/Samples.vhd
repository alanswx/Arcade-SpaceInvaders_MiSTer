library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity samples is
port(
	 -- Sound related
	 audio_enabled  : in  std_logic;
	 audio_port_0   : in  std_logic_vector( 7 downto 0);
	 audio_port_1   : in  std_logic_vector( 7 downto 0);
	 
	 audio_in       : in  std_logic_vector(15 downto 0);
	 audio_out_L    : out std_logic_vector(15 downto 0);
	 audio_out_R    : out std_logic_vector(15 downto 0);
	 
	 -- Access to samples
	 wave_addr      : inout std_logic_vector(27 downto 0);
	 wave_read      : out std_logic;
	 wave_data      : in std_logic_vector(7 downto 0);
	 wave_ready     : in std_logic;
	 
	 -- table loading
	 dl_addr        : in  std_logic_vector(24 downto 0);
	 dl_wr          : in  std_logic;
	 dl_data        : in  std_logic_vector( 7 downto 0);
	 dl_download	 : in  std_logic;
	 samples_ok     : out std_logic;
	 
	 HEX1           : out std_logic_vector(159 downto 0);
	 
	 -- Clocks and things
	 CLK_SYS        : in  std_logic; -- 10Mhz (for loading table)
	 clock          : in  std_logic; -- 80Mhz (this drives the rest)
	 reset          : in  std_logic  -- high to reset
 );
end samples;

architecture struct of samples is

 -- Clock dividers
 signal wav_clk_cnt  : std_logic_vector(11 downto 0); -- 44kHz divider / sound counter (80Mhz count to 1814 (x"716") for 44khz clock)
 signal wav_freq_cnt : std_logic_vector(1 downto 0);  -- divide further to give 22Khz (0) and 11Khz (1)
 signal wav_freq_lst : std_logic_vector(1 downto 0);  -- for rising edge checks
 
 -- wave info (aka Table)
 type addr_t is array (0 to 15) of std_logic_vector(23 downto 0);
 type mode_t is array (0 to 15) of std_logic_vector(15 downto 0);
  
 signal wav_addr_start : addr_t;
 signal wav_addr_end   : addr_t;
 signal wav_mode       : mode_t := (others=>(others=>'0'));
 signal table_loaded   : std_logic register := '0';
 
 signal wave_left      : std_logic_vector(15 downto 0) register := (others=>'0'); 
 signal wave_right     : std_logic_vector(15 downto 0) register := (others=>'0'); 
 signal wave_read_ct   : std_logic_vector(2 downto 0) register := (others=>'0'); 
 
 -- sound control info
 signal snd_id : integer;
 signal snd_addr_play  : addr_t := (others=>(others=>'1'));
 signal ports          : std_logic_vector(15 downto 0); 
 signal last_ports     : std_logic_vector(15 downto 0); 
 signal this_ports     : std_logic_vector(15 downto 0); 
 signal next_ports     : std_logic_vector(15 downto 0); 
 
 -- Audio variables
-- signal audio_sum_l    : integer;
-- signal audio_sum_r    : integer;
 signal audio_sum_l    : signed(19 downto 0);
 signal audio_sum_r    : signed(19 downto 0);
 signal audio_l        : signed(19 downto 0);
 signal audio_r        : signed(19 downto 0);
 
 signal max_cycle      : std_logic_vector(7 downto 0) := x"00";
 signal Over           : std_logic_vector(2 downto 0) := "000";
begin

----------------
-- Table Load --
----------------

-- wav_mode - 8 bits - if byte = 00 then this bit does not trigger anything
-- bit 0 = 11khz
-- bit 1 = 22khz
-- bit 2 = 44khz
-- bit 4 = 16 bit (off = 8 bit)
-- bit 5 = Stereo (off = mono)
--
-- trigger mode - 8 bits
-- bit 0 = ON  one shot (sample plays once)
-- bit 0 = OFF restarts if bit still active at end (loops)
-- bit 1 = ON  cuts off sample if bit goes low (should it fade?)
-- bit 1 = OFF continues until end of sample reached
-- bit 4 = output LEFT channel
-- bit 5 = output RIGHT channel (set both for MONO/STEREO)

process (CLK_SYS,dl_download,dl_wr,dl_data)
variable ID : integer;
begin
	if rising_edge(CLK_SYS) then
	
		if dl_download='1' and dl_wr='1' then
		
			ID := to_integer(unsigned(dl_addr(6 downto 3)));
			
			case dl_addr(2 downto 0) is
				when "000" => -- Wave mode
					wav_mode(ID)(7 downto 0) <= dl_data;
					if dl_data(2 downto 0) /= "000" then
						table_loaded <= '1';
					end if;
				when "001" => -- Trigger mode
					wav_mode(ID)(15 downto 8) <= dl_data;
				when "010" => -- Start Address
					wav_addr_start(ID)(23 downto 16) <= dl_data;
				when "011" => -- Start Address
					wav_addr_start(ID)(15 downto 8) <= dl_data;
				when "100" => -- Start Address
					wav_addr_start(ID)(7 downto 0) <= dl_data;
				when "101" => -- End Address
					wav_addr_end(ID)(23 downto 16) <= dl_data;
				when "110" => -- End Address
					wav_addr_end(ID)(15 downto 8) <= dl_data;
				when "111" => -- End Address
					wav_addr_end(ID)(7 downto 0) <= dl_data;
			end case;
		end if;
	end if;
end process;
 
-----------------
-- Wave player --
-----------------

-- current IO bit & sample to be looking at
snd_id <= to_integer(unsigned(wav_clk_cnt(9 downto 6)));
ports  <= audio_port_1 & audio_port_0;
samples_ok <= table_loaded;

-- wave player
process (clock, reset, table_loaded)
variable wave_addr_wk : std_logic_vector(23 downto 0); 
begin
	if table_loaded='1' then
		if reset='1' then
			wav_clk_cnt  <= (others=>'0');
			wav_freq_cnt <= "00";
			snd_addr_play <= (others=>(others=>'1'));
			wave_read    <= '0';
			audio_out_L <= x"0000";
			audio_out_R <= x"0000";
			HEX1 <= (others=>'0');
		else 
			-- Use falling edge to interleave commands with DDRAM module
			if falling_edge(clock) then
			
				-- make sure we don't miss any bits being set
				next_ports <= next_ports or ports;
				
				if snd_addr_play(snd_id)=x"FFFFFF" then
					-- All Start play on 0 to 1 transition
					if (last_ports(snd_id)='0' and this_ports(snd_id)='1') then
						snd_addr_play(snd_id) <= wav_addr_start(snd_id);
						max_cycle <= (others=>'0');
					end if;
				else
					-- cut out when signal zero
					if (wav_mode(snd_id)(9)='1' and this_ports(snd_id)='0') then
						snd_addr_play(snd_id) <= x"FFFFFF";
					end if;
				end if;
				
				-- 44.1kHz base tempo / high bits for scanning sound
				if wav_clk_cnt = x"716" then  -- divide 80MHz by 1814 => 44.101kHz
				
					wav_clk_cnt <= (others=>'0');
					wav_freq_lst <= wav_freq_cnt;
					wav_freq_cnt <= wav_freq_cnt + '1';

					-- cycle along ports last / this
					last_ports <= this_ports;
					this_ports <= next_ports;
					next_ports <= ports;
					
					-- latch final audio / reset sum
					audio_r <= audio_sum_r;
					audio_l <= audio_sum_l;
					audio_sum_r <= resize(signed(audio_in), 20);
					audio_sum_l <= resize(signed(audio_in), 20);
				else
					wav_clk_cnt <= wav_clk_cnt + 1;
				end if;
				
				if audio_enabled='1' then
--					-- clip audio
--					if  audio_r(19 downto 2) > 32767 then
--						audio_out_R <= x"7FFF";
--					elsif	audio_r(19 downto 2) < -32768 then 
--						audio_out_R <= x"8000";
--					else
--						audio_out_R <= std_logic_vector(audio_r(17 downto 2));
--					end if;
--
--					if  audio_l(19 downto 2) > 32767 then
--						audio_out_L <= x"7FFF";
--					elsif	audio_l(19 downto 2) < -32768 then 
--						audio_out_L <= x"8000";
--					else
--						audio_out_L <= std_logic_vector(audio_l(17 downto 2));
--					end if;

					audio_out_R <= std_logic_vector(audio_r(17 downto 2));
					audio_out_L <= std_logic_vector(audio_l(17 downto 2));

				else
					audio_out_L <= x"0000";
					audio_out_R <= x"0000";
				end if;

				-- select only useful cycles (0-15)
				if wav_clk_cnt(10)='0' then 
				
					-- is this sample present
					if wav_mode(snd_id)(2 downto 0) /= "000" then
				
						if snd_addr_play(snd_id) /= x"FFFFFF" then
		
							-------------------------------------------
							-- Data read 8 or 16 bit, mono or stereo --
							-------------------------------------------
							
							--wave_read <= '0';
							
							-- set ddram addr for first byte and set read sequence in motion
							if wav_clk_cnt(5 downto 0) = "000000" then
								wave_addr <= "0000" & snd_addr_play(snd_id);
								wave_addr_wk := snd_addr_play(snd_id);
								wave_read    <= '1';
								wave_read_ct <= "001";
							end if;
						
							if wave_read_ct /= "000" then
							
									case wave_read_ct is
										when "001" => -- First byte returned ?
											if wave_ready='1' then
											
												-- Debug longest time to get first data back
												if to_integer(unsigned(wav_clk_cnt(5 downto 0))) > to_integer(unsigned(max_cycle)) then
													max_cycle <= "00" & wav_clk_cnt(5 downto 0);
												end if;
											
												wave_read <= '0';
												
												case wav_mode(snd_id)(5 downto 4) is
												
													when "00" => -- 8 bit mono
														wave_left <= (not wave_data(7)) & wave_data(6 downto 0) & x"00";
														wave_right <= (not wave_data(7)) & wave_data(6 downto 0) & x"00";
														wave_read_ct <= "000";
														
													when "01" | "11" => -- 16 bit (mono or stereo)
														wave_left <= x"00" & wave_data;
														wave_addr_wk :=  wave_addr_wk + 1;
														wave_read_ct <= "010";
														
													when "10" => -- 8 bit stereo
														wave_left <= (not wave_data(7)) & wave_data(6 downto 0) & x"00";
														wave_addr_wk :=  wave_addr_wk + 1;
														wave_read_ct <= "100";
														
												end case;
											
											end if;
												
										when "010" => -- Read next byte
											wave_read_ct <= "011";
											wave_read <= '1';
																						
										when "011" => -- high byte of 16 bit sample
											if wave_ready='1' then
												wave_left(15 downto 8) <= wave_data;
												wave_read <= '0';
												
												if wav_mode(snd_id)(5)='1' then
													-- Stereo 
													wave_addr_wk :=  wave_addr_wk + 1;
													wave_read_ct <= "100";
												else
													-- Mono
													wave_right <= wave_data & wave_left(7 downto 0);
													wave_read_ct <= "000";
												end if;
											end if;

										when "100" => -- Read next byte
											wave_read_ct <= "101";
											wave_read <= '1';											

										when "101" => -- right channel 8 bit (or low byte of 16 bit) 8 bit is unsigned!
											if wave_ready='1' then
											
												wave_read <= '0';
											
												if wav_mode(snd_id)(4)='1' then -- 16 bit Stereo
													wave_right <= x"00" & wave_data;
													wave_addr_wk :=  wave_addr_wk + 1;
													wave_read_ct <= "110";
												else
													wave_right <= (not wave_data(7)) & wave_data(6 downto 0) & x"00";
													wave_read_ct <= "000";										
												end if;
											
											end if;

										when "110" => -- Read next byte
											wave_read_ct <= "111";
											wave_read <= '1';											

										when "111" =>
											if wave_ready='1' then
												wave_right(15 downto 8) <= wave_data;
												wave_read_ct <= "000";
												wave_read    <= '0';
											end if;
											
										when others => null;
											
									end case;							

									wave_addr  <= "0000" & wave_addr_wk;
															
							end if;
							
							-- Data all read, add to output counters
							if wav_clk_cnt(5 downto 0) = "111110" then
							
								-- Left channel
								if wav_mode(snd_id)(12)='1' then
									audio_sum_l <= audio_sum_l + to_integer(signed(wave_left));
								end if;
								
								-- Right channel
								if wav_mode(snd_id)(13)='1' then
									audio_sum_r <= audio_sum_r + to_integer(signed(wave_right));
								end if;
						
								wave_left  <= x"0000";
								wave_right <= x"0000";

								-- Increment address depending on frequency and size
								if wav_mode(snd_id)(2)='1' or 
								  (wav_mode(snd_id)(1)='1' and wav_freq_lst(0)='0' and wav_freq_cnt(0)='1') or
								  (wav_mode(snd_id)(0)='1' and wav_freq_lst(1)='0' and wav_freq_cnt(1)='1') then
								  
								  case wav_mode(snd_id)(5 downto 4) is
										when "00" => 
											-- 8 bit mono
											snd_addr_play(snd_id) <= snd_addr_play(snd_id) + 1;
										when "01" | "10" =>
											-- 16 bit mono or 8 bit stereo
											snd_addr_play(snd_id) <= snd_addr_play(snd_id) + 2;
										when "11" =>
											-- 16 bit stereo
											snd_addr_play(snd_id) <= snd_addr_play(snd_id) + 4;
								  end case;

								  -- Debug, did we overrun ?
								  if wave_read_ct /= "000" then
									  Over <= wave_read_ct;
									  wave_read_ct <= "000";
								  end if;
								  
								end if;
															
							end if;
							
							if wav_clk_cnt(5 downto 0) = "111111" then
								-- End of Wave data ?
								if snd_addr_play(snd_id) > wav_addr_end(snd_id) then 	
									-- Restart ?
									if (wav_mode(snd_id)(8)='0' and this_ports(snd_id)='1') then
										-- Loop back to the start
										snd_addr_play(snd_id) <= wav_addr_start(snd_id);
									else
										-- Stop
										snd_addr_play(snd_id) <= x"FFFFFF";
									end if;									
								end if;
							end if;
							
							-- Debug info to overlay
							HEX1(4 downto 0) <= "10000"; -- Space
							HEX1(8 downto 5) <= last_ports(15 downto 12);
							HEX1(13 downto 10) <= last_ports(11 downto 8);
							HEX1(18 downto 15) <= last_ports(7 downto 4);
							HEX1(23 downto 20) <= last_ports(3 downto 0);
							HEX1(29 downto 25) <= "10000"; -- Space
							HEX1(33 downto 30) <= this_ports(15 downto 12);
							HEX1(38 downto 35) <= this_ports(11 downto 8);
							HEX1(43 downto 40) <= this_ports(7 downto 4);
							HEX1(48 downto 45) <= this_ports(3 downto 0);
							HEX1(54 downto 50) <= "10000"; -- Space
							HEX1(58 downto 55) <= "0" & Over;
							HEX1(64 downto 60) <= "10000"; -- Space
							HEX1(68 downto 65) <= max_cycle(7 downto 4);
							HEX1(73 downto 70) <= max_cycle(3 downto 0);
							HEX1(79 downto 75) <= "10000"; -- Space							
							
						end if; -- Playing

					end if; -- Bit Active
					
				end if; -- useful
				
			end if; -- rising clock

		end if; -- reset
		
	end if; -- table loaded
						
end process;

end;
