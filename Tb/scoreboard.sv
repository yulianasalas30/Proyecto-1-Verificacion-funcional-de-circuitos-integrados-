class scoreboard #(int D_PUSH_BITS = 32, int ID_SIZE= 8,int N_DEV, int BROADCAST_ID = 255);
 
  typedef agent_txn #(D_PUSH_BITS, ID_SIZE) exp_txn_t;
 
  mailbox #(exp_txn_t) ag2sb;
  exp_txn_t             exp_q [N_DEV][$];   // una cola por destino
  int unsigned           n_received = 0;
 
  function new(mailbox #(exp_txn_t) ag2sb_i);
    this.ag2sb = ag2sb_i;
  endfunction
 
  task automatic run();
    exp_txn_t t;
    forever begin
      ag2sb.get(t);
      n_received++;
      if (t.destination == BROADCAST_ID) begin
        for (int d = 0; d < N_DEV; d++)
          if (d != t.source) exp_q[d].push_back(t);
      end else begin
        exp_q[t.destination].push_back(t);
      end
    end
  endtask
 
  // usado por el checker: saca el primero esperado para ese destino.
  // devuelve 0 si no habia nada esperado (paquete no solicitado).
  function automatic bit pop_expected(input int unsigned dst, output exp_txn_t t);
    if (exp_q[dst].size() == 0) return 0;
    t = exp_q[dst].pop_front();
    return 1;
  endfunction
 
endclass