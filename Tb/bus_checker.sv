package bus_checker_pkg;

  import bus_config_pkg::*; //para .verbose
  import bus_monitor_pkg::*; //para bus_chk_pkt
  import bus_scoreboard_pkg::*;  //para la clase bus_scoreboard y accede a un a find_and_pop()

  typedef struct {
    int unsigned source;
    int unsigned destination;
    int unsigned packet_size;
    int unsigned send_time;
    int unsigned receive_time;
    int unsigned latency;
  } bus_match_record_t;

  class bus_checker;

    local bus_config             cfg;
    local int unsigned           id;
    local mailbox #(bus_chk_pkt) mon2chk; 
    local bus_scoreboard         sb;

    local bus_match_record_t history[$]; 
    local int unsigned n_match; // cantidad de paquetes que hicieron match
    local int unsigned n_unexpected;  // cantidad de paquetes que llegaron al checker pero no estaban en la cola de paquetes esperados

    function new(int unsigned id_, mailbox #(bus_chk_pkt) mon2chk_, bus_scoreboard sb_);
      this.id      = id_;
      this.mon2chk = mon2chk_;
      this.sb      = sb_;
      cfg = bus_config::get();
    endfunction

    task run();
      bus_chk_pkt o;
      bus_sb_pkt  e;
      forever begin
        mon2chk.get(o); //espera a que el monitor le mande un paquete observado

        if (!sb.find_and_pop(o, e)) begin //si no son iguales, el paquete observado no estaba en la cola de paquetes esperados
          n_unexpected++;
          `ERR("CHK", $sformatf("term=%0d paquete SIN esperado (packet=%0h)", id, o.packet))
        end else begin
          bus_match_record_t rec;
          rec.source       = e.source;
          rec.destination  = o.destination;
          rec.packet_size  = o.packet_size;
          rec.send_time    = e.send_time;
          rec.receive_time = o.receive_time;
          rec.latency      = o.receive_time - e.send_time;
          history.push_back(rec);  //guardamos el registro de match en la historia
          n_match++;
          if (cfg.verbose)
            `INFO("CHK", $sformatf("term=%0d MATCH src=%0d latency=%0d", id, e.source, rec.latency))
        end
      end
    endtask

    function void report();
      $display("bus_checker[%0d] : matches=%0d  unexpected=%0d  sin_recibir=%0d",
                id, n_match, n_unexpected, sb.pending_count());
      if (sb.pending_count() != 0) sb.print_pending();
    endfunction

    function int unsigned fail_count();
      return n_unexpected + sb.pending_count();
    endfunction

    function void export_csv(int fd);
      foreach (history[i])
        $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                  id, history[i].source, history[i].destination,
                  history[i].packet_size, history[i].send_time,
                  history[i].receive_time, history[i].latency);
    endfunction

  endclass : bus_checker

endpackage : bus_checker_pkg