//======================================================================
// bus_generator.sv
//----------------------------------------------------------------------
// 
//======================================================================
package bus_generator_pkg;

  import bus_params_pkg::*;  //para DRVRS
  import bus_config_pkg::*; //para .verbose
  import bus_txn_pkg::*; //para bus_txn

  class bus_generator;

    local bus_config      cfg;    //para .verbose
    local mailbox #(bus_txn) gen2agt;  //mailbox del generador al agente

    function new(mailbox #(bus_txn) gen2agt_);
      cfg = bus_config::get();
      this.gen2agt = gen2agt_;
    endfunction



    task run();
      int unsigned n_txn[DRVRS];  //numero de transacciones a generar por cada terminal
      int unsigned order[$];   //
      bus_txn      txn;

      // 1) cuantas transacciones le tocan a cada terminal
      foreach (n_txn[i]) begin
        n_txn[i] = $urandom_range(cfg.n_txn_max, cfg.n_txn_min); //random entre min y max
        if (cfg.verbose)
          `INFO("GEN", $sformatf("terminal %0d generara %0d transacciones", i, n_txn[i]))
        repeat (n_txn[i]) order.push_back(i); //llenamos el arreglo con la cantidad de transacciones que le tocan a cada terminal
        //Si a la terminal 2 le tocaron 5 transacciones, quedan 5 copias del número 2 en order 
      end
      // 2) mezclamos el orden de las transacciones para que no salgan todas de la misma terminal seguidas
      order.shuffle(); 

      if (cfg.verbose)
        `INFO("GEN", $sformatf("total de transacciones a generar: %0d", order.size()))
      

      // 3) generamos las transacciones en el orden mezclado y se las enviamos al agente

 foreach (order[k]) begin
        txn = new();
        txn.source = order[k];
        if (!txn.randomize())  // buena practica: chequear que randomize() no falle nunca, aunque no deberia
          `ERR("GEN", $sformatf("randomize() fallo para terminal %0d", order[k]))
 
        if (cfg.verbose) txn.print("GEN->AGT");
        gen2agt.put(txn); // pone la transaccion en el mailbox del agente
      end


      if (cfg.verbose)
        `INFO("GEN", "generacion completa")
    endtask

  endclass : bus_generator

endpackage : bus_generator_pkg