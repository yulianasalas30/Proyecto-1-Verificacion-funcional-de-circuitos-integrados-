//si el DUT solamente me da Dpush y push (porque son sus salidas)
//D push es lo que le pasare al monitor, el push lo usare solamente
//anadirlo a la cola que me emula la FIFO
//la fifo se hara en este mismo modulo, para al revisar la cola se verifique el uso de la interfaz
//asumo la interfaz esta constantemente leyendo la fifo en realidad es solo emulacion no se utiliza mas adelante 



interface if_DUT_monitor #(parameter D_PUSH_BITS=32)(input logic clk, input logic reset);

logic [D_PUSH_BITS-1:0] dato;
logic push;


modport DUT (output dato, output push);
modport monitor (input dato, input push);

//emulando fifo

  logic [D_PUSH_BITS-1:0] fifo_emulador [$];
  always @(posedge clk) begin
    if (reset) begin
      fifo_emulador.delete();
    end else if (push) begin
      fifo_emulador.push_back(dato);
    end
  end
endinterface
