package bus_checker_pkg;

  import bus_config_pkg::*;
  import bus_monitor_pkg::*;
  import bus_scoreboard_pkg::*;
  import bus_agent_pkg::*;

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
    local int unsigned n_match;
    local int unsigned n_unexpected;

    function new(int unsigned id_, mailbox #(bus_chk_pkt) mon2chk_, bus_scoreboard sb_);
      this.id      = id_;
      this.mon2chk = mon2chk_;
      this.sb      = sb_;
      cfg = bus_config::get();
    endfunction

    task run();
      fork
        begin
          bus_chk_pkt o;
          bus_sb_pkt  e;
          forever begin
            mon2chk.get(o);

            if (!sb.find_and_pop(o, e)) begin
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
              history.push_back(rec);
              n_match++;
              if (cfg.verbose)
                `INFO("CHK", $sformatf("term=%0d MATCH src=%0d latency=%0d", id, e.source, rec.latency))
            end
          end
        end
      join_none
    endtask

    function void flush();
    endfunction

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