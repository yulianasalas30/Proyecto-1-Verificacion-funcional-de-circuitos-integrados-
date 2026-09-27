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

    local bus_config           cfg;
    local int unsigned         id;
    local virtual bus_if.MON   vif;
    local mailbox #(bus_chk_pkt) mon2chk;

    local bus_chk_pkt queue_out[$];    // emulacion de FIFO_out
    local int unsigned n_underflow;

    function new(int unsigned id_,
                         virtual bus_if.MON vif_,
                         mailbox #(bus_chk_pkt) mon2chk_);
      this.id     = id_;
      this.vif    = vif_;
      this.mon2chk = mon2chk_;
      cfg = bus_config::get();
    endfunction

    // ------------------------------------------------------------------
    // Proceso 1: observa push[id] cada ciclo y construye un paquete bus_chk_pkt que encola en queue_out
    // ------------------------------------------------------------------
    task capture_proc();
      bus_chk_pkt pkt;
      forever begin
        @(vif.cb_mon);
        if (vif.cb_mon.push[id]) begin  //si hay un push de este terminal, lo capturamos y lo encolamos en queue_out
          pkt              = new();
          pkt.destination  = id;
          pkt.packet_size  = PCKG_SZ;
          pkt.packet       = vif.cb_mon.D_push[id];
          pkt.receive_time = $time;

          queue_out.push_back(pkt);
          if (cfg.verbose) pkt.print("MON<-DUT");
        end
      end
    endtask

    // ------------------------------------------------------------------
    // Proceso 2: lee queue_out hacia el checker con un delay
    // configurable. Si la cola esta vacia al momento de leer, es
    // exactamente el caso esquina de underflow -- se loguea, NO se
    // trata como error del ambiente.
    // ------------------------------------------------------------------
    task read_proc();
      bus_chk_pkt pkt;
      forever begin
        repeat ($urandom_range(cfg.mon_max_delay, cfg.mon_min_delay)) @(vif.cb_mon); //cada intento de lectura, espera un delay random entre min y max

        if (queue_out.size() == 0) begin
          n_underflow++;
          if (cfg.verbose)
            //`INFO("MON", $sformatf("term=%0d intento de lectura con FIFO_out vacia (underflow)", id))
          continue;
        end

        pkt = queue_out.pop_front();
        mon2chk.put(pkt);
        if (cfg.verbose) pkt.print("MON->CHK");
      end
    endtask

    // Vacia la cola ante un reset (llamado por bus_env)
    function void flush();
      queue_out.delete();
      if (cfg.verbose)
        `INFO("MON", $sformatf("term=%0d FIFO_out vaciada por reset", id))
    endfunction

    function int unsigned underflow_count();
      return n_underflow;
    endfunction

    task run();
      fork
        capture_proc();
        read_proc();
      join_none  //no esperamos a que terminen
    endtask

  endclass : bus_monitor

endpackage : bus_monitor_pkg