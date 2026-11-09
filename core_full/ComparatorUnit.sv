/***************************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: ComparatorUnit.sv
*
* Unidad de comparacion: produce un solo bit de salida (comp_o) a partir
* de dos operandos de XLEN bits y una operacion de comparacion. Se
* mantiene separada del ALU por dos razones:
*
*   1. Un branch necesita comparar rs1 contra rs2 en el mismo ciclo en que
*      el ALU, por separado, calcula PC + inmediato (la direccion destino
*      si el branch se toma). Si la comparacion viviera dentro del ALU,
*      no se podrian hacer ambas cosas a la vez.
*   2. slt/sltu/slti/sltiu ("set less than") *son* comparaciones -- no
*      necesitan un circuito de resta dedicado nuevo: reutilizan este
*      mismo comparador y el resultado (0 o 1) se escribe directo al
*      banco de registros via RD_MUX_BCU.
*
* Basado en el modulo del mismo nombre de /Users/rtrevinnoc/RV32I/src.
***************************************************************************/
import risc_v_32_i_pkg::*;

module ComparatorUnit #(parameter XLEN = 32)
(
    output logic                        comp_o,
    input  logic           [XLEN-1:0]   comp_port_a_i,
    input  logic           [XLEN-1:0]   comp_port_b_i,
    input  comp_select_e                comp_op_sel_i
);

    always_comb
    begin
        unique case(comp_op_sel_i)
            OP_BEQ:     comp_o =         comp_port_a_i  ==  comp_port_b_i;
            OP_BNE:     comp_o =         comp_port_a_i  !=  comp_port_b_i;
           OP_BLTU:     comp_o =         comp_port_a_i  <   comp_port_b_i;
           OP_BGEU:     comp_o =         comp_port_a_i  >=  comp_port_b_i;
            OP_BLT:     comp_o = $signed(comp_port_a_i) <   $signed(comp_port_b_i);
            OP_BGE:     comp_o = $signed(comp_port_a_i) >=  $signed(comp_port_b_i);
       OP_BUNKNOWN:     comp_o = 1'b0;
        endcase
    end
endmodule
