`timescale 1ns/1ps

module tb_bs_gnrtr_n_rbtr;

  // Parámetros de prueba
  parameter BITS = 1;
  parameter DRVRS = 4;
  parameter PCKG_SZ = 16;
  
  // Señales de reloj y reset
  logic clk;
  logic reset;
  
  // Arreglos multidimensionales
  logic pndng [BITS-1:0][DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_pop [BITS-1:0][DRVRS-1:0];
  
  wire push [BITS-1:0][DRVRS-1:0];
  wire pop [BITS-1:0][DRVRS-1:0];
  wire [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];

  // Banderas para registrar quién recibe el paquete
  bit recibio_paquete [DRVRS];

  // Instancia del módulo top
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

  // Generación de reloj
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Bloque de estímulos principal
  initial begin
    reset = 1;
    for (int b = 0; b < BITS; b++) begin
      for (int i = 0; i < DRVRS; i++) begin
        pndng[b][i] = 0;
        D_pop[b][i] = 0;
        recibio_paquete[i] = 0; // Inicializar banderas
      end
    end

    #20;
    reset = 0;
    #20;

    // Prueba dirigida: Nodo 0 envía BROADCAST
    $display("\n========================================================");
    $display("[%0t] [Estímulo] El Nodo 0 transmite BROADCAST (16'hFFA5)...", $time);
    $display("========================================================");
    D_pop[0][0] = 16'hFFA5; // 8'hFF (Dirección BCAST) + 8'hA5 (Dato)
    pndng[0][0] = 1'b1;     

    wait(pop[0][0] == 1'b1);
    @(posedge clk);
    pndng[0][0] = 1'b0; 
    $display("[%0t] [Estímulo] Dato aceptado por el bus. Esperando propagación...", $time);

    // Tiempo amplio para que los 16 bits viajen por el bus serial
    #5000;
    
    // Generar reporte final
    $display("\n========================================================");
    $display("REPORTE FINAL DE RECEPCIÓN DE BROADCAST");
    $display("========================================================");
    for (int i = 0; i < DRVRS; i++) begin
      if (recibio_paquete[i])
        $display("-> Nodo %0d: SI recibio el paquete", i);
      else
        $display("-> Nodo %0d: NO recibio el paquete <---", i);
    end
    $display("========================================================\n");

    if (!recibio_paquete[0]) begin
      $display("CONCLUSION: ¡BUG CONFIRMADO! El Nodo 0 no puede leer su propio broadcast.\n");
    end

    $finish;
  end

  // Monitor: Observa de forma asíncrona cuándo se levantan los push
  always @(posedge clk) begin
    for (int i = 0; i < DRVRS; i++) begin
      if (push[0][i]) begin
        $display("[%0t] [Monitor] Nodo %0d levanto bandera 'push'. Dato recibido: %h", $time, i, D_push[0][i]);
        recibio_paquete[i] = 1'b1; // Marcar como recibido
      end
    end
  end

endmodule