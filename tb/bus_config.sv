//======================================================================
// bus_config.sv
//----------------------------------------------------------------------
// 
//======================================================================
package bus_config_pkg;

  class bus_config;

    //--------------------------------------------------------------------
    // 1) Knobs de nivel de test
    //--------------------------------------------------------------------
    int unsigned n_txn_min     = 20;    // +n_txn_min=   transacciones MINIMAS por terminal
    int unsigned n_txn_max     = 50;    // +n_txn_max=   transacciones MAXIMAS por terminal
    int unsigned reset_cycles  = 5;     // +reset_cycles=  duracion del reset inicial
    int unsigned drain_cycles  = 50;    // +drain_cycles=  ciclos de idle al final del test
    int unsigned timeout       = 200000;// +timeout=       watchdog, en ciclos de reloj
    int unsigned verbose       = 0;     // +verbose=1      imprime cada transaccion

    //--------------------------------------------------------------------
    // 2) Reset a mitad de simulacion (caso esquina: "reset con
    //    transacciones pendientes en alguna FIFO")
    //--------------------------------------------------------------------
    int unsigned n_mid_resets    = 0;   // +n_mid_resets=   cuantos resets extra forzar
    int unsigned mid_reset_len   = 3;   // +mid_reset_len=  duracion de cada uno

    //--------------------------------------------------------------------
    // 3) Distribucion de destino: valido / inexistente / broadcast
    //    (direccion = 8 bits altos del paquete, confirmado en el DUT)
    //--------------------------------------------------------------------
    int unsigned wt_dest_valid   = 65;  // +wt_dest_valid=    destino real, 0..DRVRS-1
    int unsigned wt_dest_invalid = 20;  // +wt_dest_invalid=  destino fuera de rango (sin dueno)
    int unsigned wt_broadcast    = 15;  // +wt_broadcast=     direccion = 8'hFF

    //--------------------------------------------------------------------
    // 4) Timing / send_time (ver c_delay_dist mas abajo para rafagas)
    //--------------------------------------------------------------------
    int unsigned min_delay      = 0;    // +min_delay=       ciclos idle minimos entre envios
    int unsigned max_delay      = 20;   // +max_delay=       ciclos idle maximos entre envios
    int unsigned wt_zero_delay  = 35;   // +wt_zero_delay=   peso extra para delay=0 (rafaga)
    int unsigned wt_big_delay   = 15;   // +wt_big_delay=    peso extra para el delay maximo

    //--------------------------------------------------------------------
    // 5) Datos (payload = PCKG_SZ-8 bits, ya que los 8 altos son direccion)
    //--------------------------------------------------------------------
    int unsigned wt_data_corner = 10;   // +wt_data_corner=  peso de forzar todo-cero/todo-uno

    //--------------------------------------------------------------------
    // 6) Emulacion de FIFO_in / FIFO_out (colas dentro de driver/monitor)
    //--------------------------------------------------------------------
  
    int unsigned mon_min_delay   = 0;   // delay minimo de lectura 
    int unsigned mon_max_delay   = 15;  // +mon_max_delay=  de "leer" su FIFO_out hacia el checker
                                         // (rangos altos aqui fuerzan el caso esquina de
                                         //  underflow: el checker pregunta y la cola esta vacia)

    //--------------------------------------------------------------------
    // 7) Base de datos de constraint_mode (bus_txn)
    //--------------------------------------------------------------------
    bit cmode [string];

    static string CNAMES[] = '{ "c_dest_dist",
                                "c_delay_range",
                                "c_delay_dist",
                                "c_data_range",
                                "c_data_corner" };

    //--------------------------------------------------------------------
    // Singleton
    //--------------------------------------------------------------------
    local static bus_config m_inst;

    static function bus_config get();
      if (m_inst == null) begin
        m_inst = new();
        m_inst.parse_plusargs();
        m_inst.check();
      end
      return m_inst;
    endfunction

    //--------------------------------------------------------------------
    // Helpers alrededor de $value$plusargs (identicos en espiritu al
    // ejemplo FIFO: agregar un knob nuevo es una sola linea en
    // parse_plusargs, no logica nueva aqui)
    //--------------------------------------------------------------------
    local function void get_int(string name, ref int unsigned var_);
      int unsigned tmp;
      if ($value$plusargs({name, "=%d"}, tmp)) begin
        var_ = tmp;
        $display("  [CFG] %-22s = %0d   (from plusarg)", name, tmp);
      end
    endfunction

    local function void get_bit(string name, ref bit var_);
      int unsigned tmp;
      if ($value$plusargs({name, "=%d"}, tmp)) begin
        var_ = tmp[0];
        $display("  [CFG] %-22s = %0b   (from plusarg)", name, tmp[0]);
      end
    endfunction

    //--------------------------------------------------------------------
    function void parse_plusargs();
      int unsigned en;
      $display("----------------------------------------------------------");
      $display(" bus_config : parsing plusargs");
      $display("----------------------------------------------------------");

      get_int("n_txn_min",     n_txn_min);
      get_int("n_txn_max",     n_txn_max);
      get_int("reset_cycles",  reset_cycles);
      get_int("drain_cycles",  drain_cycles);
      get_int("timeout",       timeout);
      get_int("verbose",       verbose);

      get_int("n_mid_resets",  n_mid_resets);
      get_int("mid_reset_len", mid_reset_len);

      get_int("wt_dest_valid",   wt_dest_valid);
      get_int("wt_dest_invalid", wt_dest_invalid);
      get_int("wt_broadcast",    wt_broadcast);

      get_int("min_delay",     min_delay);
      get_int("max_delay",     max_delay);
      get_int("wt_zero_delay", wt_zero_delay);
      get_int("wt_big_delay",  wt_big_delay);

      get_int("wt_data_corner", wt_data_corner);

      
      get_int("mon_min_delay", mon_min_delay);
      get_int("mon_max_delay", mon_max_delay);

      foreach (CNAMES[i]) begin
        en = 1;
        if ($value$plusargs({"cm_", CNAMES[i], "=%d"}, en))
          $display("  [CFG] constraint %-16s -> %s (from plusarg)",
                   CNAMES[i], en[0] ? "ON" : "OFF");
        cmode[CNAMES[i]] = en[0];
      end
    endfunction

    //--------------------------------------------------------------------
    // Checkeo de consistencia de knobs 
    //--------------------------------------------------------------------
    function void check();
      if ((wt_dest_valid + wt_dest_invalid + wt_broadcast) == 0) begin
        $display("  [CFG] WARNING: all destination weights are 0 -> forcing wt_dest_valid=1");
        wt_dest_valid = 1;
      end

      if (n_txn_max < n_txn_min) begin
        $display("  [CFG] WARNING: n_txn_max < n_txn_min -> forcing max=min");
        n_txn_max = n_txn_min;
      end

      if (max_delay < min_delay) begin
        $display("  [CFG] WARNING: max_delay < min_delay -> forcing max=min");
        max_delay = min_delay;
      end

      if (mon_max_delay < mon_min_delay) begin
        $display("  [CFG] WARNING: mon_max_delay < mon_min_delay -> forcing max=min");
        mon_max_delay = mon_min_delay;
      end

      
    endfunction

    //--------------------------------------------------------------------
    function bit is_enabled(string cname);
      return cmode.exists(cname) ? cmode[cname] : 1'b1;
    endfunction

    //--------------------------------------------------------------------
    function void print();
      $display("==========================================================");
      $display(" bus_config : active configuration");
      $display("----------------------------------------------------------");
      $display("  n_txn_min/max      = %0d / %0d", n_txn_min, n_txn_max);
      $display("  reset_cycles       = %0d   drain_cycles = %0d", reset_cycles, drain_cycles);
      $display("  timeout            = %0d", timeout);
      $display("  n_mid_resets       = %0d   mid_reset_len = %0d", n_mid_resets, mid_reset_len);
      $display("  wt_dest v/i/b      = %0d / %0d / %0d",
                wt_dest_valid, wt_dest_invalid, wt_broadcast);
      $display("  delay range        = [%0d:%0d]  wt_zero=%0d wt_big=%0d",
                min_delay, max_delay, wt_zero_delay, wt_big_delay);
      $display("  wt_data_corner     = %0d", wt_data_corner);
      $display("  mon delay range    = [%0d:%0d]", mon_min_delay, mon_max_delay);
      foreach (CNAMES[i])
        $display("  constraint %-16s : %s", CNAMES[i],
                 is_enabled(CNAMES[i]) ? "ON" : "OFF");
      $display("==========================================================");
    endfunction

  endclass : bus_config

endpackage : bus_config_pkg
