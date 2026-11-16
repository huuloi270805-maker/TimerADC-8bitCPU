`timescale 1ns/1ps
// =============================================================================
// tb_risc8_soc.v - testbench cap he thong: CPU RISC-8 + Timer/ADC (22 checks)
// Chay firmware soc_demo.s (phan A..F) va kiem tra RAM 0x80..0x91, chan irq, PWM.
// Dien ap analog: ch0 = 0.40 V, ch1 = 1.111 V, ch2 = 2.0 V, ch3 = 3.0 V
// =============================================================================
module tb_risc8_soc;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    wire       halted, irq, pwm_out, adc_sample, adc_cmp;
    wire [7:0] pc_out, adc_dac;
    wire [1:0] adc_ch;

    risc8_soc dut (.clk(clk), .rst(rst), .halted(halted), .pc_out(pc_out),
        .irq(irq), .pwm_out(pwm_out), .adc_sample(adc_sample), .adc_ch(adc_ch),
        .adc_dac(adc_dac), .adc_cmp(adc_cmp));

    // ---- Mach analog gia (ngoai thiet ke so, chi de mo phong) ----
    real vin [0:3];
    real vhold, vdac;
    always @(negedge adc_sample) vhold = vin[adc_ch];
    always @(adc_dac) vdac = adc_dac * 3.3 / 256.0;
    assign adc_cmp = (vhold >= vdac);

    // ---- thong ke ----
    integer io_acc = 0, cyc = 0;
    reg irq_seen = 0;
    always @(posedge clk) begin
        cyc = cyc + 1;
        if (dut.io_cs) io_acc = io_acc + 1;
        if (irq) irq_seen = 1;
    end

    integer errors = 0, checks = 0, hi, i;
    task chk(input [1279:0] name, input integer got, input integer exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL: %0s  got=0x%0h expected=0x%0h", name, got, exp);
            end else
                $display("PASS: %0s = 0x%0h", name, got);
        end
    endtask
    task mem(input [7:0] a, input [7:0] exp, input [1279:0] name);
        begin chk(name, dut.u_cpu.memory_data.ram[a], exp); end
    endtask

    initial begin
        vin[0] = 0.40; vin[1] = 1.111; vin[2] = 2.0; vin[3] = 3.0;
        repeat (4) @(posedge clk); #1 rst = 0;

        i = 0;
        while (!halted && i < 20000) begin @(posedge clk); i = i + 1; end
        $display("CPU halted after %0d cycles, %0d I/O accesses", cyc, io_acc);
        chk("CPU halted (HLT da ra khoi pipeline)", halted, 1);
        if (io_acc == 0)
            $display("!!! 0 truy cap I/O: CPU khong chay soc_demo.s - kiem tra file .hex nap vao imem");

        mem(8'h80, 8'hA8, "MEM[80] ID register");
        mem(8'h81, 8'h81, "MEM[81] B: ADC_RCH = valid, ch1");
        mem(8'h82, 8'h56, "MEM[82] B: ch1 code (1.111 V)");
        mem(8'h83, 8'h82, "MEM[83] C: ADC_RCH = valid, ch2");
        mem(8'h84, 8'h9B, "MEM[84] C: ch2 code (2.0 V), timer start");
        mem(8'h85, 8'h82, "MEM[85] C: ADC_RCH = valid, ch2");
        mem(8'h86, 8'h9B, "MEM[86] C: ch2 code (2.0 V)");
        mem(8'h87, 8'h82, "MEM[87] C: ADC_RCH = valid, ch2");
        mem(8'h88, 8'h9B, "MEM[88] C: ch2 code (2.0 V)");
        mem(8'h89, 8'h82, "MEM[89] C: ADC_RCH = valid, ch2");
        mem(8'h8A, 8'h9B, "MEM[8a] C: ch2 code (2.0 V)");
        mem(8'h8B, 8'h07, "MEM[8b] C: IRQ_STAT = OVF|CMP|EOC");
        mem(8'h8C, 8'h03, "MEM[8c] C: IRQ_STAT after W1C 0x04");
        mem(8'h8D, 8'h0C, "MEM[8d] D: IRQ_STAT = EOC|WD");
        mem(8'h8E, 8'hE8, "MEM[8e] D: ch3 code (3.0 V)");
        mem(8'h8F, 8'h1F, "MEM[8f] F: 1st pop, ch0 code (0.40 V)");
        mem(8'h90, 8'h56, "MEM[90] F: 2nd pop, ch1 code (1.111 V)");
        mem(8'h91, 8'h10, "MEM[91] F: ADC_STAT = empty after 2 pops");
        chk("irq pin went high during part D", irq_seen, 1);
        chk("irq pin cleared after acknowledge", irq, 0);

        hi = 0; repeat (100) begin @(posedge clk); if (pwm_out) hi = hi + 1; end
        chk("PWM high for 30 of 100 clocks", hi, 30);

        $display("--------------------------------------------------");
        if (errors == 0) $display("*** SOC TEST PASSED *** (%0d checks)", checks);
        else             $display("*** SOC TEST FAILED: %0d / %0d checks ***", errors, checks);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #100_000_000; $display("TIMEOUT"); $finish; end
endmodule