/***************************************************************
* Material didactico: core_min2 (ALU completa + branches + jumps)
* Module: core_min2_branch_tb.sv
*
* Bloque "branches": ejecuta program_branches.hex, 12 escenarios (cada
* uno de beq/bne/blt/bge/bltu/bgeu, una vez con la condicion verdadera
* y otra con la condicion falsa) y verifica que cada xN termino en 1
* (se tomo el salto) o 0 (no se tomo), segun corresponda. blt/bge vs.
* bltu/bgeu usan deliberadamente los mismos bits (1 y 0xFFFFFFFF) con
* resultado opuesto, para mostrar la diferencia con/sin signo.
***************************************************************/
`timescale 1ns/1ps

module core_min2_branch_tb;

    logic clk, reset;
    int   errors;

    logic [31:0] instr_addr, instr_data;
    logic [4:0]  debug_addr;
    logic [31:0] debug_data;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    InstructionMemory_min2 #(.PROGRAM_FILE("program_branches.hex"), .NUM_WORDS(80)) imem
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
        $dumpfile("core_min2_branch_tb.fst");
        $dumpvars(0, core_min2_branch_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (58) @(negedge clk);

        check_reg(1,  32'h1, "beq  5,5  (taken)");
        check_reg(2,  32'h0, "beq  5,6  (not taken)");
        check_reg(3,  32'h1, "bne  5,6  (taken)");
        check_reg(4,  32'h0, "bne  5,5  (not taken)");
        check_reg(5,  32'h1, "blt  -1,1 (taken, con signo)");
        check_reg(6,  32'h0, "blt  1,-1 (not taken, con signo)");
        check_reg(7,  32'h1, "bge  1,-1 (taken, con signo)");
        check_reg(8,  32'h0, "bge  -1,1 (not taken, con signo)");
        check_reg(9,  32'h1, "bltu 1,-1 (taken, sin signo)");
        check_reg(10, 32'h0, "bltu -1,1 (not taken, sin signo)");
        check_reg(11, 32'h1, "bgeu -1,1 (taken, sin signo)");
        check_reg(12, 32'h0, "bgeu 1,-1 (not taken, sin signo)");

        if (errors == 0) $display("PASS: branches (6 tipos, taken+not-taken)");
        else             $display("FAIL: branches con %0d error(es)", errors);
        $finish;
    end

endmodule
