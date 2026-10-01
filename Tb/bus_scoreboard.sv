// 1 scoreboard para todo el ambiente.
// Guarda los paquetes provenientes del agente en un arreglo de colas

package bus_scoreboard_pkg; //paquete que me ayudara a llamar el scoreboard

  import bus_params_pkg::*;//porque necesito drvers
  import bus_config_pkg::*;
  import bus_agent_pkg::*;  
  import bus_monitor_pkg::*; 



  class bus_scoreboard;
    local bus_config cfg;
    local mailbox #(bus_sb_pkt) agt2sb;
    local bus_sb_pkt exp_q [DRVRS][$]; //arreglo de colas que tendra la misma cantidad que dispositivos 

    function new(mailbox #(bus_sb_pkt) agt2sb_); //constructor de la clase que solo recibe el mailbox
      this.agt2sb = agt2sb_;
      cfg = bus_config::get(); //saco el mailobox
    endfunction

    task run(); //el run siempre corre y por ende esta siempre recibiendo el mailbox y lo coloca en la cola respectiva
      fork
        begin
          bus_sb_pkt e;
          forever begin
            agt2sb.get(e);
            if (e.destination < DRVRS) begin //si el destino existe, destination se encuentra en el mailbox
              exp_q[e.destination].push_back(e); //lo guarda en la cola respectiva del dispositivo
              if (cfg.verbose) e.print($sformatf("SB,cola[%0d]<-AGT", e.destination)); //imprime que se guardo en la cola 
            end
            else begin
              `ERR("SB", $sformatf("esperado con destino fuera de rango (%0d)", e.destination))//si mandan un dato a un dispositivo inexistente
            end
          end
        end
      join_none
    endtask

    function bit find_and_pop(bus_chk_pkt o, output bus_sb_pkt e); //para asegurarnos de que el checker si verifique bien, debemos leer toda la cola
      int unsigned t;
      t = o.destination;

      if (t >= DRVRS) return 0;//caundo no existe el dispositivo

      for (int i = 0; i <exp_q[t].size(); i++) begin //va comparando cada dato de la cola respectiva con el dato que el monitor le entrego al chekcer 
        if (exp_q[t][i].packet ==o.packet &&
            exp_q[t][i].packet_size == o.packet_size) begin
          e = exp_q[t][i];
          exp_q[t].delete(i); //se elimina de la cola si el dato coincide con el que se busca
          return 1;
        end
      end
      return 0;
    endfunction

    
    function int unsigned pending_count(); //contador que nos dice cuantos quedan pendientes en las colas que no se han leido 
      int unsigned n = 0;
      for (int t = 0; t < DRVRS; t++) n += exp_q[t].size();
      return n;
    endfunction

    // Lo mismo, pero solo de una terminal para reportar por teminal
    function int unsigned pending_count_of(int unsigned t);
      if (t >= DRVRS) return 0;
      return exp_q[t].size();
    endfunction

    function void print_pending();//nada mas muestra en consola si nunca se llego a sacar ese dato 
      for (int t = 0; t < DRVRS; t++)
        for (int i = 0; i < exp_q[t].size(); i++)
          exp_q[t][i].print($sformatf("SB[%0d] unresolved", t));
    endfunction

    // Vacia todas las colas.
    function void flush();
      for (int t = 0; t < DRVRS; t++) exp_q[t].delete();
    endfunction

  endclass : bus_scoreboard

endpackage : bus_scoreboard_pkg