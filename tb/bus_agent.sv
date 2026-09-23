//======================================================================
// bus_agent.sv
//----------------------------------------------------------------------
//======================================================================
package bus_agent_pkg;

  import bus_params_pkg::*;
  import bus_config_pkg::*;
  import bus_txn_pkg::*;

  // ------------------------------------------------------------------
  // Tabla "Agente -> Driver"
  // ------------------------------------------------------------------
  class bus_drv_pkt;
    int unsigned          terminal;    
    int unsigned          packet_size;  
    bit [PCKG_SZ-1:0]     packet;       
    int unsigned          send_time;

    function void print(string tag = "DRV_PKT");
      $display("[%0t] [%-8s] terminal=%0d size=%0d packet=%h send_time=%0d",
                $time, tag, terminal, packet_size, packet, send_time);
    endfunction
  endclass : bus_drv_pkt

  // ------------------------------------------------------------------
  // Tabla "Agente -> Scoreboard"
  // ------------------------------------------------------------------
  class bus_sb_pkt;
    int unsigned          source;
    int unsigned          destination;  
    int unsigned          packet_size;
    bit [PCKG_SZ-1:0]     packet;
    int unsigned          send_time;

    function void print(string tag = "SB_PKT");
      $display("[%0t] [%-8s] src=%0d dst=%0d size=%0d packet=%h send_time=%0d",
                $time, tag, source, destination, packet_size, packet, send_time);
    endfunction
  endclass : bus_sb_pkt

  // ------------------------------------------------------------------
  // El agente
  // ------------------------------------------------------------------
  class bus_agent;

    local bus_config cfg;

    mailbox #(bus_txn)      gen2agt;          
    mailbox #(bus_drv_pkt)  agt2drv[];       
    mailbox #(bus_sb_pkt)   agt2sb [];        

    function new(mailbox #(bus_txn)     gen2agt_,
                 mailbox #(bus_drv_pkt) agt2drv_[],
                 mailbox #(bus_sb_pkt)  agt2sb_ []);
      this.gen2agt = gen2agt_;
      this.agt2drv = agt2drv_;
      this.agt2sb  = agt2sb_;
      cfg = bus_config::get();
    endfunction

    // ------------------------------------------------------------------
    // Empaca un bus_txn en su bus_drv_pkt correspondiente
    // ------------------------------------------------------------------
    function bus_drv_pkt to_drv_pkt(bus_txn txn);
      bus_drv_pkt dp = new();
      dp.terminal    = txn.source;
      dp.packet_size = txn.packet_size;
      dp.packet      = {txn.destination[ADDR_W-1:0], txn.data};
      dp.send_time   = txn.send_time;
      return dp;
    endfunction

    function bus_sb_pkt to_sb_pkt(bus_txn txn, int unsigned dest,
                                   bit [PCKG_SZ-1:0] packed_packet);
      bus_sb_pkt sp = new();
      sp.source      = txn.source;
      sp.destination = dest;
      sp.packet_size = txn.packet_size;
      sp.packet      = packed_packet;
      sp.send_time   = txn.send_time;
      return sp;
    endfunction

    // ------------------------------------------------------------------
    task run();
      bus_txn     txn;
      bus_drv_pkt dp;

      forever begin
        gen2agt.get(txn);
        if (cfg.verbose) txn.print("AGT<-GEN");

        dp = to_drv_pkt(txn);
        agt2drv[txn.source].put(dp);

        

        case (txn.dest_cat)
          DEST_BCAST: begin
            // Copia esperada hacia CADA terminal (todas deben recibir).
            foreach (agt2sb[j])
              agt2sb[j].put(to_sb_pkt(txn, j, dp.packet));
          end
          DEST_VALID: begin
            agt2sb[txn.destination].put(to_sb_pkt(txn, txn.destination, dp.packet));
          end
          DEST_INVALID: begin
           
            if (cfg.verbose)
              `INFO("AGT", $sformatf("destino invalido %0d, sin receptor esperado",
                                      txn.destination))
          end
        endcase
      end
    endtask

  endclass : bus_agent

endpackage : bus_agent_pkg
