/***************************************************************************
* Material didactico: core_min2 (ALU completa + branches + jumps)
* Module: CoreControlUnit_min2.sv
*
* Version extendida de CoreControlUnit_min.sv (que solo decodificaba
* add/sub/addi). Aqui agregamos lo necesario para llegar hasta branches
* y saltos:
*
*   - OP_R_TYPE      (0110011): add, sub, sll, slt, sltu, xor, srl, sra,
*                                or, and
*   - OP_I_ALU_TYPE  (0010011): addi, slti, sltiu, xori, ori, andi,
*                                slli, srli, srai
*   - OP_B_TYPE      (1100011): beq, bne, blt, bge, bltu, bgeu
*   - OP_I_JALR_TYPE (1100111): jalr
*   - OP_J_TYPE      (1101111): jal
*
* Todavia quedan fuera de alcance -- y se decodifican, junto con
* cualquier otro opcode, como el mismo no-op seguro del default (no
* escriben registro, PC avanza normal):
*   - OP_U_LUI_TYPE/OP_U_AUIPC_TYPE (lui/auipc)
*   - OP_I_LOAD_TYPE/OP_S_TYPE      (loads/stores: no hay memoria de
*     datos en este bloque, igual que no habia ComparatorUnit en
*     core_min/)
*   - fence, ecall/ebreak
*
* Igual que en CoreControlUnit_min.sv, add/sub se distinguen por el bit
* 30 de la instruccion (funct7_bit5_i); el truco nuevo de este archivo es
* que slt/sltu NO tienen su propio circuito en el ALU -- reutilizan
* ComparatorUnit (el mismo que usan los branches) y el resultado llega al
* banco de registros via RD_MUX_BCU en vez de RD_MUX_ALU.
*
* Basado en CoreControlUnit.sv de /Users/rtrevinnoc/RV32I/src.
***************************************************************************/
import risc_v_32_i_pkg::*;

