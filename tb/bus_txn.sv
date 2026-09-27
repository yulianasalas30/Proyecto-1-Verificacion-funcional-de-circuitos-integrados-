//======================================================================
// bus_txn.sv
//----------------------------------------------------------------------
// 
//======================================================================
package bus_txn_pkg;

  import bus_config_pkg::*;
  import bus_params_pkg::*;   // exporta DRVRS, PCKG_SZ, ADDR_W, BCAST_ID, DATA_W

  // ------------------------------------------------------------------
  typedef enum { DEST_VALID, DEST_INVALID, DEST_BCAST } dest_cat_e;

  class bus_txn;

   
    local bus_config cfg;

    // ------------------------------------------------------------------
    // Campos = tabla "Generador -> Agente" del testplan
    // ------------------------------------------------------------------
    int unsigned       source;       // terminal que genera (0..DRVRS-1)
    rand dest_cat_e         dest_cat;     // helper: categoria de destino
    rand int unsigned       destination;  // terminal destino, o ID reservado si es invalido
    rand bit                broadcast;    // 1 si dest_cat == DEST_BCAST
    rand int unsigned       send_time;    // ciclos de espera desde la ULTIMA
                                           // transaccion de esta misma terminal
                                           // (no un timestamp absoluto)
    rand bit [DATA_W-1:0]   data;         // payload (sin el byte de direccion)
         int unsigned       packet_size;  // fijo = PCKG_SZ para esta compilacion

    // ------------------------------------------------------------------
    // Constraints
    // ------------------------------------------------------------------
    

    // c_dest_dist: pesos de bus_config deciden que tan seguido cada
    // categoria de destino aparece.
    constraint c_dest_dist {
      dest_cat dist {
        DEST_VALID   := cfg.wt_dest_valid,
        DEST_INVALID := cfg.wt_dest_invalid,
        DEST_BCAST   := cfg.wt_broadcast
      };
    }

    // 
    constraint c_dest_value {
      (dest_cat == DEST_BCAST)   -> destination == BCAST_ID;
      (dest_cat == DEST_VALID)   -> destination inside {[0:DRVRS-1]} && destination != source;
      (dest_cat == DEST_INVALID) -> destination inside {[DRVRS:BCAST_ID-1]};
      broadcast == (dest_cat == DEST_BCAST);
    }

    constraint c_delay_range {
      send_time inside {[cfg.min_delay:cfg.max_delay]};
    }

    //
    constraint c_delay_dist {
      send_time dist {
        cfg.min_delay                     :/ cfg.wt_zero_delay,
        cfg.max_delay                     :/ cfg.wt_big_delay,
        [cfg.min_delay:cfg.max_delay]     :/ 50
      };
    }

    constraint c_data_range {
      data inside {[0:{DATA_W{1'b1}}]};   // trivial dado el ancho, pero
                                           // togglable por consistencia
    }

    // c_data_corner: mismo patron, sesga hacia todo-cero / todo-uno
    // sin abandonar el resto del rango.
    constraint c_data_corner {
      data dist {
        {DATA_W{1'b0}}         :/ cfg.wt_data_corner,
        {DATA_W{1'b1}}         :/ cfg.wt_data_corner,
        [0:{DATA_W{1'b1}}]     :/ 50
      };
    }

    // ------------------------------------------------------------------
    function new();
      cfg         = bus_config::get();
      packet_size = PCKG_SZ;
    endfunction

    // Prende/apaga cada constraint segun cfg.is_enabled(), igual patron
    // que en fifo_txn del ejemplo FIFO. Ya no necesita volver a pedir
    // el singleton aqui: "cfg" ya es el miembro asignado en new().
    function void pre_randomize();
      this.c_dest_dist.constraint_mode(cfg.is_enabled("c_dest_dist"));
      this.c_delay_range.constraint_mode(cfg.is_enabled("c_delay_range"));
      this.c_delay_dist.constraint_mode(cfg.is_enabled("c_delay_dist"));
      this.c_data_range.constraint_mode(cfg.is_enabled("c_data_range"));
      this.c_data_corner.constraint_mode(cfg.is_enabled("c_data_corner"));
    endfunction

    function void print(string tag = "TXN");
      $display("[%0t] [%-6s] src=%0d dst=%0d(%s) bcast=%0b size=%0d data=%0h send_time=%0d",
                $time, tag, source, destination, dest_cat.name(),
                broadcast, packet_size, data, send_time);
    endfunction

  endclass : bus_txn

endpackage : bus_txn_pkg