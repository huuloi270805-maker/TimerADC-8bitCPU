`timescale 1ns/1ps
// =============================================================================
// timer_adc8_cpu_if.v - wrapper that makes the peripheral look like a simple
// one-clock CPU bus:  cs, we, addr[3:0], wdata[7:0]  ->  rdata[7:0]
//   * one access = one clock, no wait states
//   * rdata is 0 when cs = 0  (can be OR-ed with other devices)
//   * cs must be high for exactly ONE clock per LD / ST (a read of ADC_DATA
//     pops the FIFO)
// =============================================================================
module timer_adc8_cpu_if (
    input  wire       clk,
    input  wire       rst_n,        // active low (CPU: rst_n = ~rst)
    input  wire       cs,
    input  wire       we,
    input  wire [3:0] addr,
    input  wire [7:0] wdata,
    output wire [7:0] rdata,
    output wire       irq,
    output wire       pwm_out,
    output wire       adc_sample,
    output wire [1:0] adc_ch,
    output wire [7:0] adc_dac,
    input  wire       adc_cmp
);
    // ---- CALL: timer_adc8_top -------------------------------------------
    timer_adc8_top u_periph (
        .clk(clk), .rst_n(rst_n),
        .psel(cs), .penable(cs), .pwrite(we),
        .paddr(addr), .pwdata(wdata), .prdata(rdata),
        .irq(irq), .pwm_out(pwm_out),
        .adc_sample(adc_sample), .adc_ch(adc_ch),
        .adc_dac(adc_dac), .adc_cmp(adc_cmp)
    );
endmodule
