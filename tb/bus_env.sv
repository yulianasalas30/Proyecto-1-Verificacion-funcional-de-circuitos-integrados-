//======================================================================
// bus_env.sv
//----------------------------------------------------------------------
// 
//======================================================================
package bus_env_pkg;

  import bus_params_pkg::*;
  import bus_config_pkg::*;
  import bus_txn_pkg::*;
  import bus_generator_pkg::*;
  import bus_agent_pkg::*;
  import bus_driver_pkg::*;
  import bus_monitor_pkg::*;
  import bus_scoreboard_pkg::*;
  import bus_checker_pkg::*;

  class bus_env;

    local bus_config      cfg;
    local virtual bus_if   vif;  

    bus_generator  gen;
    bus_agent      agt;
    bus_driver     drv[];         // dinamico, tamano DRVRS
    bus_monitor    mon[];
    bus_scoreboard sb [];
    bus_checker    chk[];

    mailbox #(bus_txn)     gen2agt;
    mailbox #(bus_drv_pkt) agt2drv[];
    mailbox #(bus_sb_pkt)  agt2sb [];   
    mailbox #(bus_chk_pkt) mon2chk [];  

    function new();
      cfg = bus_config::get();
    endfunction

    
    function void connect(virtual bus_if vif_);
      this.vif = vif_;
    endfunction

    // Crea todos los mailboxes y componentes, y los conecta entre si.
    function void build();
      gen2agt = new();
      agt2drv = new[DRVRS];
      agt2sb  = new[DRVRS];
      mon2chk  = new[DRVRS];

      drv = new[DRVRS];
      mon = new[DRVRS];
      sb  = new[DRVRS];
      chk = new[DRVRS];

      foreach (agt2drv[i]) agt2drv[i] = new();
      foreach (agt2sb[i])  agt2sb[i]  = new();
      foreach (mon2chk[i]) mon2chk[i] = new();

      gen = new(gen2agt);
      agt = new(gen2agt, agt2drv, agt2sb);

      foreach (drv[i]) begin
        drv[i] = new(i, vif, agt2drv[i]);
      end

      foreach (mon[i]) begin
        mon[i] = new(i, vif, mon2chk[i]);
      end

      foreach (sb[i]) begin
        sb[i] = new(i, agt2sb[i]);
      end

      foreach (chk[i]) begin
        chk[i] = new(i, mon2chk[i], sb[i]);
      end
    endfunction

    // ------------------------------------------------------------------
    // Reset inicial. SOLO bus_env toca vif.cb_env.reset -- ninguna
    // instancia de bus_driver/bus_monitor lo hace (ver discusion en el
    // chat: con M instancias no tiene sentido que cada una controle
    // reset por su cuenta).
    // ------------------------------------------------------------------
    task apply_reset();
      vif.cb_env.reset <= 1'b1;
      repeat (cfg.reset_cycles) @(vif.cb_env);
      vif.cb_env.reset <= 1'b0;
      @(vif.cb_env);
      if (cfg.verbose) `INFO("ENV", "reset inicial completo")
    endtask

    // Caso esquina "reset con transacciones pendientes en alguna FIFO":
    // aplica cfg.n_mid_resets resets adicionales en momentos aleatorios
    // durante la simulacion, y vacia las colas/estado de cada
    // componente despues de cada uno (el scoreboard no guarda estado
    // propio, pero se llama igual por si eso cambia mas adelante).
    task mid_resets();
      repeat (cfg.n_mid_resets) begin
        repeat ($urandom_range(cfg.max_delay, cfg.min_delay)) @(vif.cb_env);

        if (cfg.verbose) `INFO("ENV", "aplicando reset a mitad de simulacion")
        vif.cb_env.reset <= 1'b1;
        repeat (cfg.mid_reset_len) @(vif.cb_env);
        vif.cb_env.reset <= 1'b0;

        foreach (drv[i]) drv[i].flush();
        foreach (mon[i]) mon[i].flush();
        foreach (sb[i])  sb[i].flush();
      end
    endtask

    // Fuerza el fin de la simulacion si nadie mas lo hizo antes de
    // cfg.timeout ciclos -- protege contra quedarse colgado por un
    // mailbox que nunca recibe su .put() esperado.
    task watchdog();
      repeat (cfg.timeout) @(vif.cb_env);
      `ERR("ENV", "TIMEOUT: la simulacion no completo a tiempo")
      $finish;
    endtask

    // ------------------------------------------------------------------
    // Reporte final: cada checker imprime su resumen, se exporta un
    // solo CSV con el historial de matches de las M terminales, y se
    // decide PASS/FAIL global sumando fail_count().
    // ------------------------------------------------------------------
    function void final_report();
      int unsigned total_fail = 0;
      int fd;

      fd = $fopen("bus_results.csv", "w");
      $fdisplay(fd, "terminal,source,destination,packet_size,send_time,receive_time,latency");

      foreach (chk[i]) begin
        chk[i].report();
        chk[i].export_csv(fd);
        total_fail += chk[i].fail_count();
      end

      $fclose(fd);

      $display("==========================================================");
      if (total_fail == 0)
        $display(" bus_env : RESULTADO GLOBAL = PASS");
      else
        $display(" bus_env : RESULTADO GLOBAL = FAIL  (%0d fallas totales)", total_fail);
      $display(" resultados exportados a bus_results.csv");
      $display("==========================================================");
    endfunction

    // ------------------------------------------------------------------
    task run();
      cfg.print();

      apply_reset();

      
      
      fork
        agt.run();
        foreach (drv[i]) drv[i].run();
        foreach (mon[i]) mon[i].run();
        foreach (sb[i])  sb[i].run();
        foreach (chk[i]) chk[i].run();
        mid_resets();
        watchdog();
      join_none

      
      gen.run();

      if (cfg.verbose) `INFO("ENV", "generacion completa, drenando")
      repeat (cfg.drain_cycles) @(vif.cb_env);

      final_report();
      $finish;
    endtask

  endclass : bus_env

endpackage : bus_env_pkg