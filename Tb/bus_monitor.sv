package bus_monitor_pkg;

  import bus_params_pkg::*;  //para PCKG_SZ
  import bus_config_pkg::*;  //para .verbose

  // Paquete "Monitor -> Checker" del testplan
  class bus_chk_pkt;
    int unsigned         destination;   // = id de esta instancia
    int unsigned         packet_size;   // = PCKG_SZ
    bit [PCKG_SZ-1:0]    packet;        //id + data
    int unsigned         receive_time;  // = $time cuando se observo el push

    function void print(string tag = "OBS_PKT");
      $display("[%0t] [%-8s] dst=%0d size=%0d packet=%h receive_time=%0d",
                $time, tag, destination, packet_size, packet, receive_time);
    endfunction
  endclass : bus_chk_pkt

  
  // El monitor
  
  class bus_monitor;

    local bus_config cfg;
    local int unsigned  id;
    local virtual bus_if.MON vif;
    local mailbox #(bus_chk_pkt) to_ctrl; // mailbox hacia el monitor padre

    local bus_chk_pkt queue_out[$];    // emulacion de FIFO_out

    function new(int unsigned id_,
                         virtual bus_if.MON vif_,
                         mailbox #(bus_chk_pkt) to_ctrl_);
      this.id= id_;
      this.vif= vif_;
      this.to_ctrl = to_ctrl_;
      cfg = bus_config::get();
    endfunction


    task capture_proc();
      bus_chk_pkt pkt;
      forever begin
        @(vif.cb_mon);
        if (vif.cb_mon.push[id]) begin
          pkt              = new();
          pkt.destination  = id;
          pkt.packet_size  = PCKG_SZ;
          pkt.packet       = vif.cb_mon.D_push[id];
          pkt.receive_time = $time;
 
          queue_out.push_back(pkt);  // la FIFO_out solo se llena
          to_ctrl.put(pkt);   // y el paquete sigue su camino
          if (cfg.verbose) pkt.print("MON<-DUT");
        end
      end
    endtask
 
    // Cuantos paquetes ha visto esta terminal desde el ultimo reset
    function int unsigned received();
      return queue_out.size();
    endfunction
 
    // Vacia el registro ante un reset (lo llama el padre)
    function void flush();
      queue_out.delete();
      if (cfg.verbose)
        `INFO("MON", $sformatf("term=%0d FIFO_out vaciada por reset", id))
    endfunction
 
    task run();
      fork
        capture_proc();
      join_none  //no esperamos a que termine
    endtask
 
  endclass : bus_monitor
 
endpackage : bus_monitor_pkg