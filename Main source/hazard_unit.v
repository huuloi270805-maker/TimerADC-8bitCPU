module hazard_unit (
    input  wire       id_ex_mem_read,
    input  wire [2:0] id_ex_rd,
    input  wire       if_id_uses_a,
    input  wire [2:0] if_id_rs1,
    input  wire       if_id_uses_b,
    input  wire [2:0] if_id_rs2,
    input  wire       ex_mem_reg_we,
    input  wire [2:0] ex_mem_rd,
    input  wire       mem_wb_reg_we,
    input  wire [2:0] mem_wb_rd,
    input  wire       id_ex_uses_a,
    input  wire [2:0] id_ex_rs1,
    input  wire       id_ex_uses_b,
    input  wire [2:0] id_ex_rs2,
    output reg  [1:0] fwd_a_sel,
    output reg  [1:0] fwd_b_sel,
    output reg        stall
);

    always @(*) begin
        // Load-Use Hazard Stall
        stall = 1'b0;
        if (id_ex_mem_read && (id_ex_rd != 3'b000)) begin
            if ((if_id_uses_a && (if_id_rs1 == id_ex_rd)) || 
                (if_id_uses_b && (if_id_rs2 == id_ex_rd))) begin
                stall = 1'b1;
            end
        end

        // Forwarding A
        fwd_a_sel = 2'b00;
        if (id_ex_uses_a && (id_ex_rs1 != 3'b000)) begin
            if (ex_mem_reg_we && (ex_mem_rd == id_ex_rs1)) begin
                fwd_a_sel = 2'b10;
            end else if (mem_wb_reg_we && (mem_wb_rd == id_ex_rs1)) begin
                fwd_a_sel = 2'b01;
            end
        end

        // Forwarding B
        fwd_b_sel = 2'b00;
        if (id_ex_uses_b && (id_ex_rs2 != 3'b000)) begin
            if (ex_mem_reg_we && (ex_mem_rd == id_ex_rs2)) begin
                fwd_b_sel = 2'b10;
            end else if (mem_wb_reg_we && (mem_wb_rd == id_ex_rs2)) begin
                fwd_b_sel = 2'b01;
            end
        end
    end
endmodule