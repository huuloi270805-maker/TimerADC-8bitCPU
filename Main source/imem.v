// =============================================================================
// imem.v - bo nho lenh 256 x 16 bit
//   HEX_FILE = ""                : dung chuong trinh test co san ben duoi (nhu cu)
//   HEX_FILE = "duong/dan"   : nap chuong trinh tu file .hex (moi dong 1 lenh,
//                            4 chu so hex), dung dau "/" trong duong dan
// Cach dung: sua dong parameter ngay duoi day, hoac ghi de tu ben ngoai
// bang defparam / tham so khi khoi tao imem.
// =============================================================================
module imem #(
    parameter HEX_FILE = "C:/Users/LENOVO/ADCtimerCPU/soc_demo.hex"
) (
    input  wire [7:0]  pc,
    output wire [15:0] inst
);
    reg [15:0] rom [255:0];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 16'h0000;
        end

        if (HEX_FILE != "") begin
            $readmemh(HEX_FILE, rom);
        end else begin
            // ---------- chuong trinh test goc (giu nguyen) ----------
            // 1. Test Cờ Z & C, Rẽ nhánh BZ
            rom[0]  = 16'h810A; // LDI R1, 0x0A  (R1 = 10)
            rom[1]  = 16'h820A; // LDI R2, 0x0A  (R2 = 10)
            rom[2]  = 16'h2312; // SUB R3, R1, R2  (R3 = 0, Z = 1)
            rom[3]  = 16'hD006; // BZ  0x06      (Nhảy tới PC = 0x06, flush 4, 5)
            rom[4]  = 16'h83FF; // (Bị flush)
            rom[5]  = 16'h83FF; // (Bị flush)

            // 2. Test Load-Use Hazard & LD/ST (PC = 0x06)
            rom[6]  = 16'h8420; // LDI R4, 0x20  (R4 = địa chỉ RAM 0x20)
            rom[7]  = 16'h8255; // LDI R2, 0x55  (R2 = 0x55)
            rom[8]  = 16'hB240; // ST  R2, [R4]  (Lưu 0x55 vào RAM[0x20])
            rom[9]  = 16'hA540; // LD  R5, [R4]  (R5 = RAM[0x20] = 0x55)
            rom[10] = 16'h9505; // ADDI R5, 5    (Load-use stall: R5 = 0x5A)

            // 3. Test Shift SHL & SHR (Kiểm tra cờ Carry C)
            rom[11] = 16'h8180; // LDI R1, 0x80  (R1 = 8'b10000000, bit 7 = 1)
            rom[12] = 16'h6210; // SHL R2, R1    (R2 = 0x00, C = 1)
            rom[13] = 16'h8301; // LDI R3, 0x01  (R3 = 8'b00000001, bit 0 = 1)
            rom[14] = 16'h7430; // SHR R4, R3    (R4 = 0x00, C = 1)

            // 4. Test BNZ & JMP
            rom[15] = 16'h8601; // LDI R6, 1
            rom[16] = 16'h8702; // LDI R7, 2
            rom[17] = 16'h2667; // SUB R6, R6, R7  (R6 = 0xFF, Z = 0, C = 1)
            rom[18] = 16'hE014; // BNZ 0x14      (Nhảy tới PC = 0x14)
            rom[19] = 16'h83AA; // (Bị flush)

            // 5. Điểm đến JMP & HLT (PC = 0x14)
            rom[20] = 16'hC016; // JMP 0x16      (Nhảy tới PC = 0x16)
            rom[21] = 16'h83CC; // (Bị flush)
            rom[22] = 16'hF000; // HLT           (Kết thúc)
        end
    end

    assign inst = rom[pc];
endmodule