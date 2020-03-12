//============================================================================
//  Arcade: Space Invaders
//
//  Port to MiSTer Dave Wood (oldgit)
//  April 2019 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned
	
	
		// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT

);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : (status[2] | landscape) ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : (status[2] | landscape) ? 8'd3 : 8'd4;



`include "build_id.v" 
localparam CONF_STR = {
	"A.INVADERS;;",
	"-;",
	"H0O1,Aspect Ratio,Original,Wide;", 
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"DIP;",
	"-;",
	"O8,Overlay,On,Off;",
	"O9,Overlay Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_40, clk_10;

wire clk_sys = clk_10;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_40),
	.outclk_1(clk_10)
);


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;

reg	[7:0] machine_info;



wire [10:0] ps2_key;

wire [15:0] joy1, joy2, joy3, joy4;
wire [15:0] joya, joya2;

wire [21:0] gamma_bus;



hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
   .clk_sys(clk_sys),
   .HPS_BUS(HPS_BUS),

   .conf_str(CONF_STR),

   .buttons(buttons),
   .status(status),
   .status_menumask({landscape,direct_video}),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),
   .direct_video(direct_video),

   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_index(ioctl_index),
	
   .joystick_0(joy1),
   .joystick_1(joy2),
   .joystick_2(joy3),
   .joystick_3(joy4),
   .joystick_analog_0(joya),
   .joystick_analog_1(joya2),
   .ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'h75: btn_up            <= pressed; // up
			'h72: btn_down          <= pressed; // down
			'h6B: btn_left          <= pressed; // left
			'h74: btn_right         <= pressed; // right
			'h76: btn_coin1         <= pressed; // ESC
			'h05: btn_start1        <= pressed; // F1
			'h06: btn_start2        <= pressed; // F2
			'h14: btn_fireA         <= pressed; // lctrl
			'h11: btn_fireB         <= pressed; // lalt
			'h29: btn_fireC         <= pressed; // Space
			'h12: btn_fireD         <= pressed; // l-shift

			// JPAC/IPAC/MAME Style Codes
			'h16: btn_start1        <= pressed; // 1
			'h1E: btn_start2        <= pressed; // 2
                        'h26: btn_start3        <= pressed; // 3
			'h25: btn_start4        <= pressed; // 4

			'h2E: btn_coin1         <= pressed; // 5
			'h36: btn_coin2         <= pressed; // 6
			'h2D: btn_up2           <= pressed; // R
			'h2B: btn_down2         <= pressed; // F
			'h23: btn_left2         <= pressed; // D
			'h34: btn_right2        <= pressed; // G
			'h1C: btn_fire2A        <= pressed; // A
			'h1B: btn_fire2B        <= pressed; // S
			'h21: btn_fire2C        <= pressed; // Q
			'h1D: btn_fire2D        <= pressed; // W
		endcase
	end
end


reg btn_left   = 0;
reg btn_right  = 0;
reg btn_down   = 0;
reg btn_up     = 0;
reg btn_fireA  = 0;
reg btn_fireB  = 0;
reg btn_fireC  = 0;
reg btn_fireD  = 0;
reg btn_coin1  = 0;
reg btn_coin2  = 0;
reg btn_start1 = 0;
reg btn_start2 = 0;
reg btn_start3 = 0;
reg btn_start4 = 0;
reg btn_up2    = 0;
reg btn_down2  = 0;
reg btn_left2  = 0;
reg btn_right2 = 0;
reg btn_fire2A = 0;
reg btn_fire2B = 0;
reg btn_fire2C = 0;
reg btn_fire2D = 0;

wire m_start1  = btn_start1 | joy[8];
wire m_start2  = btn_start2 | joy[9];
wire m_coin1   = btn_coin1  | btn_coin2 | joy[10];

wire m_right1  = btn_right  | joy1[0];
wire m_left1   = btn_left   | joy1[1];
wire m_down1   = btn_down   | joy1[2];
wire m_up1     = btn_up     | joy1[3];
wire m_fire1a  = btn_fireA  | joy1[4];
wire m_fire1b  = btn_fireB  | joy1[5];
wire m_fire1c  = btn_fireC  | joy1[6];
wire m_fire1d  = btn_fireD  | joy1[7];

wire m_right2  = btn_right2 | joy2[0];
wire m_left2   = btn_left2  | joy2[1];
wire m_down2   = btn_down2  | joy2[2];
wire m_up2     = btn_up2    | joy2[3];
wire m_fire2a  = btn_fire2A | joy2[4];
wire m_fire2b  = btn_fire2B | joy2[5];
wire m_fire2c  = btn_fire2C | joy2[6];
wire m_fire2d  = btn_fire2D | joy2[7];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;

wire m_coin3   = joy3[10];
wire m_start3  = joy3[8] | btn_start3;
wire m_left3   = joy3[1];
wire m_right3  = joy3[0];
wire m_up3     = joy3[3];
wire m_down3   = joy3[2];
/*
wire m_fire3a  = joy3[4];
wire m_fire3b  = joy3[5];
wire m_fire3c  = joy3[6];
wire m_fire3d  = joy3[7];
*/

wire m_coin4   = joy4[10];
wire m_start4  = joy4[8] | btn_start4;
wire m_left4   = joy4[1];
wire m_right4  = joy4[0];
wire m_up4     = joy4[3];
wire m_down4   = joy4[2];
/*
wire m_fire4a  = joy4[4];
wire m_fire4b  = joy4[5];
wire m_fire4c  = joy4[6];
wire m_fire4d  = joy4[7];
*/


wire [2:0] ms_col;
wire [2:0] bs_col;
wire [2:0] sh_col;
wire [2:0] sc1_col;
wire [2:0] sc2_col;
wire [2:0] mn_col;

wire [15:0] joy = joy1 | joy2;


///////////////////////////////////////////////////////////////////


wire hblank;
wire vblank;
wire hs, vs;
wire r,g,b;
//wire no_rotate = 1'b1;//status[2] | direct_video | landscape;
wire no_rotate = status[2] | direct_video | landscape;
reg ce_pix;
always @(posedge clk_40) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

arcade_video #(260,224,6) arcade_video
(
   .*,

   .clk_video(clk_40),

   .RGB_in({r,r,g,g,b,b}),
   .HBlank(hblank),
   .VBlank(vblank),
   .HSync(HSync),
   .VSync(VSync),

   .rotate_ccw(ccw),
   .fx(status[5:3])

);


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;
wire reset;
assign reset = (RESET | status[0] | buttons[1] | ioctl_download);

wire [7:0] GDB0;
wire [7:0] GDB1;
wire [7:0] GDB2;
wire [7:0] GDB3;


localparam mod_spaceinvaders = 0;
localparam mod_shuffleboard  = 1;
localparam mod_vortex        = 2;
localparam mod_280zap        = 3;
localparam mod_blueshark     = 4;
localparam mod_boothill      = 5;
localparam mod_lunarrescue   = 6;
localparam mod_ozmawars      = 7;
localparam mod_spacelaser    = 8;
localparam mod_spacewalk     = 9;
localparam mod_spaceinvaderscv = 10;
localparam mod_unknown1      = 11;
localparam mod_unknown2      = 12;
localparam mod_spaceinvadersii = 13;
localparam mod_amazingmaze   = 14;
localparam mod_attackforce   = 15;
localparam mod_ballbomb      = 16;
localparam mod_bowler        = 17;
localparam mod_checkmate     = 18;
localparam mod_clowns        = 19;
localparam mod_cosmo         = 20;
localparam mod_dogpatch      = 21;
localparam mod_doubleplay    = 22;
localparam mod_guidedmissle  = 23;
localparam mod_claybust      = 24;
localparam mod_gunfight      = 25;
localparam mod_indianbattle  = 26;
localparam mod_lupin         = 27;
localparam mod_m4            = 28;
localparam mod_phantom       = 29;
localparam mod_polaris       = 30;
localparam mod_desertgun     = 31;
localparam mod_lagunaracer   = 32;
localparam mod_seawolf       = 33;
localparam mod_yosakdon      = 34;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;


//wire [4:0] seawolf_position =  8'd16 + joya[7:3]; // not quite correct
wire [9:0] center_joystick_x   =  8'd127 + joya[7:0];
wire [4:0] seawolf_position  =  center_joystick_x[7:3]; 
wire [9:0] center_joystick_y   =  8'd127 + joya[15:8];
//wire [9:0] positive_joystick_y   =  joya[15] ? 8'd128+ $signed(joya[15:8]) : 10'b0;
wire [7:0] positive_joystick_y   =  joya[15] ? ~joya[15:8] : 10'b0;
wire [7:0] positive_joystick_y_2   =  joya2[15] ? ~joya2[15:8] : 10'b0;
wire   [3:0] zap_throttle = positive_joystick_y[6:3] ;
//wire   [2:0] dogpatch_y = positive_joystick_y[6:4] ;
wire   [2:0] dogpatch_y = center_joystick_y[7:3] ;
wire   [2:0] dogpatch_y_2 = positive_joystick_y_2[6:4] ;



reg [7:0] clown_y = 128;
reg [5:0] clown_timer= 0;
reg vsync_r;
//always @(posedge m_right or posedge m_left ) begin
always @(posedge clk_sys) 
begin
    vsync_r          <= VSync;
    if (vsync_r ==0 && VSync== 1) 
    begin
       //if (clown_timer > 1) begin
        if (m_right && clown_y < 255)
            clown_y <= clown_y +1;
        else if (m_left && clown_y > 0)
            clown_y <= clown_y -1;
       clown_timer <= clown_timer +1;
       //end
       //else
	//     clown_timer <= clown_timer +1;
    end
end

reg fire_toggle = 0;
always @(posedge m_fire_a) fire_toggle <= ~fire_toggle;

reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

reg landscape;
reg ccw;
reg color_rom_enabled;

wire Trigger_ShiftCount;
wire Trigger_ShiftData;
wire Trigger_AudioDeviceP1;
wire Trigger_AudioDeviceP2;
wire Trigger_WatchDogReset;
wire [7:0] PortWr;
wire [7:0] S;
wire [7:0] SR= { S[0], S[1], S[2], S[3], S[4], S[5], S[6], S[7]} ;
wire ShiftReverse;

always @(*) begin

        landscape <= 1;
        ccw<=0;
        color_rom_enabled<=0;
	WDEnabled <= 1'b1;
        GDB0 <= 8'hFF;
        GDB1 <= 8'hFF;
        GDB2 <= 8'hFF;
        GDB3 <= S;

        // space invaders default PortWr mapping
        Trigger_ShiftCount     <= PortWr[2];
        Trigger_AudioDeviceP1  <= PortWr[3];
        Trigger_ShiftData      <= PortWr[4];
        Trigger_AudioDeviceP2  <= PortWr[5];
        Trigger_WatchDogReset  <= PortWr[6];


        case (mod) 
        mod_spaceinvaders:
        begin
          landscape<=0;
          ccw<=1;

          GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
          GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
          GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
        end
        mod_shuffleboard:
        begin
          landscape<=0;
          ccw<=0;
          GDB1 <= S;
	  // IN0
          GDB2 <= sw[1] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, m_coin1 };
          GDB3 <= SR;
	  // IN1
	  // GB4 <=
	  // IN2 // trackball Y
	  // GB5 <=
	  // IN3 // trackball X
	  // GB6 <=
	  // 4,5,6 ???
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[5];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_AudioDeviceP2  <= PortWr[6];
          Trigger_WatchDogReset  <= PortWr[4];
        end
        mod_vortex:
        begin
          //GDB0 -- all FF
          //
          landscape<=0;
          ccw<=1;
	  // IN2 -- settings
          GDB0 <= sw[2] | { 1'b0, m_right2,m_left2,m_fire2a,1'b0,1'b0, 1'b0, 1'b0};
          GDB1 <= S;
	  // IN0
	  //GDB2 <= sw[1] | { 1'b1, m_right1,m_left1,m_fire1a,1'b1,m_start1, m_start2, ~m_coin1 };
	  //GDB2 <= sw[1] | { 1'b1, m_right1,m_left1,m_fire1a,1'b1,m_start1, m_start2, ~m_coin1 };
          GDB2 <= 8'h00;
	  // IN1
          GDB3 <= sw[1] | { 1'b0, m_right2,m_left2,m_fire2a,1'b0,m_start1, m_start2, ~m_coin1 };
	  
          Trigger_ShiftCount     <= PortWr[0];
          Trigger_AudioDeviceP1  <= PortWr[1];
          Trigger_ShiftData      <= PortWr[6];
          Trigger_AudioDeviceP2  <= PortWr[7];
          Trigger_WatchDogReset  <= PortWr[4];
        end
        mod_lagunaracer:
	begin
 	  landscape<=0;
	   GDB0 <= sw[0] | { ~m_start1, ~m_coin1, 1'b1, m_fire_a, m_fire_b,1'b0,1'b0,1'b0/*(joya[11:8]*/};
           //GDB1 <= sw[1] | { 1'b0, 1'b1, 1'b1,1'b1,1'b1,1'b1, 1'b1, 1'b1 };
           GDB1 <= 8'd127-joya[7:0];
           GDB2 <= sw[2] | { 1'b0, 1'b0, 1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
	  // IN0
          //GDB0 <= sw[0] | { m_start1, m_coin1,1'b1,m_fire_a,1'b1,1'b0, 1'b0,1'b0};
	  // IN1
          //GDB1 <= sw[1] | { 1'b0, 1'b1,1'b1,1'b1,1'b1,1'b1, 1'b1, 1'b1 };
	  // IN2
          //GDB2 <= sw[2] | { 1'b1, 1'b1,1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          Trigger_ShiftCount     <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[2];
          Trigger_ShiftData      <= PortWr[3];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[7];
        end
	mod_280zap:
	begin
 	  landscape<=1;
	   //GDB0 <= sw[0] | { ~m_start1, ~m_coin1, 1'b1, m_fire_a, m_fire_b,1'b0,1'b0,1'b0/*(joya[11:8]*/};
	   GDB0 <= sw[0] | { ~m_start1, ~m_coin1, 1'b1, fire_toggle, zap_throttle};
           //GDB1 <= sw[1] | { 1'b0, 1'b1, 1'b1,1'b1,1'b1,1'b1, 1'b1, 1'b1 };
           GDB1 <= 8'd127-joya[7:0];
           GDB2 <= sw[2] | { 1'b0, 1'b0, 1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
	  // IN0
          //GDB0 <= sw[0] | { m_start1, m_coin1,1'b1,m_fire_a,1'b1,1'b0, 1'b0,1'b0};
	  // IN1
          //GDB1 <= sw[1] | { 1'b0, 1'b1,1'b1,1'b1,1'b1,1'b1, 1'b1, 1'b1 };
	  // IN2
          //GDB2 <= sw[2] | { 1'b1, 1'b1,1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          Trigger_ShiftCount     <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[2];
          Trigger_ShiftData      <= PortWr[3];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[7];

	end

        mod_blueshark:
        begin
          GDB0 <= SR;
	  // IN0
          //GDB1 <= 8'd127-joya[7:0];
          //GDB1 <= { 8'b01000010};
        //  GDB1 <= { 8'd63 + joya[7:1]};
          GDB1 <= (8'd127+joya[7:0]) & 8'hFE;
	  // IN1
          GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b1,1'b1,1'b1,m_coin1 ,~m_fire_a};
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
        end
        mod_boothill:
        begin 
          // IN0
          GDB0 <= sw[0] | { m_fire1a, 1'b0,1'b1,1'b0,m_right1,m_left1,m_down1,m_up1};
          // IN1
          GDB1 <= sw[1] | { m_fire2a, 1'b0,1'b1,1'b0,m_right2,m_left2,m_down2,m_up2};
          // IN2
          GDB2 <= sw[2] | { m_start1, m_coin1,m_start1,1'b0,1'b1,1'b1, 1'b0, 1'b1 };
          Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          //<= PortWr[5]; // tone_generator_low_w
          //<= PortWr[6]; // tone_generator_hi_w
	  GDB3 <= ShiftReverse ? SR: S;

        end
        mod_lunarrescue:
        begin
          landscape<=0;
          color_rom_enabled<=1;
          ccw<=1;
	  WDEnabled <= 1'b0;
          //GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b1,1'b0, 1'b0,1'b0};
          //GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
          //GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
          GDB0 <= sw[0] | { 1'b1, 1'b0,1'b0,1'b0,1'b0,1'b1, 1'b0,1'b0};
          //GDB0 <= sw[0] | { 1'b0, 1'b0, 1'b0, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
          GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
          GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
        end
        mod_ozmawars:
        begin
            landscape<=0;
            ccw<=1;
            color_rom_enabled<=1;
         // GDB0 <= sw[0] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,1'b1, 1'b1,1'b1};
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
            GDB2 <= sw[2] | { m_start1, m_coin1,m_start2,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          end
        mod_spacelaser:
        begin
            landscape<=0;
            ccw<=1;
            color_rom_enabled<=1;
        // GDB0 <= sw[0] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,1'b1, 1'b1,1'b1};
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
		  end
        mod_spacewalk:
        begin
	     WDEnabled <= 1'b0;
             GDB0 <= 8'b0;
             GDB1 <= sw[1] | { 1'b1, 1'b1,1'b1,1'b1,m_start1, m_start2, m_coin1 , 1'b1};
             GDB2 <= 8'b0;
             Trigger_ShiftCount     <= PortWr[1];
             Trigger_AudioDeviceP1  <= PortWr[3];
             Trigger_ShiftData      <= PortWr[2];
             Trigger_AudioDeviceP2  <= PortWr[6];
             Trigger_WatchDogReset  <= PortWr[7];
             //<= PortWr[5]; // tone_generator_low_w
             //<= PortWr[6]; // tone_generator_hi_w
        end
        mod_spaceinvaderscv:
        begin
            landscape<=0;
            ccw<=1;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
        end
        mod_unknown1:
        begin
        GDB0 <= 8'hFF;
        GDB1 <= 8'hFF;
        GDB2 <= 8'hFF;
        end
        mod_unknown2:
        begin
        GDB0 <= 8'h00;
        GDB1 <= 8'h00;
        GDB2 <= 8'h00;
        end
        mod_spaceinvadersii:
        begin
	 landscape<=0;
          ccw<=1;
          color_rom_enabled<=1;
          GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b1, 1'b0,1'b0};
          //GDB0 <= sw[0] | { 1'b0, 1'b0, 1'b0, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
          GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
          GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
        end
        mod_amazingmaze:
        begin
	     WDEnabled <= 1'b0;
             GDB0 <= sw[0] | { m_up2, m_down2, m_right2, m_left2, m_up1, m_down1, m_right1, m_left1} ;
             GDB1 <= sw[1] | { 1'b0, 1'b0,1'b0,1'b0,m_coin1, 1'b0, m_start2, m_start1};
             GDB2 <= 8'b0;
        end
        mod_attackforce:
	begin
            landscape<=0;
	    WDEnabled <= 1'b0;
            ccw<=1;
            GDB0 <= sw[0] | { ~m_coin1, 1'b1,1'b1,1'b1,1'b1,~m_fire_a, ~m_left,~m_right};
            GDB1 <= 8'b0;
            GDB2 <= 8'b0;
            Trigger_ShiftCount     <= PortWr[7];
            Trigger_AudioDeviceP1  <= PortWr[4];
            Trigger_ShiftData      <= PortWr[3];
            Trigger_AudioDeviceP2  <= PortWr[6];
            Trigger_WatchDogReset  <= PortWr[5];

	end
        mod_ballbomb:
	begin
            landscape<=0;
	    WDEnabled <= 1'b0;
            ccw<=1;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
	end
        mod_bowler:
	begin
            landscape<=0;
	// 0 - dips
            GDB0 <= sw[0];
	// 1 - controls
	   GDB1 <= ~S;
            //GDB1 <= sw[1] | { 1'b0,1'b0,1'b0,1'b0,m_fire_b,m_start1, m_fire_a, m_coin1 };
    	// 2, 3 trackball
            GDB2 <= sw[2];
            GDB3 <= ~SR;
             Trigger_ShiftCount     <= PortWr[1];
             //Trigger_AudioDeviceP1  <= PortWr[3];
             Trigger_ShiftData      <= PortWr[2];
             //Trigger_AudioDeviceP2  <= PortWr[6];
             Trigger_WatchDogReset  <= PortWr[4];
             //<= PortWr[5]; // bowler_audio_1_w 
             //<= PortWr[6]; // bowler_audio_2_w
             //<= PortWr[7]; // bowler_lights_1_w
             //<= PortWr[8]; //
             //<= PortWr[9]; //
             //<= PortWr[A]; //
             //<= PortWr[E]; //
             //<= PortWr[F]; //
	end
        mod_checkmate:
	begin
	  WDEnabled <= 1'b0;
          // IN0
          GDB0 <= sw[0] | { m_right2,m_left2,m_down2,m_up2,m_right1,m_left1,m_down1,m_up1};
          GDB1 <= sw[1] | { m_right4,m_left4,m_down4,m_up4,m_right3,m_left3,m_down3,m_up3};
          GDB1 <= sw[1] ;
          GDB2 <= sw[2]; // dips
          GDB3 <= sw[3] | { m_coin1, 1'b0,1'b0,1'b0,m_start4,m_start3,m_start2,m_start1};
          //GDB3 <= sw[3] | { m_coin1, 1'b0,1'b0,1'b0,1'b0,1'b0,m_start2,m_start1};
          //<= PortWr[3]; //  checkmat_io_w
	end
        mod_clowns:
	begin
          //GDB0 -- all FF
          //
          landscape<=1;
	  // IN0
          //GDB0 <= sw[0] | 8'b0;
          //GDB0 <= 8'd127-joya[7:0];
          GDB0 <= clown_y;
          GDB1 <= sw[1] | { 1'b1,~m_coin1,~m_start1,~m_start2,1'b1,1'b1,1'b1,1'b1};
          GDB2 <= sw[2] | { m_up, 1'b0,1'b0,1'b0,1'b0,1'b1, 1'b0,1'b0};
	  
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_AudioDeviceP2  <= PortWr[7];
          Trigger_WatchDogReset  <= PortWr[4];
             //<= PortWr[5]; // tone_generator_low_w
             //<= PortWr[6]; // tone_generator_hi_w
	end
        mod_cosmo:
	begin
            landscape<=0;
            ccw<=0;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
            GDB1 <= sw[1] | { 1'b0, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
        Trigger_ShiftCount     <= 1'b0;
        Trigger_AudioDeviceP1  <= PortWr[3];
        Trigger_ShiftData      <= 1'b0;
        Trigger_AudioDeviceP2  <= PortWr[5];
        Trigger_WatchDogReset  <= PortWr[6];
	end
	mod_dogpatch:
        begin
            landscape<=1;
            ccw<=0;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { ~m_fire_b, dogpatch_y_2, 1'b1, ~m_start2, ~m_start1, ~m_coin1 };
            GDB1 <= sw[1] | { ~m_fire_a, dogpatch_y, 1'b1, 1'b1, 1'b1 , 1'b1};
            GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_AudioDeviceP2  <= PortWr[7];
          Trigger_WatchDogReset  <= PortWr[4];
             //<= PortWr[5]; // tone_generator_low_w
             //<= PortWr[6]; // tone_generator_hi_w

	end
	mod_doubleplay:
        begin
            landscape<=1;
            ccw<=0;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { ~m_start1, joya[7:2], ~m_fire_a};
            GDB1 <= sw[1] | { ~m_start2, joya[7:2], ~m_fire_a};
            GDB2 <= sw[2] | { ~m_coin1, 7'b0 };
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          //Trigger_AudioDeviceP2  <= PortWr[7];
          Trigger_WatchDogReset  <= PortWr[4];
             //<= PortWr[5]; // tone_generator_low_w
             //<= PortWr[6]; // tone_generator_hi_w

	end
        mod_guidedmissle:
        begin 
          // IN0
          GDB0 <= sw[0] | {~m_fire2a,~m_start1,1'b1,1'b1,~m_right2,~m_left2,1'b1,1'b1};
          GDB1 <= sw[1] | {~m_fire1a,~m_start2,1'b1,1'b1,~m_right1,~m_left1,~m_coin1,1'b1};
          // IN2
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          //<= PortWr[5]; // tone_generator_low_w
          //<= PortWr[6]; // tone_generator_hi_w
	  GDB3 <= ShiftReverse ? SR: S;
        end
        mod_claybust:
        begin 
          // IN0
          GDB1 <= sw[1] | { 1'b0,1'b0,1'b0,1'b0, ~m_start1, ~m_coin1, m_fire1a, 1'b1 };
          //GDB2 <=  // GUN low bits
          //GDB6 <=  // GUN high bits
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
        end
        mod_gunfight:
	begin
	  WDEnabled <= 1'b0;
          // IN0
          GDB0 <= sw[0] | { m_fire1a,1'b0,1'b0,1'b0,m_right1,m_left1,m_down1,m_up1};
          GDB1 <= sw[1] | { m_fire2a,1'b0,1'b0,1'b0,m_right2,m_left2,m_down2,m_up2};
          GDB2 <= sw[2] | { m_start1,m_coin1, 6'b0};
          Trigger_ShiftCount     <= PortWr[2];
          Trigger_AudioDeviceP1  <= PortWr[1];
          Trigger_ShiftData      <= PortWr[4];
          //Trigger_WatchDogReset  <= PortWr[4];
	end
//        mod_indianbattle:
        mod_lupin:
        begin
          landscape<=0;
	  ccw <= 1;
          GDB0 <= sw[0] | { m_up2,m_left2,m_down2,m_right2,m_fire2a,1'b0,1'b1,1'b1};
          GDB1 <= sw[1] | { m_up1,m_left1,m_down1,m_right1,m_fire1a,m_start1,m_start2,m_coin1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[2];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[4];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[6];
        end
        mod_m4:
        begin 
          landscape<=1;
	  WDEnabled <= 1'b0;
          // IN0
          GDB0 <= sw[0] | { 1'b1, 1'b1,~m_fire2b,~m_fire2a,~m_down2,1'b1,~m_up2,1'b1};
          GDB1 <= sw[1] | { 1'b1,~m_start2,~m_fire1b,~m_fire1a,~m_down1,~m_start1,~m_up1,~m_coin1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          Trigger_AudioDeviceP2  <= PortWr[5];
	  GDB3 <= ShiftReverse ? SR: S;

        end
        mod_phantom:
        begin
          landscape<=1;
	  GDB0 <= SR;
          GDB1 <= sw[1] | { 1'b1,1'b1,~m_coin1,~m_fire1a,~m_right1,~m_left1,~m_down1,~m_up1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[5];
          Trigger_AudioDeviceP2  <= PortWr[6];
        end
        mod_polaris:
	begin
          landscape<=0;
	  ccw<=1;
          GDB0 <= sw[0] | { m_up2,m_left2,m_down2,m_right2,m_fire2a,1'b0,1'b0,1'b0};
          GDB1 <= sw[1] | { m_up1,m_left1,m_down1,m_right1,m_fire1a,m_start1,m_start2,m_coin1};
          GDB2 <= sw[2];

          Trigger_ShiftCount     <= PortWr[1];
          Trigger_ShiftData      <= PortWr[3];
          Trigger_WatchDogReset  <= PortWr[5];
          Trigger_AudioDeviceP1  <= PortWr[2];
          Trigger_AudioDeviceP2  <= PortWr[4];
          //<= PortWr[6];

	end
        mod_desertgun:
	begin
          landscape<=1;
          GDB0 <= SR;
          GDB1 <= joya[7:0];
          GDB2 <= sw[2] | { ~m_fire1a,m_coin1, 2'b0, 2'b0, 2'b0};

          Trigger_ShiftCount     <= PortWr[1];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[3];
          //<= PortWr[5]; // tone_generator_low_w
          //<= PortWr[6]; // tone_generator_hi_w
          Trigger_AudioDeviceP2  <= PortWr[7];

	end
	mod_seawolf:
	begin
          landscape<=1;
	  WDEnabled <= 1'b0;
          ccw<=0;
          GDB0 <= SR;
	  // IN0
          GDB1 <= sw[0] | { 2'b0, m_fire_a, seawolf_position};
          GDB2 <= sw[1] | { 3'b0,1'b0 /*erase?*/, 2'b0,m_start1,m_coin1};
          Trigger_ShiftData      <= PortWr[3];
          Trigger_ShiftCount     <= PortWr[4];
          //<= PortWr[5];
          //<= PortWr[6];
          //<= PortWr[4];
       end
        mod_yosakdon:
	begin
	  WDEnabled <= 1'b0;
          landscape<=1;
          //GDB0 <= SR;
	  // IN0
          GDB1 <= sw[0] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, m_coin1 };
	  // IN1
          GDB2 <= sw[1] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,1'b0,1'b0,1'b0};
	  Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_AudioDeviceP2  <= PortWr[5];
       end
      endcase
end

wire [15:0] color_prom_addr;
wire [7:0]  color_prom_out;
wire [15:0]RAB;
wire [15:0]AD;
wire [7:0]RDB;
wire [7:0]RWD;
wire [7:0]IB;
wire [5:0]SoundCtrl3;
wire [5:0]SoundCtrl5;
wire Rst_n_s;
wire RWE_n;
wire Video;
wire HSync;
wire VSync;

invaderst invaderst(
        .Rst_n(~(reset)),
        .Clk(clk_sys),
        .ENA(),
		  
        .GDB0(GDB0),
        .GDB1(GDB1),
        .GDB2(GDB2),
        .GDB3(GDB3),

	.WD_Enabled(WDEnabled),

        .RDB(RDB),
        .IB(IB),
        .RWD(RWD),
        .RAB(RAB),
        .AD(AD),
        .SoundCtrl3(SoundCtrl3),
        .SoundCtrl5(SoundCtrl5),
        .Rst_n_s(Rst_n_s),
        .RWE_n(RWE_n),
        .Video(Video),

	.color_prom_addr(color_prom_addr),
	.color_prom_out(color_prom_out),
        .O_VIDEO_R(r),
        .O_VIDEO_G(g),
        .O_VIDEO_B(b),
        //.HBLANK(hblank),
        //.VBLANK(vblank),
        .Overlay(~status[8]),
	.OverlayTest(status[9]),

        .HSync(HSync),
        .VSync(VSync),


        .Trigger_ShiftCount(Trigger_ShiftCount),
        .Trigger_ShiftData(Trigger_ShiftData),
        .Trigger_AudioDeviceP1(Trigger_AudioDeviceP1),
        .Trigger_AudioDeviceP2(Trigger_AudioDeviceP2),
        .Trigger_WatchDogReset(Trigger_WatchDogReset),

        .PortWr(PortWr),
        .S(S),
        .ShiftReverse(ShiftReverse),

	.mod_vortex(mod==mod_vortex),
	.mod_280zap(mod==mod_280zap),
	.mod_blueshark(mod==mod_blueshark)
        );
invaders_memory invaders_memory (
        .Clock(clk_sys),
        .RW_n(RWE_n),
        .Addr(AD),
        .Ram_Addr(RAB),
        .Ram_out(RDB),
        .Ram_in(RWD),
        .Rom_out(IB),
	.color_prom_out(color_prom_out),
	.color_prom_addr(color_prom_addr),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr&ioctl_index==0),
	.mod_vortex(mod==mod_vortex),
	.mod_attackforce(mod==mod_attackforce)
        );

invaders_audio invaders_audio (
        .Clk(clk_sys),
        .S1(SoundCtrl3),
        .S2(SoundCtrl5),
        .Aud(audio)
        );

invaders_blank invaders_blank (
        .CLK(clk_sys),
        .Rst_n_s(Rst_n_s),
        .HSync(HSync),
        .VSync(VSync),
        .O_HBLANK(hblank),
        .O_VBLANK(vblank)
	);
/*
invaders_video invaders_video (
        .Video(Video),
        .Overlay(~status[8]),
        .CLK(clk_sys),
        .Rst_n_s(Rst_n_s),
        .HSync(HSync),
        .VSync(VSync),
	.color_prom_addr(color_prom_addr2),
	.color_prom_out(color_prom_out),
	.OverlayTest(status[9]),
        .O_VIDEO_R(r2),
        .O_VIDEO_G(g2),
        .O_VIDEO_B(b2),
        .O_HSYNC(hs),
        .O_VSYNC(vs),
        .O_HBLANK(hblank),
        //.O_VBLANK(vblank)
	
        );
	
*/

/*
invaders_top invaders_top
(

	.Clk(clk_10),
	.Clk_mem(clk_sys),
	.clk_vid(clk_6),

	.I_RESET(reset),

	.GDB0(GDB0),
	.GDB1(GDB1),
	.GDB2(GDB2),
	

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr&(ioctl_index==0 || ioctl_index==2)),
	.dn_index(ioctl_index),

	.r(r),
	.g(g),
	.b(b),
	//.hblnk(hblank),
	.vblnk(vblank),
	.hs(hs),
	.vs(vs),
	
	.audio_out(audio),
	.ms_col(ms_col),
	.bs_col(bs_col),
	.sh_col(sh_col),
	.sc1_col(sc1_col),
	.sc2_col(sc2_col),
	.mn_col(mn_col),
	.color_rom_enabled(color_rom_enabled)
	

);
*/
endmodule
