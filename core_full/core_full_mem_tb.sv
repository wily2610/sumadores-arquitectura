/***************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: core_full_mem_tb.sv
*
* Bloque final, "memoria": ejecuta program_loadstore.hex sobre el
* nucleo completo, con DataMemory_full conectada de verdad (no en 0
* como en los bloques anteriores). Cubre lb/lbu/lh/lhu/lw y sb/sh/sw,
* incluyendo el caso critico de que un store de byte/halfword NO debe
* alterar los bytes vecinos de la palabra (write_data_strobe_o).
***************************************************************/
`timescale 1ns/1ps

module core_full_mem_tb;

    logic clk, reset;
    int   errors;

    logic [31:0] instr_addr, instr_data;
    logic [4:0]  debug_addr;
    logic [31:0] debug_data;

    logic        write_enable;
    logic [31:0] write_data;
    logic [3:0]  write_data_strobe;
    logic [31:0] address;
    logic [31:0] read_data;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    InstructionMemory_full #(.PROGRAM_FILE("program_loadstore.hex"), .NUM_WORDS(32)) imem
    (
        .instruction_data_o   (instr_data),
        .instruction_address_i(instr_addr)
    );

    DataMemory_full #(.XLEN(32), .MEM_BYTES(256)) dmem
    (
        .read_data_o          (read_data),
        .clk_i                (clk),
        .write_enable_i       (write_enable),
        .write_data_i         (write_data),
        .write_data_strobe_i  (write_data_strobe),
        .address_i            (address)
    );

    ProcessorCoreFull dut
    (
        .clk_i                 (clk),
        .reset_i               (reset),
        .instruction_address_o (instr_addr),
        .instruction_data_i    (instr_data),
        .read_data_i           (read_data),
        .write_enable_o        (write_enable),
        .write_data_o          (write_data),
        .write_data_strobe_o   (write_data_strobe),
        .address_o             (address),
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
        $dumpfile("core_full_mem_tb.fst");
        $dumpvars(0, core_full_mem_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (30) @(negedge clk);

        check_reg(3,  32'hFFFFFFFF, "lb  (0xFF con signo)");
        check_reg(4,  32'h000000FF, "lbu (0xFF sin signo)");
        check_reg(9,  32'hFFFFFF01, "lh  (0xFF01 con signo)");
        check_reg(10, 32'h0000FF01, "lhu (0xFF01 sin signo)");
        check_reg(16, 32'hDDCCBBAA, "lw  tras 4 sb: orden little-endian");
        check_reg(17, 32'h89ABCDEF, "x17 = constante original");
        check_reg(18, 32'h89ABCDEF, "lw  tras sw: ida y vuelta exacta");
        check_reg(20, 32'h0000FFFF, "lw  tras sh: NO debe arrastrar FFFFFFFF");

        if (errors == 0) $display("PASS: memoria (loads/stores, byte/half/word, little-endian)");
        else             $display("FAIL: memoria con %0d error(es)", errors);
        $finish;
    end

endmodule
