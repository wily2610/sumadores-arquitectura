/***************************************************************************
* Material didactico: core_full (RV32I base completo)
* Module: LoadAndStoreUnit.sv
*
* Alinea y extiende signo/ceros para loads, y recorta + genera los bits
* de habilitacion por byte (strobe) para stores. No decide la direccion
* (eso lo hace el ALU, sumando rs1 + inmediato) ni accede a la memoria
* (eso lo hace DataMemory_full) -- solo da forma a los datos que entran
* y salen de ella.
*
* Supone que DataMemory_full es direccionable por byte y que, para
* cualquier direccion, regresa los 4 bytes consecutivos a partir de esa
* direccion con el byte en la direccion exacta en los bits [7:0]. Por eso
* los casos L_B/L_H solo necesitan mirar los bits bajos de read_data_i.
*
* Basado en el modulo del mismo nombre de /Users/rtrevinnoc/RV32I/src.
***************************************************************************/
import risc_v_32_i_pkg::*;

module LoadAndStoreUnit #(parameter XLEN = 32)
(
    output logic [XLEN-1:0]     read_data_o,
    input  logic [XLEN-1:0]     read_data_i,
    output logic [XLEN-1:0]     write_data_o,
    input  logic [XLEN-1:0]     write_data_i,
    input  load_store_type_e    load_store_type_i,
    output logic [3:0]          write_data_strobe_o
);

    always_comb
    begin
        unique case(load_store_type_i)
               L_B: read_data_o =               $signed(read_data_i[(XLEN/4)-1:0]);
              L_BU: read_data_o = {{((3*XLEN)/4){1'b0}},read_data_i[(XLEN/4)-1:0]};
               L_H: read_data_o =               $signed(read_data_i[(XLEN/2)-1:0]);
              L_HU: read_data_o = {{(( XLEN /2)){1'b0}},read_data_i[(XLEN/2)-1:0]};
               L_W: read_data_o =                       read_data_i[XLEN-1:0];
           default: read_data_o =                       read_data_i[XLEN-1:0];
        endcase
    end

    always_comb
    begin
        unique case(load_store_type_i)
               S_B:
                   begin
                   write_data_o = {{((3*XLEN)/4){1'b0}},write_data_i[(XLEN/4)-1:0]};
                   write_data_strobe_o = 4'b0001;
                   end
               S_H:
                   begin
                   write_data_o = {{(( XLEN /2)){1'b0}},write_data_i[(XLEN/2)-1:0]};
                   write_data_strobe_o = 4'b0011;
                   end
               S_W:
                   begin
                   write_data_o = write_data_i[XLEN-1:0];
                   write_data_strobe_o = 4'b1111;
                   end
           default:
                   begin
                   write_data_o = write_data_i[XLEN-1:0];
                   write_data_strobe_o = 4'b0000;
                   end
        endcase
    end

endmodule
