
module invaders_memory(
input            Clock,
input            RW_n,
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
input            mod_vortex

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

wire [7:0]rom_data;
wire [7:0]rom2_data;

wire [15:0]rom_addr_vortex = {Addr[15:10],~Addr[9],Addr[8:4],~Addr[3],Addr[2:1],~Addr[0]};
wire [15:0] rom_addr = mod_vortex? rom_addr_vortex : Addr;


wire rom_cs  = dn_wr & dn_addr[15:13]==3'b000;

// 0010 0000 0000 0000
wire rom2_cs = dn_wr & dn_addr[15:13]==3'b001;
// 0100 0000 0000 0000
// 0100 0100 0000 0000
wire vrom_cs = dn_wr & dn_addr[15:11]==5'b01000;

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
dpram #(.addr_width_g(11),
	.data_width_g(8))
video_rom(
	.clock_a(Clock),
	.wren_a(vrom_cs),
	.address_a(dn_addr[10:0]),
	.data_a(dn_data),

	.clock_b(Clock),
	.address_b(color_prom_addr),
	.q_b(color_prom_out)
);


	
always @(Addr, rom_data, rom2_data) begin
	
	Rom_out = 8'b00000000;
		case (Addr[15:11])
			5'b00000 : Rom_out = rom_data;
			5'b00001 : Rom_out = rom_data;
			5'b00010 : Rom_out = rom_data;
			5'b00011 : Rom_out = rom_data;
			
			5'b01000 : Rom_out = rom2_data;
			5'b01001 : Rom_out = rom2_data;
			5'b01010 : Rom_out = rom2_data;
			5'b01011 : Rom_out = rom2_data;
			default : Rom_out = 8'b00000000;
		endcase
end
		
spram #(
	.addr_width_g(13),
	.data_width_g(8)) 
u_ram0(
	.address(Ram_Addr[12:0]),
	.clken(1'b1),
	.clock(Clock),
	.data(Ram_in),
	.wren(~RW_n),
	.q(Ram_out)
	);
endmodule 
