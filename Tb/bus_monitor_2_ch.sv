class bus_monitor_2_ch #(int D_PUSH_BITS = 32,int ID_SIZE = 8);

    typedef monitor #(D_PUSH_BITS, ID_SIZE) datos_monitor;
    typedef virtual if_DUT_monitor #(D_PUSH_BITS).monitor mon_vif_t;

    mon_vif_t vif; //para conectar el clock y reset que esta en la interfaz ocn el dut para que se trabaje con el mismo clk
    int id;
    mailbox #(datos_monitor) mon2ch; //monitor to ch
    function new (mon_vif_t vif_i, int id_i, mailbox #(datos_monitor) mon2ch_i);
        this.vif = vif_i;
        this.id = id_i;
        this.mon2ch = mon2ch_i;
    endfunction

    task automatic run(); //estructura similar al del ejemplo de fifo
        datos_monitor correo;
        forever begin
            @(posedge vif.clk);
            if (vif.reset)
                continue;
            if (vif.push) begin //si hay un push se envia el mailbox al checker 
                correo= new(vif.d_push);
                mon2ch.put(correo);
            end
        end
    endtask
endclass

