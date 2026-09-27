//======================================================================
// bus_params_pkg.sv
//----------------------------------------------------------------------
// Convierte las macros de bus_defines.svh en parametros de paquete
// reales, mismo rol que fifo_params_pkg en el ejemplo FIFO. Debe
// compilarse ANTES de bus_if.sv, bus_txn.sv y cualquier otro archivo
// que haga `import bus_params_pkg::*;`.
//======================================================================
`include "bus_defines.svh"

package bus_params_pkg;

  parameter int DRVRS   = `BUS_DRVRS;    // M: cantidad de terminales
  parameter int PCKG_SZ = `BUS_PCKG_SZ;  // ancho fijo del paquete (16/32/64)
  parameter int ADDR_W  = 8;
  parameter bit [ADDR_W-1:0] BCAST_ID = {ADDR_W{1'b1}};
  parameter int DATA_W  = PCKG_SZ - ADDR_W;

endpackage : bus_params_pkg
