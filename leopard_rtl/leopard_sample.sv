`timescale 1ns / 1ps
// See LICENSE for licensing details.
module leopard_sample
   (input logic aclk,
    input logic aresetn,

    // Must be in the clock domain!
    input logic sample_clk,

    input logic sample_gate,
    input logic wavetable_wen,    
    input logic unsigned [7:0] controls_wen,
    input logic unsigned [7:0] controls,
    output logic signed [15:0] sample_out);
    // Wavetable data
    logic signed [7:0] r_wavetable[4096] = '{default:{8'h00}};
    // Where the wavetable pointer is currently at
    logic unsigned [11:0] r_wavetable_wptr = 12'h000;
    logic unsigned [11:0] r_wavetable_rptr = 12'h000;

    logic unsigned [7:0] r_pitch = 8'h00;
    logic unsigned [7:0] r_pitch_cnt = 8'h00;
    logic unsigned [3:0] r_octave = 4'h0;
    logic unsigned [7:0] r_volume = 8'h00;
    logic unsigned [4:0] r_octave_outs = 5'h00;

    logic signed [15:0] r_sample_out = 16'h0000;

    logic r_octave_setout = 1'b0;
    /** CONTROL:
        > 8'b0000_0000 nothing is controlled
        > 8'b0000_0001 sampleram write address bits 12'hB to 12'h8 is controlled, and octave is 4 MSBs
        > 8'b0000_0010 sampleram write address bits 12'h7 to 12'h0 is controlled
        > 8'b0000_0100 pitch is controlled
        > 8'b0000_1000 volume is controlled
        > 8'b0001_0000 nothing is controlled
        > 8'b0010_0000 nothing is controlled
        > 8'b0100_0000 nothing is controlled
        > 8'b1000_0000 nothing is controlled
    */

    // Control wavetable writing pointer segments
    always_ff@(posedge aclk or negedge aresetn) begin: sample_control_waveptr1
        if(~aresetn)
            r_wavetable_wptr[11:8] <= 4'h0;
        else if(controls_wen[0])
            r_wavetable_wptr[11:8] <= controls[3:0];
    end: sample_control_waveptr1
    always_ff@(posedge aclk or negedge aresetn) begin: sample_control_waveptr0
        if(~aresetn)
            r_wavetable_wptr[7:0] <= 8'h00;
        else if(controls_wen[1])
            r_wavetable_wptr[7:0] <= controls;
    end: sample_control_waveptr0
    
    // Control octave
    always_ff@(posedge aclk or negedge aresetn) begin: sample_control_octaves
        if(~aresetn)
            r_octave <= 4'h0;
        else if(controls_wen[0])
            r_octave <= controls[7:4];
    end: sample_control_octaves

    // Control pitch
    always_ff@(posedge aclk or negedge aresetn) begin: sample_control_pitch
        if(~aresetn)
            r_pitch <= 8'h00;
        else if(controls_wen[2])
            r_pitch <= controls;
    end: sample_control_pitch

    // Control volume
    always_ff@(posedge aclk or negedge aresetn) begin: sample_control_volume
        if(~aresetn)
            r_volume <= 8'h00;
        else if(controls_wen[3])
            r_volume <= controls;
    end: sample_control_volume

    always_ff@(posedge sample_clk or negedge aresetn or edge sample_gate) begin: sample_playback
        if(~aresetn | ~sample_gate)
            r_sample_out <= 16'h0000;
        else if(~|controls_wen & ~wavetable_wen)
            casez(r_volume)
                8'b0000_0000: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 8'b0000_0000, r_wavetable[r_wavetable_rptr][6:0]};
                8'b0000_0001: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 7'b000_0000, r_wavetable[r_wavetable_rptr][6:0], 1'b0};
                8'b0000_001z: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 6'b00_0000, r_wavetable[r_wavetable_rptr][6:0], 2'b00};
                8'b0000_01zz: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 5'b0_0000, r_wavetable[r_wavetable_rptr][6:0], 3'b000};
                8'b0000_1zzz: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 4'b0000, r_wavetable[r_wavetable_rptr][6:0],  4'b0000};
                8'b0001_zzzz: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 3'b000, r_wavetable[r_wavetable_rptr][6:0], 5'b0_0000};
                8'b001z_zzzz: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 2'b00, r_wavetable[r_wavetable_rptr][6:0], 6'b00_0000};
                8'b01zz_zzzz: r_sample_out <= {r_wavetable[r_wavetable_rptr][7], 1'b0, r_wavetable[r_wavetable_rptr][6:0], 7'b000_0000};
                8'b1zzz_zzzz: r_sample_out <= {r_wavetable[r_wavetable_rptr], 8'b0000_0000};
            endcase
    end: sample_playback

    always_ff@(posedge r_octave_setout or negedge aresetn) begin: sample_wavetable_incptr
        if(~aresetn)
            r_wavetable_rptr <= 12'h000;
        else if(~|controls_wen & ~wavetable_wen)
            r_wavetable_rptr <= r_wavetable_rptr + 12'h001;
    end: sample_wavetable_incptr

    always_ff@(posedge aclk or negedge aresetn) begin: sample_wavetable
        if(~aresetn)
            r_wavetable <= '{default:{8'h00}};
        else if(wavetable_wen)
            r_wavetable[r_wavetable_wptr] <= controls;
    end: sample_wavetable

    // Divide octaves
    assign r_octave_outs[0] = sample_clk;
    for(genvar i = 1; i < 5; i++) begin: sample_octave_gen
        leopard_divide divide_octave(.aresetn(aresetn), .aclk(r_octave_outs[i - 1]), .state(r_octave_outs[i]));
    end: sample_octave_gen
    always_ff@(posedge aclk or negedge aresetn) begin: sample_octave_setout
        if(~aresetn)
            r_octave_setout <= 1'b0;
        else casez(r_octave)
            4'b0000: r_octave_setout <= r_octave_outs[0];
            4'b0001: r_octave_setout <= r_octave_outs[1];
            4'b001z: r_octave_setout <= r_octave_outs[2];
            4'b01zz: r_octave_setout <= r_octave_outs[3];
            4'b1zzz: r_octave_setout <= r_octave_outs[4];
        endcase
    end: sample_octave_setout
endmodule: leopard_sample