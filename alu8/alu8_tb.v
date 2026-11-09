/***************************************************************************
* Material didactico: ALU de 8 bits para Silicluster v3 (SKY130)
* Module: alu8_tb.v
*
* Testbench en Verilog puro para alu8.v. Genera un reloj, carga A y B
* por el bus compartido data_in (como hara el chip real, con solo 14
* pines de entrada disponibles), recorre las 8 operaciones del ALU y
* verifica resultado y banderas contra el valor esperado calculado en
* el propio testbench. Al final vuelca las ondas a alu8_tb.vcd para
* inspeccionarlas con Surfer o GTKWave.
***************************************************************************/
`timescale 1ns/1ps

module alu8_tb;

    reg        clk;
    reg        rst;
    reg  [7:0] data_in;
    reg  [2:0] op_sel;
    reg        load_a;
    reg        load_b;

    wire [7:0] result;
    wire       zero;
    wire       carry_out;
    wire       negative;
    wire       overflow;

    integer errors;

    alu8 dut
    (
        .clk       (clk),
        .rst       (rst),
        .data_in   (data_in),
        .op_sel    (op_sel),
        .load_a    (load_a),
        .load_b    (load_b),
        .result    (result),
        .zero      (zero),
        .carry_out (carry_out),
        .negative  (negative),
        .overflow  (overflow)
    );

    // Reloj de 10ns de periodo (100 MHz en simulacion aunque el chip real
    // correra hasta 10 MHz, pero aqui solo nos importa ver cada flanco).
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Vuelca todas las señales del testbench (y por lo tanto del DUT)
    // a un archivo de ondas que se puede abrir con Surfer o GTKWave.
    initial begin
        $dumpfile("alu8_tb.vcd");
        $dumpvars(0, alu8_tb);
    end

    // Tarea auxiliar: carga un byte en reg_a o reg_b por el bus
    // compartido data_in, igual que lo haria el controlador externo
    // del chip a traves de los pines load_a / load_b.
    task load_byte;
        input        is_b;
        input [7:0]  value;
        begin
            data_in = value;
            load_a  = ~is_b;
            load_b  =  is_b;
            @(posedge clk);
            #1;
            load_a  = 1'b0;
            load_b  = 1'b0;
        end
    endtask

    // Tarea auxiliar: aplica una operacion y compara contra lo esperado.
    task check_op;
        input [2:0]  op;
        input [7:0]  exp_result;
        input        exp_carry;
        input        exp_overflow;
        input [8*24-1:0] name;
        begin
            op_sel = op;
            #1;
            if (result !== exp_result || carry_out !== exp_carry || overflow !== exp_overflow) begin
                $display("FAIL %s: result=%0d (esp %0d) carry=%0b (esp %0b) overflow=%0b (esp %0b)",
                          name, result, exp_result, carry_out, exp_carry, overflow, exp_overflow);
                errors = errors + 1;
            end else begin
                $display("PASS %s: result=%0d carry=%0b overflow=%0b zero=%0b negative=%0b",
                          name, result, carry_out, overflow, zero, negative);
            end
        end
    endtask

    initial begin
        errors  = 0;
        rst     = 1'b1;
        data_in = 8'b0;
        op_sel  = 3'b0;
        load_a  = 1'b0;
        load_b  = 1'b0;

        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        // ---- ADD: 20 + 15 = 35, sin acarreo ni desborde ----
        load_byte(1'b0, 8'd20);
        load_byte(1'b1, 8'd15);
        check_op(3'b000, 8'd35, 1'b0, 1'b0, "ADD 20+15");

        // ---- SUB: 20 - 15 = 5 ----
        check_op(3'b001, 8'd5, 1'b1, 1'b0, "SUB 20-15");

        // ---- SUB con resultado negativo: 4 - 6 = -2 -> 8'hFE ----
        load_byte(1'b0, 8'd4);
        load_byte(1'b1, 8'd6);
        check_op(3'b001, 8'hFE, 1'b0, 1'b0, "SUB 4-6");

        // ---- ADD con acarreo de salida: 200 + 100 = 300 -> 8'h2C, carry=1 ----
        load_byte(1'b0, 8'd200);
        load_byte(1'b1, 8'd100);
        check_op(3'b000, 8'h2C, 1'b1, 1'b0, "ADD 200+100 (carry)");

        // ---- ADD con desborde con signo: 100 + 50 = 150 (>127) ----
        load_byte(1'b0, 8'd100);
        load_byte(1'b1, 8'd50);
        check_op(3'b000, 8'd150, 1'b0, 1'b1, "ADD 100+50 (overflow)");

        // ---- AND / OR / XOR sobre 8'hF0 y 8'h0F ----
        load_byte(1'b0, 8'hF0);
        load_byte(1'b1, 8'h0F);
        check_op(3'b010, 8'h00, 1'b0, 1'b0, "AND F0&0F");
        check_op(3'b011, 8'hFF, 1'b0, 1'b0, "OR  F0|0F");
        check_op(3'b100, 8'hFF, 1'b0, 1'b0, "XOR F0^0F");

        // ---- SLL / SRL / SRA: A = 8'h81, B = 3'd2 ----
        load_byte(1'b0, 8'h81);
        load_byte(1'b1, 8'd2);
        check_op(3'b101, 8'h04, 1'b0, 1'b0, "SLL 81<<2");
        check_op(3'b110, 8'h20, 1'b0, 1'b0, "SRL 81>>2");
        check_op(3'b111, 8'hE0, 1'b0, 1'b0, "SRA 81>>>2");

        // ---- zero flag: A - A siempre da 0 ----
        load_byte(1'b0, 8'd42);
        load_byte(1'b1, 8'd42);
        op_sel = 3'b001;
        #1;
        if (zero !== 1'b1) begin
            $display("FAIL zero flag: A-A deberia encender zero");
            errors = errors + 1;
        end else begin
            $display("PASS zero flag: A-A enciende zero");
        end

        if (errors == 0)
            $display("PASS: alu8 -- todas las operaciones verificadas");
        else
            $display("FAIL: %0d error(es) en alu8", errors);

        $finish;
    end

endmodule
