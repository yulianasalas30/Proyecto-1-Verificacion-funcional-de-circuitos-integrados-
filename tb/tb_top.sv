//======================================================================
// tb_top.sv
//----------------------------------------------------------------------

//======================================================================
`timescale 1ns/1ps
`include "tb/bus_defines.svh"

module tb_top;

  import bus_params_pkg::*;  //para DRVRS, PCKG_SZ
  import bus_env_pkg::*;  //para bus_env

  // ------------------------------------------------------------------
  // Reloj
  // ------------------------------------------------------------------
  bit clk = 0;
  always #(`CLK_PERIOD/2.0) clk = ~clk;

  // ------------------------------------------------------------------
  // Interfaz.
  // ------------------------------------------------------------------
  bus_if #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ)) vif (clk);

  logic               pndng2d [0:0][DRVRS-1:0];
  logic               push2d  [0:0][DRVRS-1:0];
  logic               pop2d   [0:0][DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_pop2d [0:0][DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_push2d[0:0][DRVRS-1:0];

  genvar gi;
  generate
    for (gi = 0; gi < DRVRS; gi++) begin : BRIDGE
      assign pndng2d[0][gi]  = vif.pndng[gi];
      assign vif.push[gi]    = push2d[0][gi];
      assign vif.pop[gi]     = pop2d[0][gi];
      assign D_pop2d[0][gi]  = vif.D_pop[gi];
      assign vif.D_push[gi]  = D_push2d[0][gi];
    end
  endgenerate

  // ------------------------------------------------------------------
  // DUT. broadcast=BCAST_ID (8'hFF, de bus_params_pkg) para que el
  // patron reservado de broadcast coincida exactamente con el que
  // bus_txn/bus_agent ya asumen.
  // ------------------------------------------------------------------
  bs_gnrtr_n_rbtr #(
    .bits      (1),
    .drvrs     (DRVRS),
    .pckg_sz   (PCKG_SZ),
    .broadcast (BCAST_ID)
  ) dut (
    .clk    (clk),
    .reset  (vif.reset),
    .pndng  (pndng2d),
    .push   (push2d),
    .pop    (pop2d),
    .D_pop  (D_pop2d),
    .D_push (D_push2d)
  );

  // ------------------------------------------------------------------
  // Ambiente de verificacion.
  // ------------------------------------------------------------------
  bus_env env;

  initial begin
    $display("==========================================================");
    $display(" bus_gnrtr_n_rbtr testbench   DRVRS=%0d  PCKG_SZ=%0d  CLK=%0dns",
              DRVRS, PCKG_SZ, `CLK_PERIOD);
    $display("==========================================================");

    env = new();
    env.connect(vif);
    env.build();
    env.run();      // run() llama $finish al terminar, no hace falta aqui
       $monitor("[%0t] reset=%b", $time, vif.reset);
  end

endmodule : tb_top