
#   make comp                       compila una vez
#   make base                       prueba base, totalmente aleatoria
#   make <escenario>                cualquier escenario del plan de pruebas
#   make regress                    corre todo el plan (sin el sweep)
#   make sweep                      barrido de DRVRS / PCKG_SZ (recompila)
#   make cov                        reporte de cobertura (urg)
#
# Cada escenario reusa el mismo simv: solo cambian los plusargs.

# Antes de usar make correr este comando:
# source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh
#se puede cambiar la semilla escribiendo por ejemplo make base SEED=7
 
VCS      = vcs
SIMV     = ./simv
FLIST    = bus.f
 
#Estructurales (se fijan al COMPILAR)
DRVRS   ?= 4
PCKG_SZ ?= 16
PERIOD  ?= 10
 
#Ciclos de espera al final de cada simulacion (+drain_cycles) 
DRAIN   ?= 20000
 
#Semilla aleatoria
SEED    ?= 1
 
VCS_OPTS = -full64 -sverilog -kdb -lca -timescale=1ns/1ps \
           -debug_acc+all -debug_region+cell+encrypt +lint=TFIPC-L \
           +define+BUS_DRVRS=$(DRVRS) \
           +define+BUS_PCKG_SZ=$(PCKG_SZ) \
           +define+CLK_PERIOD=$(PERIOD) \
           -cm line+cond+fsm+tgl+branch \
           -cm_dir ./cov.vdb \
           -top tb_top -o simv
 
RUN_OPTS = -cm line+cond+fsm+tgl+branch -cm_dir ./cov.vdb \
           +ntb_random_seed=$(SEED) +drain_cycles=$(DRAIN)
 
#-----------------------------------------------------------------------
comp:
	@which $(VCS) > /dev/null 2>&1 || { echo "No encuentro vcs: haz el source de synopsys_tools2.sh"; exit 1; }
	$(VCS) $(VCS_OPTS) -f $(FLIST) -l comp.log
 
#------------------------------------------------------------------------
# PLAN DE PRUEBAS

 
#Prueba base, todo aleatorio: destino valido,invalido o broadcast mezclados
base:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 -l base.log
 
#Prueba general o valida: solo destinos validos 
prueba_valida:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   -l prueba_valida.log
 
# Solo destinos inexistentes
id_invalido:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +wt_dest_valid=0 +wt_dest_invalid=100 +wt_broadcast=0 \
	   -l id_invalido.log
 
#Broadcast
broadcast:
	$(SIMV) $(RUN_OPTS) +n_txn_min=5 +n_txn_max=5 \
	   +wt_dest_valid=0 +wt_dest_invalid=0 +wt_broadcast=100 \
	   -l broadcast.log
 
#Muchos paquetes consecutivos
paq_consecutivo:
	$(SIMV) $(RUN_OPTS) +n_txn_min=200 +n_txn_max=200 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   +min_delay=0 +max_delay=0 +timeout=1000000 \
	   -l paq_consecutivo.log
 
#Esperas gradnes al enviar
esp_grande:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   +min_delay=10 +max_delay=40 +wt_zero_delay=0 +timeout=1000000 \
	   -l esp_grande.log
 
#Casi siempre todo ceros o todo unos
data_corners:
	$(SIMV) $(RUN_OPTS) +n_txn_min=50 +n_txn_max=50 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   +wt_data_corner=1000 -l data_corners.log
 
#Monitor que lee su FIFO_out muy rapido (caso de underflow)
mon_fast:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   +mon_min_delay=1 +mon_max_delay=1 -l mon_fast.log
 
#monitor que lee su FIFO_out muy lento (la cola se acumula)
mon_slow:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +wt_dest_valid=100 +wt_dest_invalid=0 +wt_broadcast=0 \
	   +mon_min_delay=30 +mon_max_delay=60 -l mon_slow.log
 
 
#todas las constraints con nombre apagadas para probar que se fuerce 1
unconstrained:
	$(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 \
	   +cm_c_dest_dist=0 +cm_c_delay_dist=0 +cm_c_data_range=0 \
	   +cm_c_data_corner=0 -l unconstrained.log
 #corrida larga
soak:
	$(SIMV) $(RUN_OPTS) +n_txn_min=500 +n_txn_max=500 \
	   +timeout=5000000 -l soak.log
 
# barrido estructural (necesita recompilar: DRVRS y PCKG_SZ son
#       parametros del DUT; todo lo demas sigue siendo plusarg).
#       Al terminar, el simv que queda es el del ultimo caso: haz
#       "make comp" para volver a la configuracion normal.
sweep:
	$(MAKE) comp DRVRS=2  PCKG_SZ=16 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d2_p16.log
	$(MAKE) comp DRVRS=4  PCKG_SZ=32 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d4_p32.log
	$(MAKE) comp DRVRS=4  PCKG_SZ=64 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d4_p64.log
	$(MAKE) comp DRVRS=8  PCKG_SZ=16 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d8_p16.log
	$(MAKE) comp DRVRS=16 PCKG_SZ=16 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d16_p16.log
	$(MAKE) comp DRVRS=16 PCKG_SZ=64 && $(SIMV) $(RUN_OPTS) +n_txn_min=20 +n_txn_max=50 +timeout=1000000 -l sweep_d16_p64.log
	@echo "----- sweep terminado -----"
	@grep -H "RESULTADO GLOBAL" sweep_*.log || true
 
#-----------------------------------------------------------------------
regress: comp base prueba_valida id_invalido broadcast paq_consecutivo esp_grande \
         data_corners mon_fast mon_slow unconstrained
	@echo "----- regresion terminada: veredicto del checker en cada log -----"
	@grep -H "RESULTADO GLOBAL" base.log prueba_valida.log id_invalido.log broadcast.log \
	   paq_consecutivo.log esp_grande.log data_corners.log mon_fast.log mon_slow.log \
	unconstrained.log || true
 
cov:
	urg -dir ./cov.vdb -report ./urgReport
 
clean:
	rm -rf simv* csrc *.log *.vpd *.vdb urgReport DVEfiles ucli.key .vcs* novas* *.fsdb bus_results.csv
 
.PHONY: comp base prueba_valida id_invalido broadcast paq_consecutivo esp_grande \
        data_corners mon_fast mon_slow  unconstrained soak \
        sweep regress cov clean
 