//======================================================================
// bus_driver.sv
//----------------------------------------------------------------------
// Unidad de compilacion propia (paquete). Debe compilarse DESPUES de
// bus_params_pkg.sv, bus_config.sv, bus_agent.sv (importa bus_drv_pkt)
// y bus_if.sv.
//
// Una instancia de bus_driver por terminal (bus_env crea DRVRS de
// estas). Cada instancia:
//   - Es DUEÑA de la emulacion de FIFO_in de su terminal (una cola SV,
//     bus_drv_pkt queue_in[$]), con profundidad cfg.depth_in.
//   - Recibe bus_drv_pkt del agente por SU PROPIO mailbox (agt2drv[id],
//     ya indexado por bus_env antes de pasarselo a esta clase).
//   - Maneja pndng[id]/D_pop[id] hacia el DUT, y observa pop[id] para
//     saber cuando el DUT ya consumio el dato (ver discusion de
//     clocking blocks: pop puede tardar varios ciclos en pulsar,
//     porque hay arbitraje + serializacion de por medio).
//
// Politica de FIFO_in: cola SIN limite de capacidad (infinita) -- no
// hay backpressure ni descarte de datos del lado de entrada. Decision
// explicita para simplificar el ambiente; ver nota mas abajo sobre la
// tension con el caso esquina "FIFO de entrada llena" del testplan.
//
// NO maneja reset en absoluto: bus_env lo controla directamente via su
// propio modport ENV en bus_if.sv (cb_env), sin pasar por ninguna
// instancia de bus_driver. Cuando bus_env detecta o aplica un reset,
// llama flush() en cada instancia para vaciar su cola.
//======================================================================
package bus_driver_pkg;

  import bus_params_pkg::*;
  import bus_config_pkg::*;
  import bus_agent_pkg::*;   // bus_drv_pkt

  class bus_driver;

    local bus_config             cfg;
    local int unsigned           id;        // terminal que esta instancia maneja
    local virtual bus_if.DRV     vif;
    local mailbox #(bus_drv_pkt) agt2drv;   // SOLO el mailbox de ESTA terminal

    local bus_drv_pkt queue_in[$];          // emulacion de FIFO_in

    function new();
      cfg = bus_config::get();
    endfunction

    // bus_env llama esto una vez por instancia, pasandole su id y el
    // mailbox correspondiente (ya indexado: agt2drv[id] del agente).
    function void build(int unsigned id_,
                         virtual bus_if.DRV vif_,
                         mailbox #(bus_drv_pkt) agt2drv_);
      this.id      = id_;
      this.vif     = vif_;
      this.agt2drv = agt2drv_;
    endfunction

    // ------------------------------------------------------------------
    // Proceso 1: recibe del agente y encola en FIFO_in (con backpressure
    // si esta llena).
    // ------------------------------------------------------------------
    task receive_proc();
      bus_drv_pkt pkt;
      forever begin
        agt2drv.get(pkt);

        // send_time = ciclos de espera desde la ULTIMA transaccion de
        // esta terminal (ver bus_txn.sv). Se espera ANTES de intentar
        // encolar, no antes de recibir del mailbox.
        repeat (pkt.send_time) @(vif.cb_drv);

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

        // Publicar el estado ACTUAL de la cola (antes de reaccionar a
        // un posible pop de este mismo flanco, ya que #1step ya
        // capturo el pop del DUT correspondiente al dato ya expuesto).
        vif.cb_drv.pndng[id] <= (queue_in.size() != 0);
        vif.cb_drv.D_pop[id] <= (queue_in.size() != 0) ? queue_in[0].packet : '0;

        // El DUT confirma que tomo el dato -> recien ahora se saca de
        // la cola. cb_drv.pop es input (#1step), asi que ya viene
        // estable de ANTES de este flanco.
        if (vif.cb_drv.pop[id]) begin
          if (cfg.verbose)
            `INFO("DRV", $sformatf("term=%0d pop detectado, desencolando", id))
          void'(queue_in.pop_front());
        end
      end
    endtask

    // ------------------------------------------------------------------
    // Vacia la cola ante un reset (llamado por bus_env cuando detecta
    // reset activo -- ver Decision 2 mas arriba).
    // ------------------------------------------------------------------
    function void flush();
      queue_in.delete();
      if (cfg.verbose)
        `INFO("DRV", $sformatf("term=%0d FIFO_in vaciada por reset", id))
    endfunction

    // Lanza los dos procesos de esta instancia. bus_env hace esto
    // dentro de su propio fork...join_none, una vez por terminal.
    task run();
      fork
        receive_proc();
        drive_proc();
      join_none
    endtask

  endclass : bus_driver

endpackage : bus_driver_pkg