package bus_env_pkg;
 
  import bus_params_pkg::*;
  import bus_config_pkg::*;
  import bus_txn_pkg::*;
  import bus_generator_pkg::*;
  import bus_agent_pkg::*;
  import bus_driver_pkg::*;
  import bus_monitor_pkg::*;
  import bus_monitor_ctrl_pkg::*;
  import bus_scoreboard_pkg::*;
  import bus_checker_pkg::*;
 
  class bus_env;
 
    local bus_config      cfg;
    local virtual bus_if   vif;
 
    bus_generator     gen;
    bus_agent         agt;
    bus_driver        drv[];     // uno por terminal
    bus_monitor_ctrl  mon;       // monitor PADRE (contiene los hijos, uno por terminal)
    bus_scoreboard    sb;        // uno solo (una cola por terminal adentro)
    bus_checker       chk;       // uno solo
 
    mailbox #(bus_txn)     gen2agt;
    mailbox #(bus_drv_pkt) agt2drv[];   // uno por terminal
    mailbox #(bus_sb_pkt)  agt2sb;      // unico
    mailbox #(bus_chk_pkt) mon2chk;     // unico
 
    function new();
      cfg = bus_config::get();
    endfunction
 
    function void connect(virtual bus_if vif_);
      this.vif = vif_;
    endfunction
 
    function void build();
      gen2agt = new();
      agt2drv = new[DRVRS];
      agt2sb  = new();
      mon2chk = new();
 
      drv = new[DRVRS];
 
      foreach (agt2drv[i]) agt2drv[i] = new();
 
      gen = new(gen2agt);
      agt = new(gen2agt, agt2drv, agt2sb);
 
      foreach (drv[i]) begin
        drv[i] = new(i, vif, agt2drv[i]);
      end
 
      mon = new(vif, mon2chk);     // crea adentro los DRVRS monitores hijos
      sb  = new(agt2sb);
      chk = new(mon2chk, sb);
    endfunction
 
    task apply_reset();
      vif.cb_env.reset <= 1'b1;
      repeat (cfg.reset_cycles) @(vif.cb_env);
      vif.cb_env.reset <= 1'b0;
      @(vif.cb_env);
      if (cfg.verbose) `INFO("ENV", "reset inicial completo")
    endtask
 
    task mid_resets();
      repeat (cfg.n_mid_resets) begin
        repeat ($urandom_range(cfg.max_delay, cfg.min_delay)) @(vif.cb_env);
 
        if (cfg.verbose) `INFO("ENV", "aplicando reset a mitad de simulacion")
        vif.cb_env.reset <= 1'b1;
        repeat (cfg.mid_reset_len) @(vif.cb_env);
        vif.cb_env.reset <= 1'b0;
 
        foreach (drv[i]) drv[i].flush();
        mon.flush();
        sb.flush();
        chk.flush();
      end
    endtask
 
    task watchdog();
      repeat (cfg.timeout) @(vif.cb_env);
      `ERR("ENV", "TIMEOUT: la simulacion no completo a tiempo")
      $finish;
    endtask
 
    function void final_report();
      int unsigned total_fail = 0;
      int fd;
 
      fd = $fopen("bus_results.csv", "w");
      $fdisplay(fd, "terminal,source,destination,packet_size,send_time,receive_time,latency");
 
      mon.report();
      chk.report();
      chk.export_csv(fd);
      total_fail = chk.fail_count();
 
      $fclose(fd);
 
      $display("==========================================================");
      if (total_fail == 0)
        $display(" bus_env : RESULTADO GLOBAL = PASS");
      else
        $display(" bus_env : RESULTADO GLOBAL = FAIL  (%0d fallas totales)", total_fail);
      $display(" resultados exportados a bus_results.csv");
      $display("==========================================================");
    endfunction
 
    task run();
      cfg.print();
 
      apply_reset();
 
      fork
        agt.run();
        foreach (drv[i]) drv[i].run();
        mon.run();
        sb.run();
        chk.run();
        mid_resets();
        watchdog();
      join_none
 
      gen.run();
 
      if (cfg.verbose) `INFO("ENV", "generacion completa, esperando FIFO_in vacias")
      begin
        bit all_empty;
        do begin
          all_empty = 1;
          foreach (drv[i]) if (drv[i].pending_count() != 0) all_empty = 0;
          if (!all_empty) @(vif.cb_env);
        end while (!all_empty);
      end
 
      if (cfg.verbose) `INFO("ENV", "drenando")
      repeat (cfg.drain_cycles) @(vif.cb_env);
 
      final_report();
      $finish;
    endtask
 
  endclass : bus_env
 
endpackage : bus_env_pkg