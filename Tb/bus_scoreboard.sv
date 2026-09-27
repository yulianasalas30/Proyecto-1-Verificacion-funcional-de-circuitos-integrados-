package bus_scoreboard_pkg;

  import bus_config_pkg::*; //para .verbose
  import bus_agent_pkg::*;  // para bus_sb_pkt
  import bus_monitor_pkg::*;  //para bus_chk_pkt

  class bus_scoreboard;

    local bus_config            cfg;
    local int unsigned          id;
    local mailbox #(bus_sb_pkt) agt2sb;
    local bus_sb_pkt            exp_q[$];  //cola de paquetes esperados, aun sin recibir

    function new(int unsigned id_, mailbox #(bus_sb_pkt) agt2sb_);
      this.id     = id_;
      this.agt2sb = agt2sb_;
      cfg = bus_config::get();
    endfunction

    task run();
      bus_sb_pkt e;
      forever begin
        agt2sb.get(e);
        exp_q.push_back(e);
        if (cfg.verbose) e.print($sformatf("SB%0d<-AGT", id));
      end
    endtask

    function bit find_and_pop(bus_chk_pkt o, output bus_sb_pkt e); // si bit es 1, devuelve en e el paquete esperado
      foreach (exp_q[i])
        if (exp_q[i].packet == o.packet && exp_q[i].packet_size == o.packet_size) begin  // si lo encontramos, lo sacamos de la cola y devolvemos 1
          e = exp_q[i];
          exp_q.delete(i);
          return 1;
        end
      return 0;
    endfunction

    // devuelve la cantidad de paquetes esperados aun sin recibir

    function int unsigned pending_count(); 
      return exp_q.size();
    endfunction

    function void print_pending();
      foreach (exp_q[i]) exp_q[i].print($sformatf("SB%0d unresolved", id));
    endfunction

    function void flush();
      exp_q.delete();
    endfunction

  endclass : bus_scoreboard

endpackage : bus_scoreboard_pkg