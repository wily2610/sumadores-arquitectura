/***************************************************************************
* Material didactico: core_full -- top-level para el Arty A7-100T
* Module: TopArtyA7.sv
*
* Envuelve ProcessorCoreFull con memoria de instrucciones y de datos (las
* mismas InstructionMemory_full/DataMemory_full que usa el testbench
* capstone, core_full_tb.sv) y lo conecta a la placa:
*
*   - CLK100MHZ: reloj del nucleo, sin PLL -- un monociclo a 100 MHz
*     corre el programa completo en microsegundos, muy por debajo de
*     cualquier periodo de reloj real.
*   - btn[0]: reset, activo en alto (igual que reset_i del nucleo).
*   - sw[3:0]: indice de registro a mostrar (x0-x15) via el puerto de
*     depuracion debug_reg_addr_i/debug_reg_data_o.
*   - led[3:0] + led{0..3}_r: byte completo (8 bits) del registro elegido
*     -- led[3:0] el nibble bajo, led{0..3}_r el nibble alto.
*   - led3_b: parpadeo de ~1.5 Hz para confirmar que el reloj esta vivo,
*     incluso despues de que el programa termino de correr.
***************************************************************************/
module TopArtyA7
(
    input  logic       CLK100MHZ,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic       led0_r, led1_r, led2_r, led3_r,
    output logic       led3_b
);

    logic clk, reset;
    assign clk   = CLK100MHZ;
    assign reset = btn[0];

    logic [31:0] instr_addr, instr_data;
    logic        write_enable;
    logic [31:0] write_data;
    logic [3:0]  write_data_strobe;
    logic [31:0] address;
    logic [31:0] read_data;

    logic        retire_valid;
    logic [31:0] retire_pc, retire_instruction, retire_rd_value;
    logic        retire_reg_write;
    logic [4:0]  retire_rd;

    logic [31:0] debug_reg_data;

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

    ProcessorCoreFull core
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
        .debug_reg_addr_i      ({1'b0, sw}),
        .debug_reg_data_o      (debug_reg_data)
    );

    assign led    = debug_reg_data[3:0];
    assign led0_r = debug_reg_data[4];
    assign led1_r = debug_reg_data[5];
    assign led2_r = debug_reg_data[6];
    assign led3_r = debug_reg_data[7];

    logic [25:0] heartbeat_counter;
    always_ff @(posedge clk)
        heartbeat_counter <= heartbeat_counter + 26'd1;
    assign led3_b = heartbeat_counter[25];

endmodule
