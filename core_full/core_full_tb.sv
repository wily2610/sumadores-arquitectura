/***************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: core_full_tb.sv
*
* Ejecuta program_rv32i_full.hex, un programa real
* Suma un arreglo de 5 enteros en memoria
* contado (lw, add, addi, bne), y guarda el resultado de
* vuelta en memoria. Es el equivalente, para core_full, de lo que
* program_add_sub_addi.hex fue para core_min: la prueba final de que
* todas las piezas -- ALU, comparador, memoria, banco de registros,
* control -- funcionan juntas.
***************************************************************/
`timescale 1ns/1ps

module core_full_tb;

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

    InstructionMemory_full #(.PROGRAM_FILE("program_rv32i_full.hex"), .NUM_WORDS(32)) imem
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
            $display("FAIL %s: x%0d = %0d (esperaba %0d)", name, rnum, debug_data, exp);
            errors++;
        end
        else
        begin
            $display("OK   %s: x%0d = %0d", name, rnum, debug_data);
        end
    endtask

    initial begin
        $dumpfile("core_full_tb.fst");
        $dumpvars(0, core_full_tb);
    end

    initial begin
        clk = 0; reset = 1; debug_addr = 0; errors = 0;
        @(negedge clk); reset = 0;
        repeat (45) @(negedge clk);

        if (retire_valid)
            $display("Ultima instruccion retirada: PC=0x%08h instr=0x%08h rd=x%0d valor=%0d",
                      retire_pc, retire_instruction, retire_rd, retire_rd_value);

        check_reg(2, 32'd20,  "x2 (puntero tras el lazo: 5*4)");
        check_reg(3, 32'd150, "x3 (suma acumulada en registro)");
        check_reg(4, 32'd0,   "x4 (contador llego a 0)");
        check_reg(6, 32'd150, "x6 (suma leida de vuelta de memoria)");

        if (errors == 0) $display("PASS: ProcessorCoreFull sumo el arreglo {10,20,30,40,50} = 150");
        else             $display("FAIL: ProcessorCoreFull con %0d error(es)", errors);
        $finish;
    end

endmodule
