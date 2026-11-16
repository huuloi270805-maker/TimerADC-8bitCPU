`timescale 1ns/1ps
// =============================================================================
// timer_adc8_top.v - wires timer8, sar_adc_ctrl, sync_fifo and apb_regs8
// =============================================================================
module timer_adc8_top (
    input  wire       clk,
    input  wire       rst_n,
    // APB-like register port (psel & penable high for one clock per access)
    input  wire       psel,
    input  wire       penable,
    input  wire       pwrite,
    input  wire [3:0] paddr,
    input  wire [7:0] pwdata,
    output wire [7:0] prdata,
    // outputs
    output wire       irq,
    output wire       pwm_out,
    // analog front end
    output wire       adc_sample,
    output wire [1:0] adc_ch,
    output wire [7:0] adc_dac,
    input  wire       adc_cmp
);
    // timer <-> regs
    wire       tmr_en, tmr_oneshot, ev_ovf, ev_cmp, tmr_done;
    wire [7:0] tmr_presc, tmr_load, tmr_cmp, tmr_cnt;
    // adc <-> regs
    wire       adc_en, adc_start, adc_busy, adc_eoc, adc_trig_miss;
    wire [1:0] adc_trig_sel, ctrl_ch, res_ch;
    wire [7:0] adc_smp, adc_div, adc_result;
    // fifo <-> regs
    wire       fifo_pop, fifo_empty, fifo_full, fifo_ovf;
    wire [9:0] fifo_dout;
    wire [3:0] fifo_level;

    // ---- CALL: apb_regs8 -------------------------------------------------
    apb_regs8 u_regs (
        .clk(clk), .rst_n(rst_n),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
        .tmr_en(tmr_en), .tmr_oneshot(tmr_oneshot), .tmr_presc(tmr_presc),
        .tmr_load(tmr_load), .tmr_cmp(tmr_cmp), .tmr_cnt(tmr_cnt),
        .ev_ovf(ev_ovf), .ev_cmp(ev_cmp), .tmr_done(tmr_done),
        .adc_en(adc_en), .adc_start(adc_start), .adc_trig_sel(adc_trig_sel),
        .adc_ch(ctrl_ch), .adc_smp(adc_smp), .adc_div(adc_div),
        .adc_busy(adc_busy), .adc_eoc(adc_eoc), .adc_result(adc_result),
        .adc_trig_miss(adc_trig_miss),
        .fifo_pop(fifo_pop), .fifo_dout(fifo_dout), .fifo_level(fifo_level),
        .fifo_empty(fifo_empty), .fifo_full(fifo_full), .fifo_ovf(fifo_ovf),
        .irq(irq)
    );

    // ---- CALL: timer8 ----------------------------------------------------
    timer8 u_timer (
        .clk(clk), .rst_n(rst_n),
        .en(tmr_en), .oneshot(tmr_oneshot),
        .presc(tmr_presc), .load(tmr_load), .cmp(tmr_cmp),
        .cnt(tmr_cnt), .ovf_pulse(ev_ovf), .cmp_pulse(ev_cmp),
        .done(tmr_done), .pwm(pwm_out)
    );

    // ---- CALL: sar_adc_ctrl ---------------------------------------------
    sar_adc_ctrl u_adc (
        .clk(clk), .rst_n(rst_n),
        .en(adc_en), .start(adc_start), .trig_sel(adc_trig_sel),
        .trig_ovf(ev_ovf), .trig_cmp(ev_cmp),
        .ch(ctrl_ch), .smp(adc_smp), .div(adc_div),
        .sample(adc_sample), .adc_ch(adc_ch), .dac(adc_dac), .cmp(adc_cmp),
        .busy(adc_busy), .eoc(adc_eoc), .result(adc_result),
        .res_ch(res_ch), .trig_miss(adc_trig_miss)
    );

    // ---- CALL: sync_fifo (8 x {ch, data}) --------------------------------
    sync_fifo #(.WIDTH(10), .AW(3)) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .push(adc_eoc), .din({res_ch, adc_result}),
        .pop(fifo_pop), .dout(fifo_dout),
        .level(fifo_level), .empty(fifo_empty), .full(fifo_full),
        .overflow(fifo_ovf)
    );
endmodule
