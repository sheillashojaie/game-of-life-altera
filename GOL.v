/* Conway's Game of Life developed for the Altera DE2 FPGA Board
 * GOL.v by Thomas Robinson & Sheilla Shojaie
 * March 2014
 */
 
`define VGA_WIDTH 160
`define VGA_HEIGHT 120
`define GRID_HEIGHT 10
`define GRID_WIDTH 10

module GOL(
    input CLOCK_50, // On Board 50 MHz
    input[3:0] KEY, // Push Button[3:0]
    input[17:0] SW, // DPDT Switch[17:0]
    output VGA_CLK, // VGA Clock
    output VGA_HS, // VGA H_SYNC
    output VGA_VS, // VGA V_SYNC
    output VGA_BLANK, // VGA BLANK
    output VGA_SYNC, // VGA SYNC
    output[9:0] VGA_R, // VGA Red[9:0]
    output[9:0] VGA_G, // VGA Green[9:0]
    output[9:0] VGA_B, // VGA Blue[9:0]
    output[7:0] LEDG,
    output[17:0] LEDR);
    
    wire Clock, Reset, X_en, Y_en, Erase, VGA_en;
    reg Draw_start, Draw_done, Animate_done;
    wire[15:0] X, X_out;
    wire[15:0] Y, Y_out;
    wire[2:0] C_out;
    
    assign Clock = CLOCK_50;
    assign Reset = SW[0];
	 assign EN = SW[1];
    assign Animate = SW[2];
    assign Right = ~KEY[0];
    assign Left = ~KEY[1];
	 assign Up = ~KEY[2];
	 assign Down = ~KEY[3];

    
    Datapath(Clock, Reset, Right, Left, Up, Down, EN, X, X_en, Y, Y_en, Erase, X_out, Y_out, C_out, SW[17:0]);
    FSM(Animate, Reset, X_en, Y_en, VGA_en, LEDG[1:0]);
    
    vga_adapter VGA(
            .resetn(1'b1),
            .clock(CLOCK_50),
            .colour(C_out),
            .x(X_out),
            .y(Y_out),
            .plot(VGA_en),
            /* Signals for the DAC to drive the monitor. */
            .VGA_R(VGA_R),
            .VGA_G(VGA_G),
            .VGA_B(VGA_B),
            .VGA_HS(VGA_HS),
            .VGA_VS(VGA_VS),
            .VGA_BLANK(VGA_BLANK),
            .VGA_SYNC(VGA_SYNC),
            .VGA_CLK(VGA_CLK));
        defparam VGA.RESOLUTION = "160x120";
        defparam VGA.MONOCHROME = "FALSE";
        defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
        defparam VGA.BACKGROUND_IMAGE = "display.mif";
endmodule

module Datapath(input Clock, Reset, Right, Left, Up, Down, EN, input[15:0] X, X_en, input[15:0] Y, Y_en, Erase, output reg[15:0] X_out = -1, output reg[15:0] Y_out = 0, output reg[2:0] C_out = 0, input [17:0] SW);
    reg[15:0] address = 0;
    wire Clock_60Hz;
    wire[15:0] X_anm, Y_anm, cursor_X_anm, cursor_Y_anm;
    reg[15:0] X_off, Y_off, cursor_X_off, cursor_Y_off;
    wire[2:0] color, cell_color, cursor_color;
	 reg[(`GRID_HEIGHT*`GRID_WIDTH):0] states;
	 reg [3:0] sum;
	 reg rst = 0;
	 wire[(`GRID_HEIGHT*`GRID_WIDTH):0] states2;
    test(address, Clock, color);
    _60HzClock(Clock, Clock_60Hz);
	 cursor_config(Clock_60Hz, Right, Left, Up, Down, cursor_X_anm, cursor_Y_anm);

    
    always @ (posedge Clock or posedge Reset) 
	 begin
        if (Reset) 
		  begin
            X_off = 0;
            Y_off = 0;
            cursor_X_off = 0;
            cursor_Y_off = 0;
            address = 0;
            X_out = 0;
            Y_out = 0;
            C_out = 0;
        end else 
		  begin            
            X_out = X_out + 1;
            if (X_out == `VGA_WIDTH) 
				begin
                X_out = 0;
                Y_out = Y_out + 1;
                if (Y_out == `VGA_HEIGHT) 
					 begin
                    Y_out = 0;
                end
            end
				
            if (X_en) X_off = X;
            else X_off = X_anm;
            if (Y_en) Y_off = Y;
            else Y_off = Y_anm;
			
            if (X_en) cursor_X_off = X;
            else cursor_X_off = cursor_X_anm;
            if (Y_en) cursor_Y_off = Y;
            else cursor_Y_off = cursor_Y_anm;
				
				if (SW[0]&~SW[1]&~SW[2] )
				begin
				if (Y_out == 0 & X_out != 0 & X_out != `GRID_WIDTH-1) //First Row
				begin
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out+1]) sum = sum +1;
				end
				
				if (Y_out == `GRID_WIDTH - 1 & X_out != 0 & X_out != `GRID_WIDTH-1) //Last Row
				begin
				if (states[`GRID_WIDTH*(Y_out-1) + X_out-1]) sum = sum +1; 
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out-1) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				end
				
				
				if (X_out == 0 & Y_out != 0 & Y_out != `GRID_HEIGHT-1) //First Column
				begin
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out-1) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out+1]) sum = sum +1;
				end
				
				if (X_out == `GRID_HEIGHT-1 & Y_out != 0 & Y_out != `GRID_HEIGHT-1) //Last Column
				begin
				if (states[`GRID_WIDTH*(Y_out-1) + X_out-1]) sum = sum +1; 
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				end
				
				if (X_out == 0 & Y_out == 0) //Top left corner
				begin
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out+1]) sum = sum +1;
				end
				
				if (X_out == `GRID_WIDTH-1 & Y_out == 0) //Top right corner
				begin
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				end
				
				if (X_out == 0 & Y_out == `GRID_HEIGHT-1) //Bottom left corner
				begin 
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out-1) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				end
				
				if (X_out == `GRID_WIDTH-1 & Y_out == `GRID_HEIGHT-1) //Bottom right corner
				begin
				if (states[`GRID_WIDTH*(Y_out-1) + X_out-1]) sum = sum +1; 
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				end
				
				if (X_out != `GRID_HEIGHT -1 & X_out != 0 & Y_out != `GRID_WIDTH -1 & Y_out != 0)
				begin
				if (states[`GRID_WIDTH*(Y_out-1) + X_out-1]) sum = sum +1; 
				if (states[`GRID_WIDTH*(Y_out-1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out-1) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out) + X_out+1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out-1]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out]) sum = sum +1;
				if (states[`GRID_WIDTH*(Y_out+1) + X_out+1]) sum = sum +1;
				end
				
				states = states2;
			
				if (states2[(`GRID_WIDTH*(Y_out)) + (X_out)]) //cell is alive
				begin
				C_out = 3'b111;
				end
				
				else //cell is dead
				begin
				C_out = 3'b000;
				end
				
				end
				
				else
				begin
				if (SW[2] & ~SW[1])
				begin
				states[(`GRID_WIDTH*(cursor_Y_off)) + (cursor_X_off)] = 1;
				end
				
				if (SW[1] & ~SW[2])
				begin
				states[(`GRID_WIDTH*(cursor_Y_off)) + (cursor_X_off)] = 0;
				end
				//end
				if (states[(`GRID_WIDTH*(Y_out)) + (X_out)])
				begin
				C_out = SW[17:15];
				end
				if ((X_out == cursor_X_off)&(Y_out == cursor_Y_off))
				begin
            
                C_out = SW[14:12];
            end
							
				//code here
				
				if (~states[(`GRID_WIDTH*(Y_out)) + (X_out)] & ~((X_out == cursor_X_off)&(Y_out == cursor_Y_off)))
				begin
                C_out = SW[11:8];
            end
        end
    end
	 end
endmodule

module cursor_config(input Clock, Right, Left, Up, Down, output reg[15:0] X_anm = 0, output reg[15:0] Y_anm = 0);
	always @ (posedge Clock)
		begin
			if(Left)
				if (X_anm > 1) X_anm = X_anm - 1;
		
			if(Right)
				if (X_anm < `GRID_WIDTH) X_anm = X_anm + 1;
			
			if(Up)
				if (Y_anm > 1) Y_anm = Y_anm - 1;
			
			if(Down)
				if (Y_anm < `GRID_HEIGHT) Y_anm = Y_anm + 1;
		
		end
endmodule

module count_neighbours (neighbours,sum);
    input [7:0] neighbours;
    output [3:0] sum;
 
    wire [3:0] sum;
 
    assign sum = neighbours[7] + 
                 neighbours[6] +
                 neighbours[5] +
                 neighbours[4] +
                 neighbours[3] +
                 neighbours[2] +
                 neighbours[1] +
                 neighbours[0];
endmodule
 
module rules (pop_count, current_state, next_state);
    input [3:0] pop_count;
    input current_state;
    output next_state;
    wire next_state;
 
    assign next_state = (pop_count == 2 & current_state) | pop_count == 3;
endmodule    	
 
module gol_cell( pop, clk, rst, seed, state);
    input clk;
    input rst;
    input seed;
    output state;
 
    input [3:0] pop;
    wire next_state;
 
    reg state;
 
    rules r(pop, state, next_state);
 
    always @(posedge clk or negedge rst) begin
        if(~rst) begin
            state = seed;
        end else begin
            state = next_state;
        end
    end
endmodule



module FSM(input Animate, Reset, output reg X_en, Y_en, VGA_en, output reg[2:0] y);
    //FSM states
    parameter IDLE = 3;
    reg Draw_start = 0, Draw_done = 0, Animate_start = 0;
    //Current FSM state
    reg[2:0] Y;
    
    always @ (*) 
	 begin
        Animate_start = Animate & ~Animate_start;
        
        VGA_en = (y != IDLE);       

        Animate_start = 0;
    end
endmodule

module _60HzClock(input Clock, output reg EN = 0);
    //20 bits required to store largest cnt value (833333)
    reg[19:0] cnt = 0;
    always @ (posedge Clock) 
	 begin
        cnt = cnt + 1;
        //83333 clock cycles is 60 Hz
        if (cnt == 833333) 
		  begin
            cnt = 0;
            EN = ~EN;
        end
    end
endmodule


	