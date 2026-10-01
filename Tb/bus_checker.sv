package bus_checker_pkg;
 
  import bus_params_pkg::*;     // DRVRS
  import bus_config_pkg::*;
  import bus_monitor_pkg::*;    // bus_chk_pkt que es el que proviene del monitor 
  import bus_scoreboard_pkg::*;
  import bus_agent_pkg::*;      // bus_sb_pkt del scoreboard
 
  typedef struct {
    int unsigned source;
    int unsigned destination;
    int unsigned packet_size;
    int unsigned send_time;
    int unsigned receive_time;
    int unsigned latency;
  } bus_match_record_t;
 
  class bus_checker;
 
    local bus_config cfg;
    local mailbox #(bus_chk_pkt) mon2chk; // unico mailbox desde el monitor padre
    local bus_scoreboard sb; 
 
    local bus_match_record_t history[$]; 
 
    // Contadores POR TERMINAL (el indice es el dispositivo destino)
    local int unsigned n_match [DRVRS];
    local int unsigned n_unexpected [DRVRS];
    local int unsigned n_bad_term; // paquetes con terminal fuera de rango
 
    function new(mailbox #(bus_chk_pkt) mon2chk_, bus_scoreboard sb_); //recibe mailbox de monitor y el dato del scoreboar
      this.mon2chk = mon2chk_;
      this.sb = sb_;
      cfg = bus_config::get();
    endfunction
 
    
    task run();
      fork
        begin
          bus_chk_pkt o;
          bus_sb_pkt  e;
          forever begin
            mon2chk.get(o);
            if (o.destination >= DRVRS) begin //por si no existe el dispositivo
              n_bad_term++;
              `ERR("CHK", $sformatf("paquete con terminal fuera de rango (%0d)", o.destination))
              continue;
            end
 
            if (!sb.find_and_pop(o, e)) begin //si no se encontro el dato en el scoreboard
              n_unexpected[o.destination]++;
              `ERR("CHK", $sformatf("term=%0d paquete SIN esperado (packet=%0h)",
                                    o.destination, o.packet))
            end else begin //si se encontro el dato en el scoreboard 
              bus_match_record_t rec;
              rec.source = e.source;
              rec.destination = o.destination;
              rec.packet_size = o.packet_size;
              rec.send_time = e.send_time;
              rec.receive_time = o.receive_time;
              rec.latency = o.receive_time - e.send_time;
              history.push_back(rec); //seva guardando un historial de lo que si se encontro 
              n_match[o.destination]++; //contador que me indica si el dato llego correctamente 
              if (cfg.verbose)
                `INFO("CHK", $sformatf("term=%0d MATCH src=%0d latency=%0d",
                  o.destination, e.source, rec.latency))
            end
          end
        end
      join_none
    endtask
 
   
    function void flush();
    endfunction
 
    
    function int unsigned total_match(); //contador de que si llego el dato 
      int unsigned n = 0;
      for (int t = 0; t < DRVRS; t++) n += n_match[t];
      return n;
    endfunction
 
    function int unsigned total_unexpected(); //contador de que no llego el dato
      int unsigned n = 0;
      for (int t = 0; t < DRVRS; t++) n += n_unexpected[t];
      return n;
    endfunction
 
    
    function void report(); //funcion que imprime los resultados
      for (int t = 0; t < DRVRS; t++)
        $display("bus_checker[%0d] : matches=%0d  unexpected=%0d  sin_recibir=%0d",
                  t, n_match[t], n_unexpected[t], sb.pending_count_of(t));
      $display("bus_checker TOTAL : matches=%0d  unexpected=%0d  sin_recibir=%0d  term_invalida=%0d",
                total_match(), total_unexpected(), sb.pending_count(), n_bad_term);
      if (sb.pending_count() != 0) sb.print_pending();
    endfunction
 
    function int unsigned fail_count(); 
      return total_unexpected() + n_bad_term + sb.pending_count();
    endfunction
 
    
    function void export_csv(int fd); //creacion del csv para conocer paquetes 
      foreach (history[i])
        $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                  history[i].destination, history[i].source, history[i].destination,
                  history[i].packet_size, history[i].send_time,
                  history[i].receive_time, history[i].latency);
    endfunction
 
  endclass : bus_checker
 
endpackage : bus_checker_pkg