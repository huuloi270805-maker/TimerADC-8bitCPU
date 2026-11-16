`timescale 1ns/1ps
// =============================================================================
// risc8_soc.v - top he thong: CPU RISC-8 5 tang + Timer/ADC
//   * chung clk; reset CPU active-high -> ngoai vi nhan rst_n = ~rst
//   * CPU truy cap ngoai vi qua trang I/O 0xF0..0xFF (cong io_* cua core)
//   * irq, pwm_out va 4 day analog tro thanh chan cua he thong
// =============================================================================
module risc8_soc (
    input  wire       clk,
    input  wire       rst,            // active high (reset cua CPU)
    output wire       halted,
    output wire [7:0] pc_out,
    // ngoai vi
    output wire       irq,
    output wire       pwm_out,
    output wire       adc_sample,
    output wire [1:0] adc_ch,
    output wire [7:0] adc_dac,
    input  wire       adc_cmp
);
    wire       io_cs, io_we;
    wire [3:0] io_addr;
    wire [7:0] io_wdata, io_rdata;

    // ---- CPU ----
    risc8_5stage_core #(
        .IO_ENABLE (1),
        .IO_PAGE   (4'hF)
    ) u_cpu (
        .clk       (clk),
        .rst       (rst),
        .halted    (halted),
        .pc_out    (pc_out),
        .flags_out (),
        .instr_done(),
        .io_cs     (io_cs),
        .io_we     (io_we),
        .io_addr   (io_addr),
        .io_wdata  (io_wdata),
        .io_rdata  (io_rdata)
    );

    // ---- Timer + ADC ----
    timer_adc8_cpu_if u_tadc (
        .clk        (clk),
        .rst_n      (~rst),           // doi cuc tinh reset
        .cs         (io_cs),
        .we         (io_we),
        .addr       (io_addr),
        .wdata      (io_wdata),
        .rdata      (io_rdata),
        .irq        (irq),
        .pwm_out    (pwm_out),
        .adc_sample (adc_sample),
        .adc_ch     (adc_ch),
        .adc_dac    (adc_dac),
        .adc_cmp    (adc_cmp)
    );
endmodule