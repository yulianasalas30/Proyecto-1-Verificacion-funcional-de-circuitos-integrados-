//el monitor es el que se encarga de traducir lo que envie el DUT a cosas sencillas que entendera el checker
//se necesita conectar esto al scoreboard, con un bus talvez


class monitor #(int D_PUSH_BITS = 32, int ID_SIZE=8);
 
  int id;
  logic [D_PUSH_BITS-ID_SIZE-1:0] d_push;
 
  function new(logic [D_PUSH_BITS-1:0] d_push_i);
    this.id   = d_push_i[D_PUSH_BITS-1 : D_PUSH_BITS-ID_SIZE]
    this.d_push  = d_push_i[D_PUSH_BITS-ID_SIZE-1:0];
  endfunction
 
  function string convert2str();
    return $sformatf("id destino=%0d dato=%0h", id, d_push);
  endfunction
 
endclass
