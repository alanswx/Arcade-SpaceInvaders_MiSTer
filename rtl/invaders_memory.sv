
module invaders_memory(
input            Clock,
input            RW_n,
input            CPU_RW_n,
input     [15:0] Addr,
input     [15:0] Ram_Addr,
output    [7:0]  Ram_out,
input     [7:0]  Ram_in,
output    [7:0]  Rom_out,
output    [7:0]  color_prom_out,
input     [10:0] color_prom_addr,
input     [15:0] dn_addr,
input     [7:0]  dn_data,
input            dn_wr,
input            mod_vortex,
output           Vortex_bit,
input            mod_attackforce,
input            mod_cosmo,
input            mod_polaris,
input            mod_lupin
);

/*
 reg [10:0] color_prom_addr=0;
always @(posedge Clock ) begin
	//0010 0100 0000 0000 // 2400
	//0011 1111 1111 1111
	if (Ram_Addr > 16'h2400) begin
		color_prom_addr<={ Ram_Addr[12:7],Ram_Addr[4:0]};
	end
end
//wire [10:0] color_prom_addr={ Ram_Addr[12:7],Ram_Addr[4:0]};
*/

wire [7:0] color_prom_out_rom;

wire [7:0]rom_data;
wire [7:0]rom2_data;

wire [15:0]rom_addr_vortex = {Addr[15:10],~Addr[9],Addr[8:4],~Addr[3],Addr[2:1],~Addr[0]};
wire [15:0]rom_addr_attackforce = {Addr[15:10],Addr[8],Addr[9],Addr[7:0]};
wire [15:0] rom_addr = mod_vortex? rom_addr_vortex : mod_attackforce ? rom_addr_attackforce : Addr;

wire rom_cs  = dn_wr & dn_addr[15:13]==3'b000;

// 0010 0000 0000 0000
wire rom2_cs = dn_wr & dn_addr[15:13]==3'b001;
// 0100 0000 0000 0000
// 0100 0100 0000 0000
wire vrom_cs = dn_wr & dn_addr[15:11]==5'b01000;

// Low ROM 0000-1FFF
dpram #(.addr_width_g(13),
	.data_width_g(8))
cpu_prog_rom(
	.clock_a(Clock),
	.wren_a(rom_cs),
	.address_a(dn_addr[12:0]),
	.data_a(dn_data),

	.clock_b(Clock),
	.address_b(rom_addr[12:0]),
	.q_b(rom_data)
);

// High ROM 4000-5FFF
dpram #(.addr_width_g(13),
	.data_width_g(8))
cpu_prog_rom2(
	.clock_a(Clock),
	.wren_a(rom2_cs),
	.address_a(dn_addr[12:0]),
	.data_a(dn_data),

	.clock_b(Clock),
	.address_b(rom_addr[12:0]),
	.q_b(rom2_data)
);

// 0 - RED, 1 - BLUE, 2 - GREEN

assign color_prom_out = mod_cosmo ? {color_prom_out_rom[7:3],color_prom_out_rom[1],color_prom_out_rom[2],color_prom_out_rom[0]} : color_prom_out_rom;

//=======================
//
// W A R N I N G
//
// The lupin color stuff
// doesn't work, isn't
// complete
//
//=======================


// Colour ROM / RAM
wire use_color_ram = mod_cosmo | mod_lupin ;
// Cosmo can read/write Colour RAM (5C00-5FFF)
//
// Lupin, Polaris, xxx uses C000-DFFF with a 2k repeat
wire [10:0] lupin_addr = ( rom_addr[10:0] & 11'h1f) | (( rom_addr[10:0] & 11'h1f80) >> 8'd2);
wire [7:0] color_ram_out;
//wire [7:0] color_ram_in = use_color_ram ? Ram_in : dn_data;
wire [10:0] color_ram_addr = mod_lupin ? lupin_addr :  {1'b0,rom_addr[9:0]}; // ??  : dn_addr[10:0]; // will stop cosmo loading it in first place
wire color_ram_wr = mod_cosmo ? (rom_addr[15:10]==6'b010111 & ~CPU_RW_n) : mod_lupin ? (rom_addr[15:13]==3'b110 & ~CPU_RW_n):1'b0;

wire [10:0] lupin_prom_addr = color_prom_addr[4:0] | {color_prom_addr[10:5],5'b00000};
dpram #(.addr_width_g(11),
	.data_width_g(8))
video_rom(
	.clock_a(Clock),
	.wren_a(vrom_cs | color_ram_wr),
	.address_a(vrom_cs ? dn_addr[10:0] : color_ram_addr),
	.data_a(vrom_cs ? dn_data : Ram_in),
	.q_a(color_ram_out),

	.clock_b(Clock),
	.address_b(mod_lupin ? lupin_prom_addr : color_prom_addr),
	.q_b(color_prom_out_rom)
);
	
always @(rom_addr, rom_data, rom2_data, color_ram_out) begin
	
	Rom_out = 8'b00000000;

	// Lupin, Polaris, xxx uses C000-DFFF with a 2k repeat
	// allow them to read back the color_ram
	if (rom_addr[15]==1'b1) begin
	   if (mod_lupin & rom_addr[14:13]==2'b10) begin
		 Rom_out = color_ram_out;
	   end
	end
	else
	begin
		case (rom_addr[15:11])
			5'b00000 : Rom_out = rom_data;
			5'b00001 : Rom_out = rom_data;
			5'b00010 : Rom_out = rom_data;
			5'b00011 : Rom_out = rom_data;
			
			5'b01000 : Rom_out = rom2_data;
			5'b01001 : Rom_out = rom2_data;
			5'b01010 : Rom_out = rom2_data;
			5'b01011 : if (mod_cosmo & (rom_addr[10]==1'b1)) begin
							 Rom_out = color_ram_out;
						  end 
						  else begin
							 Rom_out = rom2_data;
						  end
			default : Rom_out = 8'b00000000;
		endcase
	end
end

// For Vortex - Read next screen byte
wire [15:0] VortexAddr = Ram_Addr + 1;
wire [7:0]  VortexColour;

assign Vortex_bit = VortexColour[0];
		
dpram #(
	.addr_width_g(13),
	.data_width_g(8)) 
u_ram0(
	.address_a(Ram_Addr[12:0]),
	.clock_a(Clock),
	.data_a(Ram_in),
	.wren_a(~RW_n),
	.q_a(Ram_out),
	
	.address_b(VortexAddr[12:0]),
	.clock_b(Clock),
	.q_b(VortexColour)
	);
endmodule 
