`timescale 1ns/1ps
// =============================================================================
// sar_adc_ctrl.v - 8-bit SAR ADC controller (digital part only)
//
//   IDLE -> SAMPLE (SMP+1 ticks) -> CONVERT (8 ticks, MSB first) -> IDLE+EOC
//   tick = one every DIV+1 clocks
//   busy lasts (SMP+1+8)*(DIV+1) clocks (min 9); 'eoc' is a 1-clock pulse in
//   the first clock after busy falls, 'result' is valid at that time.
//
//   Analog part (outside, see sv/sar_afe_model.sv):
//     adc_sample = 1 : sample & hold tracks channel adc_ch ; falling edge = hold
//     adc_dac    = guess code ; adc_cmp = 1 when  Vheld >= DAC(adc_dac)
//
//   Start sources (ADC_CTRL.TRIG_SEL): 0 software START, 1 timer overflow,
//   2 timer compare, 3 continuous.  Software START always works.
//   A start request while busy only raises 'trig_miss'.
//   en = 0 aborts the conversion (no result, no eoc).
// =============================================================================
module sar_adc_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire       start,        // software START (1-clock pulse)
    input  wire [1:0] trig_sel,
    input  wire       trig_ovf,     // timer overflow pulse
    input  wire       trig_cmp,     // timer compare pulse
    input  wire [1:0] ch,           // channel requested by ADC_CTRL.CH
    input  wire [7:0] smp,          // sample window - 1   (ticks)
    input  wire [7:0] div,          // clock divider - 1
    // analog front end
    output reg        sample,
    output wire [1:0] adc_ch,
    output reg  [7:0] dac,
    input  wire       cmp,
    // result
    output wire       busy,
    output reg        eoc,
    output reg  [7:0] result,
    output reg  [1:0] res_ch,
    output reg        trig_miss
);
    localparam [1:0] IDLE = 2'd0, SAMPLE = 2'd1, CONVERT = 2'd2;

    reg [1:0] state;
    reg [1:0] ch_l;
    reg [7:0] smp_l, div_l;
    reg [7:0] dcnt;                // clock divider counter
    reg [7:0] scnt;                // sample tick counter
    reg [7:0] acc;                 // bits decided so far
    reg [7:0] mask;                // bit being tested (one-hot)

    wire tick  = (dcnt == div_l);
    wire req   = start
               | ((trig_sel == 2'd1) & trig_ovf)
               | ((trig_sel == 2'd2) & trig_cmp);
    wire cont  = (trig_sel == 2'd3);
    wire go    = en & (req | cont);

    assign busy   = (state != IDLE);
    assign adc_ch = busy ? ch_l : ch;

    wire [7:0] acc_n = cmp ? dac : acc;   // keep the guessed bit if cmp = 1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            ch_l      <= 2'd0;
            smp_l     <= 8'd0;
            div_l     <= 8'd0;
            dcnt      <= 8'd0;
            scnt      <= 8'd0;
            acc       <= 8'd0;
            mask      <= 8'd0;
            sample    <= 1'b0;
            dac       <= 8'd0;
            eoc       <= 1'b0;
            result    <= 8'd0;
            res_ch    <= 2'd0;
            trig_miss <= 1'b0;
        end else begin
            eoc       <= 1'b0;
            // trigger arrives while a conversion is running -> missed
            trig_miss <= en & busy & (start
                              | ((trig_sel == 2'd1) & trig_ovf)
                              | ((trig_sel == 2'd2) & trig_cmp));

            if (!en) begin                         // abort
                state  <= IDLE;
                sample <= 1'b0;
                dac    <= 8'd0;
                dcnt   <= 8'd0;
            end else begin
                case (state)
                IDLE: begin
                    dcnt <= 8'd0;
                    if (go) begin
                        ch_l   <= ch;
                        smp_l  <= smp;
                        div_l  <= div;
                        scnt   <= 8'd0;
                        acc    <= 8'd0;
                        sample <= 1'b1;
                        state  <= SAMPLE;
                    end
                end
                SAMPLE: begin
                    dcnt <= tick ? 8'd0 : dcnt + 8'd1;
                    if (tick) begin
                        if (scnt == smp_l) begin   // last sample tick: hold + 1st guess
                            sample <= 1'b0;
                            dac    <= 8'h80;
                            mask   <= 8'h80;
                            state  <= CONVERT;
                        end else begin
                            scnt <= scnt + 8'd1;
                        end
                    end
                end
                CONVERT: begin
                    dcnt <= tick ? 8'd0 : dcnt + 8'd1;
                    if (tick) begin
                        if (mask == 8'h01) begin   // last bit decided
                            result <= acc_n;
                            res_ch <= ch_l;
                            eoc    <= 1'b1;
                            dac    <= 8'd0;
                            state  <= IDLE;
                        end else begin
                            acc  <= acc_n;
                            mask <= mask >> 1;
                            dac  <= acc_n | (mask >> 1);
                        end
                    end
                end
                default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
