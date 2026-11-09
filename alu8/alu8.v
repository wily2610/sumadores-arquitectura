/***************************************************************************
* Material didactico: ALU de 8 bits para Silicluster v3 (SKY130)
* Module: alu8.v
*
* ALU de 8 bits pensada para caber en el presupuesto de pines de un
* proyecto digital de Silicluster v3: hasta 14 entradas y 14 salidas
* digitales, mas un pin externo de reloj (clk) y uno de reset (rst).
*
* Sumar A[7:0] y B[7:0] en paralelo junto con un selector de operacion
* necesita 19 entradas (8+8+3), mas que las 14 disponibles. Por eso
* A y B se cargan por un mismo bus de 8 bits (data_in), uno a la vez,
* usando dos señales de carga (load_a, load_b) sincronas con clk.
*
* Entradas digitales usadas:  data_in[7:0] + op_sel[2:0] + load_a + load_b = 13
* Salidas digitales usadas:   result[7:0] + zero + carry_out + negative + overflow = 12
*
* Codigo en Verilog puro (sin SystemVerilog): Silicluster v3 solo acepta
* Verilog sintetizable para los proyectos digitales.
***************************************************************************/
`timescale 1ns/1ps

module alu8
(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] data_in,
    input  wire [2:0] op_sel,
    input  wire       load_a,
    input  wire       load_b,

    output wire [7:0] result,
    output wire        zero,
    output wire        carry_out,
    output wire        negative,
    output wire        overflow
);

    // Codigos de operacion. Verilog no tiene "enum" como SystemVerilog,
    // asi que usamos localparam para nombrar cada valor de op_sel.
    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_AND = 3'b010;
    localparam [2:0] OP_OR  = 3'b011;
    localparam [2:0] OP_XOR = 3'b100;
    localparam [2:0] OP_SLL = 3'b101;
    localparam [2:0] OP_SRL = 3'b110;
    localparam [2:0] OP_SRA = 3'b111;

    // -----------------------------------------------------------------
    // Banco de dos registros de 8 bits (A y B).
    // Se cargan uno a la vez desde el mismo bus data_in, para no
    // exceder de 14 entradas digitales.
    // -----------------------------------------------------------------
    reg [7:0] reg_a;
    reg [7:0] reg_b;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_a <= 8'b0;
            reg_b <= 8'b0;
        end else begin
            if (load_a) reg_a <= data_in;
            if (load_b) reg_b <= data_in;
        end
    end

    // -----------------------------------------------------------------
    // Sumador/restador: mismo truco XOR + carry_in visto en la clase
    // de ADD/SUB/ADDI. B se invierte bit a bit cuando op_sel pide una
    // resta, y ese mismo bit entra como el acarreo inicial (+1 del
    // complemento a 2).
    // -----------------------------------------------------------------
    wire       is_sub    = (op_sel == OP_SUB);
    wire [7:0] b_operand = reg_b ^ {8{is_sub}};
    wire [8:0] add_wide  = {1'b0, reg_a} + {1'b0, b_operand} + is_sub;

    wire [7:0] add_result   = add_wide[7:0];
    wire       add_carry    = add_wide[8];
    wire       add_overflow = (reg_a[7] == b_operand[7]) && (add_result[7] != reg_a[7]);

    // -----------------------------------------------------------------
    // Selector de operacion: el mismo patron "case" del ALU de RV32I,
    // ahora con 8 bits de ancho y escrito en Verilog puro.
    // -----------------------------------------------------------------
    reg [7:0] alu_result;
    reg       alu_carry;
    reg       alu_overflow;

    always @(*) begin
        alu_carry    = 1'b0;
        alu_overflow = 1'b0;
        case (op_sel)
            OP_ADD:  begin alu_result = add_result; alu_carry = add_carry; alu_overflow = add_overflow; end
            OP_SUB:  begin alu_result = add_result; alu_carry = add_carry; alu_overflow = add_overflow; end
            OP_AND:  alu_result = reg_a & reg_b;
            OP_OR:   alu_result = reg_a | reg_b;
            OP_XOR:  alu_result = reg_a ^ reg_b;
            OP_SLL:  alu_result = reg_a << reg_b[2:0];
            OP_SRL:  alu_result = reg_a >> reg_b[2:0];
            OP_SRA:  alu_result = $signed(reg_a) >>> reg_b[2:0];
            default: alu_result = 8'b0;
        endcase
    end

    assign result    = alu_result;
    assign carry_out = alu_carry;
    assign overflow  = alu_overflow;
    assign zero      = (alu_result == 8'b0);
    assign negative  = alu_result[7];

endmodule
