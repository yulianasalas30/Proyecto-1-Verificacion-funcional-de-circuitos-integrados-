`timescale 1ns/1ps

module tb_bs_gnrtr_n_rbtr;

  // Parámetros de prueba
  parameter BITS = 1;
  parameter DRVRS = 4;
  parameter PCKG_SZ = 16;
  
  // Señales de reloj y reset
  logic clk;
  logic reset;
  
  // Arreglos multidimensionales para las entradas (requiere SystemVerilog)
  logic pndng [BITS-1:0][DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_pop [BITS-1:0][DRVRS-1:0];
  
  // Arreglos multidimensionales para las salidas
  wire push [BITS-1:0][DRVRS-1:0];
  wire pop [BITS-1:0][DRVRS-1:0];
  wire [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];

  // Instancia del módulo top (Generador de bus)
  bs_gnrtr_n_rbtr #(
    .bits(BITS),
    .drvrs(DRVRS),
    .pckg_sz(PCKG_SZ)
  ) uut (
    .clk(clk),
    .reset(reset),
    .pndng(pndng),
    .D_pop(D_pop),
    .push(push),
    .pop(pop),
    .D_push(D_push)
  );

  // Generación de reloj (Periodo de 10ns -> 100MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Bloque de estímulos principal
  initial begin
    // 1. Inicialización de señales
    reset = 1;
    for (int b = 0; b < BITS; b++) begin
      for (int i = 0; i < DRVRS; i++) begin
        pndng[b][i] = 0;
        D_pop[b][i] = 0;
      end
    end

    // 2. Liberar el reset después de un par de ciclos
    #20;
    reset = 0;
    #20;

    // 3. Prueba de transmisión: El Nodo 0 solicita enviar un paquete
    $display("[%0t] [Estímulo] El Nodo 0 solicita enviar el dato 16'hA5A5...", $time);
    D_pop[0][0] = 16'hA5A5; // Dato a enviar
    pndng[0][0] = 1'b1;     // Levantar bandera de "paquete pendiente"

    // 4. Esperar a que el controlador tome el dato (señal pop en alto)
    wait(pop[0][0] == 1'b1);
    @(posedge clk);
    pndng[0][0] = 1'b0; // Bajar la solicitud una vez aceptada
    $display("[%0t] [Estímulo] Dato aceptado por el bus (señal pop detectada).", $time);

    // 5. Esperar suficiente tiempo para la serialización y deserialización (PCKG_SZ ciclos)
    #500;
    
    $display("[%0t] [Fin] Termina la simulación.", $time);
    $finish;
  end

  // Monitor: Observa de forma asíncrona cuándo cualquier nodo recibe un dato
  always @(posedge clk) begin
    for (int i = 0; i < DRVRS; i++) begin
      if (push[0][i]) begin
        $display("[%0t] [Monitor] Nodo %0d recibió un paquete válido. Dato: %h", $time, i, D_push[0][i]);
      end
    end
  end

  // (Opcional) Generación de ondas para ver en GTKWave o ModelSim
  initial begin
    $dumpfile("tb_bus.vcd");
    $dumpvars(0, tb_bs_gnrtr_n_rbtr);
  end

endmodule