module CoreControlUnit_min2
(
    output logic                    pc_mux_sel_o,
    output logic                    reg_write_enable_o,
    output imm_select_e             imm_select_o,
    output logic                    execute_port_a_sel_o,
    output logic                    execute_port_b_sel_o,
    output alu_select_e             alu_op_sel_o,
    output comp_select_e            comp_op_sel_o,
    output write_data_select_e      reg_write_data_sel_o,
    input  logic [6:0]              op_code_i,
    input  logic [2:0]              funct3_i,
    input  logic                    funct7_bit5_i,
    input  logic                    branch_enable_i
);

    localparam OP_R_TYPE        = 7'b0110011;
    localparam OP_B_TYPE        = 7'b1100011;
    localparam OP_I_JALR_TYPE   = 7'b1100111;
    localparam OP_I_ALU_TYPE    = 7'b0010011;
    localparam OP_J_TYPE        = 7'b1101111;

    always_comb
    begin
        unique case(op_code_i)

            // --- R-type: add, sub, sll, slt, sltu, xor, srl, sra, or, and
            OP_R_TYPE:
            begin
                pc_mux_sel_o          = 1'b0;
                reg_write_enable_o    = 1'b1;
                imm_select_o          = IMM_UNKNOWN_TYPE;
                execute_port_a_sel_o  = 1'b1;

                // execute_port_b_sel_o alimenta DOS muxes con sentido
                // invertido: alu_port_b elige reg_source_2 cuando vale 1
                // (inmediato cuando 0); comp_port_b elige el inmediato
                // cuando vale 1 (reg_source_2 cuando 0). Para slt/sltu
                // -- que SI comparan rs1 contra rs2, no contra un
                // inmediato -- hay que ponerlo en 0 para que el
                // comparador reciba reg_source_2 (el resultado del ALU,
                // en 1, no importa: reg_write_data_sel_o lo ignora).
                unique case({funct7_bit5_i, funct3_i})
                    4'b0000: begin alu_op_sel_o=OP_ADD; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // add
                    4'b1000: begin alu_op_sel_o=OP_SUB; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // sub
                    4'b0001: begin alu_op_sel_o=OP_SLL; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // sll
                    4'b0010: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BLT;  execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_BCU; end // slt
                    4'b0011: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BLTU; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_BCU; end // sltu
                    4'b0100: begin alu_op_sel_o=OP_XOR; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // xor
                    4'b0101: begin alu_op_sel_o=OP_SRL; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // srl
                    4'b1101: begin alu_op_sel_o=OP_SRA; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // sra
                    4'b0110: begin alu_op_sel_o=OP_OR;  comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // or
                    4'b0111: begin alu_op_sel_o=OP_AND; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end // and
                    default: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_ALU; end
                endcase
            end

            // --- I-type ALU: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
            OP_I_ALU_TYPE:
            begin
                pc_mux_sel_o          = 1'b0;
                reg_write_enable_o    = 1'b1;
                imm_select_o          = IMM_I_TYPE;
                execute_port_a_sel_o  = 1'b1;

                // Igual que en OP_R_TYPE, pero al reves: slti/sltiu SI
                // comparan contra el inmediato, asi que ahi
                // execute_port_b_sel_o=1 (el comparador toma el
                // inmediato); el resto (que no usa el comparador) se
                // deja en 0 para que el ALU tome el inmediato.
                unique case(funct3_i)
                    3'b000: begin alu_op_sel_o=OP_ADD; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // addi
                    3'b010: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BLT;  execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_BCU; end // slti
                    3'b011: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BLTU; execute_port_b_sel_o=1'b1; reg_write_data_sel_o=RD_MUX_BCU; end // sltiu
                    3'b100: begin alu_op_sel_o=OP_XOR; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // xori
                    3'b110: begin alu_op_sel_o=OP_OR;  comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // ori
                    3'b111: begin alu_op_sel_o=OP_AND; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // andi
                    3'b001: begin alu_op_sel_o=OP_SLL; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // slli
                    3'b101: begin alu_op_sel_o=(funct7_bit5_i ? OP_SRA : OP_SRL); comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end // srli/srai
                    default: begin alu_op_sel_o=OP_UNKNOWN; comp_op_sel_o=OP_BUNKNOWN; execute_port_b_sel_o=1'b0; reg_write_data_sel_o=RD_MUX_ALU; end
                endcase
            end

            // --- B-type: beq, bne, blt, bge, bltu, bgeu
            OP_B_TYPE:
            begin
                pc_mux_sel_o          = branch_enable_i;
                reg_write_enable_o    = 1'b0;
                imm_select_o          = IMM_B_TYPE;
                execute_port_a_sel_o  = 1'b0;
                execute_port_b_sel_o  = 1'b0;
                alu_op_sel_o          = OP_ADD;
                reg_write_data_sel_o  = RD_MUX_N_A;

                unique case(funct3_i)
                    3'b000:  comp_op_sel_o = OP_BEQ;
                    3'b001:  comp_op_sel_o = OP_BNE;
                    3'b100:  comp_op_sel_o = OP_BLT;
                    3'b101:  comp_op_sel_o = OP_BGE;
                    3'b110:  comp_op_sel_o = OP_BLTU;
                    3'b111:  comp_op_sel_o = OP_BGEU;
                    default: comp_op_sel_o = OP_BUNKNOWN;
                endcase
            end

            // --- jalr
            OP_I_JALR_TYPE:
            begin
                pc_mux_sel_o          = 1'b1;
                reg_write_enable_o    = 1'b1;
                imm_select_o          = IMM_I_TYPE;
                execute_port_a_sel_o  = 1'b1;
                execute_port_b_sel_o  = 1'b0;
                alu_op_sel_o          = OP_ADD;
                comp_op_sel_o         = OP_BUNKNOWN;
                reg_write_data_sel_o  = RD_MUX_PC_N;
            end

            // --- jal
            OP_J_TYPE:
            begin
                pc_mux_sel_o          = 1'b1;
                reg_write_enable_o    = 1'b1;
                imm_select_o          = IMM_J_TYPE;
                execute_port_a_sel_o  = 1'b0;
                execute_port_b_sel_o  = 1'b0;
                alu_op_sel_o          = OP_ADD;
                comp_op_sel_o         = OP_BUNKNOWN;
                reg_write_data_sel_o  = RD_MUX_PC_N;
            end

            // --- todo lo demas (lui, auipc, loads, stores, fence,
            // ecall/ebreak): no-op seguro -- no hay unidad de memoria de
            // datos ni mux de inmediato hacia el banco de registros en
            // este bloque todavia.
            default:
            begin
                pc_mux_sel_o          = 1'b0;
                reg_write_enable_o    = 1'b0;
                imm_select_o          = IMM_UNKNOWN_TYPE;
                execute_port_a_sel_o  = 1'b0;
                execute_port_b_sel_o  = 1'b0;
                alu_op_sel_o          = OP_UNKNOWN;
                comp_op_sel_o         = OP_BUNKNOWN;
                reg_write_data_sel_o  = RD_MUX_N_A;
            end
        endcase
    end
endmodule
