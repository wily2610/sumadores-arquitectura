/***************************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: DataMemory_full.sv
*
* Memoria de datos direccionable por byte (little-endian, como todo
* RISC-V): MEM_BYTES bytes individuales en vez de un arreglo de palabras.
* Esto hace que loads y stores de byte/halfword sean directos, sin tener
* que calcular un indice de palabra ni desplazar bits:
*
*   - Lectura combinacional: siempre regresa los 4 bytes a partir de
*     address_i (direccion exacta, sin alinear a palabra). LoadAndStoreUnit
*     ya sabe tomar solo los bytes que necesita de ahi.
*   - Escritura sincrona con habilitacion por byte (write_data_strobe_i):
*     solo se escriben los bytes marcados en 1 -- asi un `sb` no borra los
*     otros 3 bytes de la palabra que lo rodea.
*
* Mejora intencional sobre DataMemory.sv de /Users/rtrevinnoc/RV32I/src
* (ahi la escritura ignora el strobe).
***************************************************************************/
module DataMemory_full #(parameter XLEN = 32, parameter MEM_BYTES = 256)
(
    output logic [XLEN-1:0]     read_data_o,
    input  logic                clk_i,
    input  logic                write_enable_i,
    input  logic [XLEN-1:0]     write_data_i,
    input  logic [3:0]          write_data_strobe_i,
    input  logic [XLEN-1:0]     address_i
);

    logic [7:0] mem [0:MEM_BYTES-1];

    initial
    begin
        for (int i = 0; i < MEM_BYTES; i++)
            mem[i] = 8'h00;
    end

    always_comb
    begin
        read_data_o = {mem[address_i[$clog2(MEM_BYTES)-1:0] + 3],
                       mem[address_i[$clog2(MEM_BYTES)-1:0] + 2],
                       mem[address_i[$clog2(MEM_BYTES)-1:0] + 1],
                       mem[address_i[$clog2(MEM_BYTES)-1:0]    ]};
    end

    always_ff @(posedge clk_i)
    begin
        if (write_enable_i)
        begin
            if (write_data_strobe_i[0]) mem[address_i[$clog2(MEM_BYTES)-1:0]    ] <= write_data_i[7:0];
            if (write_data_strobe_i[1]) mem[address_i[$clog2(MEM_BYTES)-1:0] + 1] <= write_data_i[15:8];
            if (write_data_strobe_i[2]) mem[address_i[$clog2(MEM_BYTES)-1:0] + 2] <= write_data_i[23:16];
            if (write_data_strobe_i[3]) mem[address_i[$clog2(MEM_BYTES)-1:0] + 3] <= write_data_i[31:24];
        end
    end

endmodule
