class bus_monitor_2_sb #(int D_PUSH_BITS = 32,int ID_SIZE = 8);

    typedef monitor #(D_PUSH_BITS, ID_SIZE) datos_monitor;
    typedef virtual if_DUT_monitor #(D_PUSH_BITS).monitor mon_vif_t;

    mon_vif_t vif; //para conectar el clock y reset que esta en la interfaz ocn el dut para que se trabaje con el mismo clk
    int id;
    mailbox #(datos_monitor) mon2sb; //monitor to scoreboard
    function new (
        mon_vif_t vif_i,
        int id_i,
        mailbox #(datos_monitor) mon2sb_i);
        this.vif = vif_i;
        this.id = id_i;
        this.mon2sb = mon2sb_i;
    endfunction

    task automatic run(); //estructura similar al del ejemplo de fifo
        datos_monitor correo;
        forever begin
            @(posedge vif.clk);
            if (vif.reset)
                continue;
            if (vif.push) begin
                correo = new(vif.D_push);
                mon2sb.put(correo);
                $display(
                    "[salida monitor %0d] %s",
                    id,
                    correo.convert2str()
                );
            end
        end
    endtask
endclass

