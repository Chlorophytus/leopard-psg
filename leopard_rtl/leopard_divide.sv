`timescale 1ns / 1ps
// See LICENSE for licensing details.
module leopard_divide
   (input logic aclk,
    input logic aresetn,
    output logic state);
    // assign state register, temporary
    logic r_state = 1'b0;
    always_ff@(posedge aclk or negedge aresetn) begin: leopard_divide_clk
        if(~aresetn)
            r_state <= 1'b0;
        else
            r_state <= ~r_state;
    end: leopard_divide_clk
    // then send off
    assign state = r_state;
endmodule: leopard_divide