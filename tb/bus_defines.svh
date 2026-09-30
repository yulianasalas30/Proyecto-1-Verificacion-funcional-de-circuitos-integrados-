// bus_defines.svh
// Mismo rol que fifo_defines.svh en el ejemplo FIFO.

`ifndef BUS_DEFINES_SVH
`define BUS_DEFINES_SVH

`ifndef BUS_DRVRS
  `define BUS_DRVRS 4        // cantidad de dispositivos
`endif

`ifndef BUS_PCKG_SZ
  `define BUS_PCKG_SZ 16     // ancho fijo del paquete para esta compilacion
`endif

`ifndef CLK_PERIOD
  `define CLK_PERIOD 10      // periodo de reloj en ns
`endif

`define INFO(NAME, MSG)  $display("[%0t] [%-10s] %s", $time, NAME, MSG);
`define ERR(NAME, MSG)   $display("[%0t] [%-10s] *** ERROR *** %s", $time, NAME, MSG);

`endif
