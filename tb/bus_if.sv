`include "tb/bus_defines.svh"

interface bus_if #(
  parameter int DRVRS   = `BUS_DRVRS,
  parameter int PCKG_SZ = `BUS_PCKG_SZ
)(
  input bit clk
);

  logic               reset;

  logic               pndng [DRVRS-1:0];
  logic               push  [DRVRS-1:0];
  logic               pop   [DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_pop [DRVRS-1:0];
  logic [PCKG_SZ-1:0] D_push[DRVRS-1:0];

  clocking cb_drv @(posedge clk);
    default input #1step output #1ns;
    output pndng, D_pop;
    input  pop;
  endclocking

  clocking cb_mon @(posedge clk);
    default input #1step;
    input reset, pndng, push, pop, D_pop, D_push;
  endclocking

  clocking cb_env @(posedge clk);
    default input #1step output #1ns;
    output reset;
  endclocking

  modport DRV (clocking cb_drv);
  modport MON (clocking cb_mon);
  modport ENV (clocking cb_env);
  modport DUT (input  clk, reset, pndng, D_pop,
               output push, pop, D_push);

endinterface : bus_if