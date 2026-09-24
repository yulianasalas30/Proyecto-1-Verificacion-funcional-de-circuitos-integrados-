class checker #(int D_PUSH_BITS = 32, int ID_SIZE = 8, int N_DEV = 4,
                 int BROADCAST_ID = 255);
 
  typedef monitor    #(D_PUSH_BITS, ID_SIZE)                       obs_txn_t;
  typedef scoreboard #(D_PUSH_BITS, ID_SIZE, N_DEV, BROADCAST_ID)  sb_t;
  typedef sb_t::exp_txn_t; 
 
  mailbox #(obs_txn_t) mon2ch [N_DEV];
  sb_t sb;
  int unsigned n_pass = 0;
  int unsigned n_fail = 0;
 
  function new(mailbox #(obs_txn_t) mon2ch_i [N_DEV], sb_t sb_i);
    this.mon2ch = mon2ch_i;
    this.sb= sb_i;
  endfunction
 
  task automatic run();
    for (int d = 0;d< N_DEV; d++) begin
      automatic int dd = d;
      fork
        check_device(dd);
      join_none
    end
  endtask
 
  task automatic check_device(int unsigned dev);
    obs_txn_t obs;
    exp_txn_t exp;
    forever begin
      mon2ch[dev].get(obs); // algo llego al dispositivo 
 
      if (!sb.pop_expected(dev, exp)) begin
        n_fail++;
        $error("[CHK] dispositivo %0d recibio un paquete no esperado: %s",
               dev, obs.convert2str());
        continue;
      end
 
      //el destino que el emisor puso
      // en la palabra deberia coincidir con el puerto real que la
      // recibio (si no, es un bug de ruteo del bus)
      if (obs.embedded_dst != dev)
        $warning("Checker: destino (%0d) no coincide con el puerto real (%0d) en t=%0t",
                  obs.embedded_dst, dev, obs.t_obs);
 
    //chequeando si lo qe el sb envio es lo msimo que envio el monitor
      if (obs.raw !== exp.packet) begin
        n_fail++;
        $error("Cheker: dato incorrecto en destino %0d: obtenido=0x%0h esperado=0x%0h (enviado por src=%0d en t=%0t)",
               dev, obs.raw, exp.packet, exp.source, exp.send_time);
      end else begin
        n_pass++;
        $display("cheker  OK dst=%0d dato=0x%0h  latencia=%0t (src=%0d, t_send=%0t)",
                  dev, obs.raw, obs.t_obs - exp.send_time, exp.source, exp.send_time);
      end
    end
  endtask
 
  function void report();
    $display("Cheker resumen: pass=%0d fail=%0d", n_pass, n_fail);
  endfunction
 
endclass