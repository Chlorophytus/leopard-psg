`timescale 1ns / 1ps
// See LICENSE for licensing details.
module leopard_i2s
   (input logic aclk,
    input logic aresetn,
    input logic signed [15:0] channels_in[3],
    output logic dac_mclk_out,
    output logic dac_lrck_out,
    output logic dac_sclk_out,
    output logic dac_sdata_out);
endmodule: leopard_i2s