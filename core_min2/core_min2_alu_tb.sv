/***************************************************************
* Material didactico: core_min2 (ALU completa + branches + jumps)
* Module: core_min2_alu_tb.sv
*
* Bloque "ALU completa": ejecuta program_alu_rtype_itype.hex, que
* cubre los 10 R-type (add,sub,and,or,xor,sll,srl,sra,slt,sltu) y los
* 9 I-type (addi,slti,sltiu,xori,ori,andi,slli,srli,srai) de una sola
* pasada, y verifica el banco de registros contra los valores que
* calculo scratchpad/gen_block1_alu.py (verificados, a su vez, contra
* RV32I/tb/reference_model.py).
***************************************************************/
`timescale 1ns/1ps

module core_min2_alu_tb;

    logic clk, reset;
    int   errors;

    logic [31:0] instr_addr, instr_data;
    logic [4:0]  debug_addr;
    logic [31:0] debug_data;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    InstructionMemory_min2 #(.PROGRAM_FILE("program_alu_rtype_itype.hex"), .NUM_WORDS(32)) imem
    (
        .instruction_data_o   (instr_data),
        .instruction_address_i(instr_addr)
    );

    ProcessorCoreMin2 dut
    (
        .clk_i                 (clk),
        .reset_i               (reset),
        .instruction_address_o (instr_addr),
        .instruction_data_i    (instr_data),
        .retire_valid_o        (retire_valid),
        .retire_pc_o           (retire_pc),
        .retire_instruction_o  (retire_instruction),
        .retire_reg_write_o    (retire_reg_write),
        .retire_rd_o           (retire_rd),
        .retire_rd_value_o     (retire_rd_value),
        .debug_reg_addr_i      (debug_addr),
        .debug_reg_data_o      (debug_data)
    );

    always #5 clk = ~clk;

    task automatic check_reg(input logic [4:0] rnum, input logic [31:0] exp, input string name);
        debug_addr = rnum;
        #1;
        if (debug_data !== exp)
        begin
            $display("FAIL %s: x%0d = 0x%08h (esperaba 0x%08h)", name, rnum, debug_data, exp);
            errors++;
        end
        else
        begin
            $display("OK   %s: x%0d = 0x%08h", name, rnum, debug_data);
        end
    endtask

    initial begin
        $dumpfile("core_min2_alu_tb.fst");
        $dumpvars(0, core_min2_alu_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (28) @(negedge clk);

        check_reg(1,  32'h0000000F, "addi x1,x0,15");
        check_reg(2,  32'h00000003, "addi x2,x0,3");
        check_reg(3,  32'h00000012, "add  x3,x1,x2");
        check_reg(4,  32'h0000000C, "sub  x4,x1,x2");
        check_reg(5,  32'h00000003, "and  x5,x1,x2");
        check_reg(6,  32'h0000000F, "or   x6,x1,x2");
        check_reg(7,  32'h0000000C, "xor  x7,x1,x2");
        check_reg(8,  32'h00000078, "sll  x8,x1,x2");
        check_reg(9,  32'h00000001, "srl  x9,x1,x2");
        check_reg(10, 32'hFFFFFFF0, "addi x10,x0,-16");
        check_reg(11, 32'h00000002, "addi x11,x0,2");
        check_reg(12, 32'hFFFFFFFC, "sra  x12,x10,x11");
        check_reg(13, 32'h00000001, "slt  x13,x2,x1");
        check_reg(14, 32'h00000000, "slt  x14,x1,x2");
        check_reg(15, 32'h00000001, "sltu x15,x2,x1");
        check_reg(16, 32'h00000000, "sltu x16,x1,x2");
        check_reg(17, 32'hFFFFFFFB, "addi x17,x0,-5");
        check_reg(18, 32'h00000001, "slti x18,x17,-1");
        check_reg(19, 32'h00000000, "sltiu x19,x17,1");
        check_reg(20, 32'h000000F0, "xori x20,x1,0xFF");
        check_reg(21, 32'h000000FF, "ori  x21,x1,0xF0");
        check_reg(22, 32'h0000000C, "andi x22,x1,0x0C");
        check_reg(23, 32'h00000030, "slli x23,x2,4");
        check_reg(24, 32'h0FFFFFFF, "srli x24,x10,4");
        check_reg(25, 32'hFFFFFFFF, "srai x25,x10,4");

        if (errors == 0) $display("PASS: ALU completa (R-type + I-type, 19 operaciones)");
        else             $display("FAIL: ALU completa con %0d error(es)", errors);
        $finish;
    end

endmodule
