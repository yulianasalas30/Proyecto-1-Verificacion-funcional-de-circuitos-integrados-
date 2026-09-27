//======================================================================
// bus_driver.sv
//----------------------------------------------------------------------
// 

//======================================================================
package bus_driver_pkg;

  import bus_config_pkg::*;  //para .verbose  
  import bus_agent_pkg::*;   // para bus_drv_pkt

  class bus_driver;

    local bus_config             cfg;
    local int unsigned           id;        // terminal que esta instancia maneja
    local virtual bus_if.DRV     vif;
    local mailbox #(bus_drv_pkt) agt2drv;   // SOLO el mailbox de ESTA terminal

    local bus_drv_pkt queue_in[$];          // emulacion de FIFO_in

    function new(int unsigned id_, virtual bus_if.DRV vif_, mailbox #(bus_drv_pkt) agt2drv_);
      
      this.id     = id_;
      this.vif    = vif_;
      this.agt2drv = agt2drv_;
      cfg    = bus_config::get();
    endfunction

    // ------------------------------------------------------------------
    // Proceso 1: Escucha al agente y encola los paquetes que le llegan
    // ------------------------------------------------------------------
    task receive_proc();
      bus_drv_pkt pkt;
      forever begin
        agt2drv.get(pkt); //espera a que el agente le mande un paquete para esta terminal
        repeat (pkt.send_time) @(vif.cb_drv);  //espera el tiempo de envio indicado por el agente

        queue_in.push_back(pkt);
        if (cfg.verbose)
          `INFO("DRV", $sformatf("term=%0d encolado, FIFO_in size=%0d",
                                  id, queue_in.size()))
      end
    endtask

    // ------------------------------------------------------------------
    // Proceso 2: maneja las señales fisicas hacia el DUT cada ciclo.
    // ------------------------------------------------------------------
    task drive_proc();
      forever begin
        @(vif.cb_drv);
        vif.cb_drv.pndng[id] <= (queue_in.size() != 0); //si la cola tiene algo, pndng=1, sino pndng=0
        vif.cb_drv.D_pop[id] <= (queue_in.size() != 0) ? queue_in[0].packet : '0; //igual el dut no deberia leer el 0 

        
        if (vif.cb_drv.pop[id]) begin //el dut confirma con pop=1 que leyo el paquete, entonces lo desencolamos
          if (cfg.verbose)
            `INFO("DRV", $sformatf("term=%0d pop detectado, desencolando", id))
          void'(queue_in.pop_front()); //el void es para descartar el valor retornado por pop_front()
        end
      end
    endtask

    // ------------------------------------------------------------------
    // Vacia la cola ante un reset (llamado por bus_env cuando detecta reset activo).
    // ------------------------------------------------------------------
    function void flush();
      queue_in.delete();  //la vacia por completo
      if (cfg.verbose)
        `INFO("DRV", $sformatf("term=%0d FIFO_in vaciada por reset", id))
    endfunction

    
    task run();
      fork
        receive_proc();
        drive_proc();
      join_none  //no esperamos a que terminen
    endtask

  endclass : bus_driver

endpackage : bus_driver_pkg