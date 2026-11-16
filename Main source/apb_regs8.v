`timescale 1ns/1ps
// =============================================================================
// apb_regs8.v - the 16 registers, read mux, interrupt flags, irq
//
//  0x0 TMR_CTRL   RW   [0] EN  [1] ONESHOT
//  0x1 TMR_PRESC  RW   tick every PRESC+1 clocks
//  0x2 TMR_LOAD   RW   reset 0xFF
//  0x3 TMR_CMP    RW   reset 0x80
//  0x4 TMR_CNT    RO
//  0x5 ADC_CTRL   RW   [0] EN [1] START (reads 0) [3:2] TRIG_SEL [5:4] CH
//  0x6 ADC_SMP    RW   reset 0x04
//  0x7 ADC_DIV    RW
//  0x8 ADC_THR_LO RW   reset 0x00
//  0x9 ADC_THR_HI RW   reset 0xFF
//  0xA ADC_DATA   RO   oldest FIFO result, a READ POPS the FIFO
//  0xB ADC_RCH    RO   [7] VALID  [1:0] CH of oldest entry (no pop)
//  0xC ADC_STAT   RO   [3:0] LEVEL [4] EMPTY [5] FULL [6] BUSY   reset 0x10
//  0xD IRQ_EN     RW   [5:0]
//  0xE IRQ_STAT   W1C  [0] TMR_OVF [1] TMR_CMP [2] ADC_EOC [3] ADC_WD
//                      [4] FIFO_OVR [5] TRIG_MISS
//  0xF ID         RO   0xA8
//
// One access = one clock: (psel & penable) is high for exactly one clock.
// prdata is combinational and is 0 when no read is in progress.
// A flag set by hardware in the same clock as a W1C write stays set.
// =============================================================================
module apb_regs8 (
    input  wire       clk,
    input  wire       rst_n,
    // bus
    input  wire       psel,
    input  wire       penable,
    input  wire       pwrite,
    input  wire [3:0] paddr,
    input  wire [7:0] pwdata,
    output reg  [7:0] prdata,
    // timer
    output wire       tmr_en,
    output wire       tmr_oneshot,
    output wire [7:0] tmr_presc,
    output wire [7:0] tmr_load,
    output wire [7:0] tmr_cmp,
    input  wire [7:0] tmr_cnt,
    input  wire       ev_ovf,
    input  wire       ev_cmp,
    input  wire       tmr_done,
    // ADC
    output wire       adc_en,
    output reg        adc_start,
    output wire [1:0] adc_trig_sel,
    output wire [1:0] adc_ch,
    output wire [7:0] adc_smp,
    output wire [7:0] adc_div,
    input  wire       adc_busy,
    input  wire       adc_eoc,
    input  wire [7:0] adc_result,
    input  wire       adc_trig_miss,
    // FIFO
    output wire       fifo_pop,
    input  wire [9:0] fifo_dout,      // {ch[1:0], data[7:0]}
    input  wire [3:0] fifo_level,
    input  wire       fifo_empty,
    input  wire       fifo_full,
    input  wire       fifo_ovf,
    // interrupt
    output wire       irq
);
    localparam [3:0] A_TMR_CTRL = 4'h0, A_TMR_PRESC = 4'h1, A_TMR_LOAD = 4'h2,
                     A_TMR_CMP  = 4'h3, A_TMR_CNT   = 4'h4, A_ADC_CTRL = 4'h5,
                     A_ADC_SMP  = 4'h6, A_ADC_DIV   = 4'h7, A_THR_LO    = 4'h8,
                     A_THR_HI   = 4'h9, A_ADC_DATA  = 4'hA, A_ADC_RCH   = 4'hB,
                     A_ADC_STAT = 4'hC, A_IRQ_EN    = 4'hD, A_IRQ_STAT  = 4'hE,
                     A_ID       = 4'hF;

    wire acc = psel & penable;
    wire wr  = acc &  pwrite;
    wire rd  = acc & ~pwrite;

    reg [1:0] r_tmr_ctrl;      // [0] EN [1] ONESHOT
    reg [7:0] r_presc, r_load, r_cmp;
    reg       r_adc_en;
    reg [1:0] r_trig_sel, r_ch;
    reg [7:0] r_smp, r_div, r_thr_lo, r_thr_hi;
    reg [5:0] r_irq_en, r_irq_stat;

    assign tmr_en       = r_tmr_ctrl[0];
    assign tmr_oneshot  = r_tmr_ctrl[1];
    assign tmr_presc    = r_presc;
    assign tmr_load     = r_load;
    assign tmr_cmp      = r_cmp;
    assign adc_en       = r_adc_en;
    assign adc_trig_sel = r_trig_sel;
    assign adc_ch       = r_ch;
    assign adc_smp      = r_smp;
    assign adc_div      = r_div;

    // reading ADC_DATA pops the FIFO (exactly one pop per LD)
    assign fifo_pop = rd & (paddr == A_ADC_DATA);

    // window comparator on every new result
    wire wd_hit = (adc_result < r_thr_lo) | (adc_result > r_thr_hi);

    // hardware flag set
    wire [5:0] flag_set = { adc_trig_miss,            // [5] TRIG_MISS
                            fifo_ovf,                 // [4] FIFO_OVR
                            adc_eoc & wd_hit,         // [3] ADC_WD
                            adc_eoc,                  // [2] ADC_EOC
                            ev_cmp,                   // [1] TMR_CMP
                            ev_ovf };                 // [0] TMR_OVF
    wire [5:0] flag_clr = (wr & (paddr == A_IRQ_STAT)) ? pwdata[5:0] : 6'h00;

    assign irq = |(r_irq_stat & r_irq_en);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_tmr_ctrl <= 2'b00;
            r_presc    <= 8'h00;
            r_load     <= 8'hFF;
            r_cmp      <= 8'h80;
            r_adc_en   <= 1'b0;
            r_trig_sel <= 2'b00;
            r_ch       <= 2'b00;
            r_smp      <= 8'h04;
            r_div      <= 8'h00;
            r_thr_lo   <= 8'h00;
            r_thr_hi   <= 8'hFF;
            r_irq_en   <= 6'h00;
            r_irq_stat <= 6'h00;
            adc_start  <= 1'b0;
        end else begin
            adc_start <= 1'b0;
            // one-shot timer finished: hardware clears EN
            if (tmr_done) r_tmr_ctrl[0] <= 1'b0;
            if (wr) begin
                case (paddr)
                A_TMR_CTRL: begin
                    r_tmr_ctrl[1] <= pwdata[1];
                    if (!tmr_done) r_tmr_ctrl[0] <= pwdata[0];
                end
                A_TMR_PRESC: r_presc <= pwdata;
                A_TMR_LOAD : r_load  <= pwdata;
                A_TMR_CMP  : r_cmp   <= pwdata;
                A_ADC_CTRL : begin
                    r_adc_en   <= pwdata[0];
                    adc_start  <= pwdata[1];      // pulse, not stored
                    r_trig_sel <= pwdata[3:2];
                    r_ch       <= pwdata[5:4];
                end
                A_ADC_SMP  : r_smp    <= pwdata;
                A_ADC_DIV  : r_div    <= pwdata;
                A_THR_LO   : r_thr_lo <= pwdata;
                A_THR_HI   : r_thr_hi <= pwdata;
                A_IRQ_EN   : r_irq_en <= pwdata[5:0];
                default: ;
                endcase
            end
            // sticky flags: set wins over clear
            r_irq_stat <= (r_irq_stat & ~flag_clr) | flag_set;
        end
    end

    // read mux (0 when not reading)
    always @* begin
        prdata = 8'h00;
        if (rd) begin
            case (paddr)
            A_TMR_CTRL : prdata = {6'b0, r_tmr_ctrl};
            A_TMR_PRESC: prdata = r_presc;
            A_TMR_LOAD : prdata = r_load;
            A_TMR_CMP  : prdata = r_cmp;
            A_TMR_CNT  : prdata = tmr_cnt;
            A_ADC_CTRL : prdata = {2'b0, r_ch, r_trig_sel, 1'b0, r_adc_en}; // START reads 0
            A_ADC_SMP  : prdata = r_smp;
            A_ADC_DIV  : prdata = r_div;
            A_THR_LO   : prdata = r_thr_lo;
            A_THR_HI   : prdata = r_thr_hi;
            A_ADC_DATA : prdata = fifo_dout[7:0];
            A_ADC_RCH  : prdata = {~fifo_empty, 5'b0, fifo_dout[9:8]};
            A_ADC_STAT : prdata = {1'b0, adc_busy, fifo_full, fifo_empty, fifo_level};
            A_IRQ_EN   : prdata = {2'b0, r_irq_en};
            A_IRQ_STAT : prdata = {2'b0, r_irq_stat};
            A_ID       : prdata = 8'hA8;
            default    : prdata = 8'h00;
            endcase
        end
    end
endmodule
