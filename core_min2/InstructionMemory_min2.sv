/***************************************************************
* Material didactico: core_min2 (ALU completa + branches + jumps)
* Module: InstructionMemory_min2.sv
*
* Misma idea que InstructionMemory_min.sv: ROM combinacional cargada por
* $readmemh, direccionada por palabra (instruction_address_i[31:2]). Se
* le agrega un parametro PROGRAM_FILE para poder reutilizar el mismo
* modulo con cada uno de los programas de prueba de este bloque
* (program_alu_rtype_itype.hex, program_branches.hex, program_jumps.hex,
* sin tener que copiar el modulo por cada uno).
***************************************************************/
module InstructionMemory_min2 #(parameter string PROGRAM_FILE = "program_jumps.hex",
                                 parameter int    NUM_WORDS    = 64)
(
    output logic [31:0]   instruction_data_o,
    input  logic [31:0]   instruction_address_i
);

    logic [31:0] instruction [NUM_WORDS-1:0];

    initial
    begin
        $readmemh(PROGRAM_FILE, instruction);
    end

    always_comb
    begin
        instruction_data_o = instruction[instruction_address_i[31:2]];
    end

endmodule
