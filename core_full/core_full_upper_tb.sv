/***************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: core_full_upper_tb.sv
*
* Bloque "lui/auipc": ejecuta program_upper.hex y verifica, ademas de
* lui/auipc por separado, el idioma de dos instrucciones (lui+addi)
* que usan los ensambladores para materializar una constante de 32
* bits arbitraria (la pseudo-instruccion "li").
***************************************************************/
`timescale 1ns/1ps

module core_full_upper_tb;

    logic clk, reset;
    int   errors;

    logic [31:0] instr_addr, instr_data;
    logic [4:0]  debug_addr;
    logic [31:0] debug_data;

    logic        write_enable;
    logic [31:0] write_data;
    logic [3:0]  write_data_strobe;
    logic [31:0] address;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    InstructionMemory_full #(.PROGRAM_FILE("program_upper.hex"), .NUM_WORDS(16)) imem
    (
        .instruction_data_o   (instr_data),
        .instruction_address_i(instr_addr)
    );

    ProcessorCoreFull dut
    (
        .clk_i                 (clk),
        .reset_i               (reset),
        .instruction_address_o (instr_addr),
        .instruction_data_i    (instr_data),
        .read_data_i           (32'h0),
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
        $dumpfile("core_full_upper_tb.fst");
        $dumpvars(0, core_full_upper_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (9) @(negedge clk);

        check_reg(1, 32'h12345000, "lui x1,0x12345");
        check_reg(2, 32'h00001004, "auipc x2,0x1 (PC=4)");
        check_reg(3, 32'hFFFFF000, "lui x3,0xFFFFF (bit de signo del U-type)");
        check_reg(4, 32'h0000000C, "auipc x4,0 (leer el PC actual)");
        check_reg(5, 32'h12345678, "lui+addi: constante de 32 bits exacta");

        if (errors == 0) $display("PASS: lui/auipc");
        else             $display("FAIL: lui/auipc con %0d error(es)", errors);
        $finish;
    end

endmodule
