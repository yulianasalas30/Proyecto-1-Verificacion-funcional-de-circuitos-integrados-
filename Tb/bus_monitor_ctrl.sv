package bus_monitor_ctrl_pkg;
 
  import bus_params_pkg::*; // DRVRS
  import bus_config_pkg::*;
  import bus_monitor_pkg::*;    
  class bus_monitor_ctrl;
 
    local bus_config cfg; //puntero
    local mailbox #(bus_chk_pkt) child2ctrl;// todos los hijos al padre
    local mailbox #(bus_chk_pkt) mon2chk; // padre al checker
 
    local bus_monitor  mons [DRVRS];  // los hijos
    local int unsigned n_rx [DRVRS];  // paquetes reenviados, por dispo
 
    function new(virtual bus_if.MON vif_, mailbox #(bus_chk_pkt) mon2chk_); //constructor
      this.mon2chk = mon2chk_;
      cfg = bus_config::get();
      child2ctrl = new();
      for (int i = 0; i < DRVRS; i++) //creando un hijo monitor por cada dispositivo
        mons[i] = new(i, vif_, child2ctrl);
    endfunction
 
  
    local task forward_proc();//se envia cada paquete que envia cada hijo y se lo pasa al checker 
      bus_chk_pkt pkt;
      forever begin
        child2ctrl.get(pkt);
        if (pkt.destination < DRVRS) n_rx[pkt.destination]++;
        mon2chk.put(pkt);
        if (cfg.verbose) pkt.print("MON->CHK");
      end
    endtask
 
    task run(); //hace repetidamente la captura del dato de cada hijo 
      for (int i = 0; i < DRVRS; i++) mons[i].run(); 
      fork
        forward_proc();
      join_none
    endtask
 
   
    function void flush(); //resetea fifo out emulada si hay reset
      for (int i = 0; i < DRVRS; i++) mons[i].flush();
    endfunction
 
    function int unsigned total_rx();//contador de recepciones de dato
      int unsigned n = 0;
      for (int i = 0; i < DRVRS; i++) n += n_rx[i];
      return n;
    endfunction
 
    function void report(); //imprime el reporte
      for (int i = 0; i < DRVRS; i++)
        $display("bus_monitor[%0d] : paquetes vistos=%0d", i, n_rx[i]);
    endfunction
 
  endclass : bus_monitor_ctrl
 
endpackage : bus_monitor_ctrl_pkg