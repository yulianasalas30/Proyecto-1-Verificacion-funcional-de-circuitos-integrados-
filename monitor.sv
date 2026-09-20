//el monitor es el que se encarga de traducir lo que envie el DUT a cosas sencillas que entendera el checker
//se necesita conectar esto al scoreboard, con un bus talvez


class monitor #(int D_PUSH_BITS = 32, int ID_SIZE=8);
 
  int id;
  logic [D_PUSH_BITS-1:0] dato;
 
  function new(logic [D_PUSH_BITS-1:0] dato_i);
    this.id   = dato_i[D_PUSH_BITS-1:D_PUSH_BITS-ID_SIZE-1];
    this.dato  = dato_i[D_PUSH_BITS-ID_SIZE-1:0];
  endfunction
 
  function string convert2str();
    return $sformatf("id destino=%0d dato=%0h", id, dato);
  endfunction
 
endclass
