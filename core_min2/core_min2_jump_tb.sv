/***************************************************************
* Material didactico: core_min2 (ALU completa + branches + jumps)
* Module: core_min2_jump_tb.sv
*
* Bloque "saltos": ejecuta program_jumps.hex -- un jal/jalr de ida y
* vuelta (llamada-y-retorno con registro de enlace), un jalr con
* inmediato distinto de cero (salta mas alla del punto de retorno
* normal), y un jal hacia atras (bne + jal formando un lazo que cuenta
* regresivo) -- y verifica los registros marcadores de cada camino.
***************************************************************/
`timescale 1ns/1ps

module core_min2_jump_tb;

    logic clk, reset;
    int   errors;

    logic [31:0] instr_addr, instr_data;
    logic [4:0]  debug_addr;
    logic [31:0] debug_data;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    InstructionMemory_min2 #(.PROGRAM_FILE("program_jumps.hex"), .NUM_WORDS(32)) imem
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
        $dumpfile("core_min2_jump_tb.fst");
        $dumpvars(0, core_min2_jump_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (22) @(negedge clk);

        check_reg(1,  32'h00000004, "x1 = ra tras jal (llamada 1)");
        check_reg(20, 32'h0000002A, "x20 = 42 (dentro de la funcion)");
        check_reg(21, 32'h00000063, "x21 = 99 (tras el retorno, jalr x0,x1,0)");
        check_reg(22, 32'h00000064, "x22 = 100 (instruccion justo despues del jal)");
        check_reg(2,  32'h0000001C, "x2 = ra tras jal (llamada 2)");
        check_reg(25, 32'h00000007, "x25 = 7 (dentro de la segunda funcion)");
        check_reg(26, 32'h00000000, "x26 = 0 (NUNCA se ejecuta: jalr con +offset la salta)");
        check_reg(27, 32'h0000004D, "x27 = 77 (tras jalr x0,x2,offset)");
        check_reg(23, 32'h00000000, "x23 = 0 (contador del lazo al terminar)");
        check_reg(24, 32'h00000037, "x24 = 55 (tras el lazo con jal hacia atras)");

        if (errors == 0) $display("PASS: saltos (jal/jalr, llamada+retorno, lazo hacia atras)");
        else             $display("FAIL: saltos con %0d error(es)", errors);
        $finish;
    end

endmodule
