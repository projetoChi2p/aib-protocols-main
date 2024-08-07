#-------------------------------------------------------------------------
# Description: makefile
#-----------------------------------------------------------------------------

default: help

#-----------------------------------------------------------------------------
# user specify Files
#-----------------------------------------------------------------------------
export PROJ_DIR = ../../../../

#-----------------------------------------------------------------
# SEED defaults to random
# To use a seed with value N, specify "SEED=N" on the make command line
#-----------------------------------------------------------------
ifeq ($(SEED), )
  rseedprocid := $(shell echo $$$$)
  rseed := `expr $(shell date +"%S%M%H%d") + $(rseedprocid)`
else
  rseed := $(SEED)
endif
SEEDCMD = +ntb_random_seed=$(rseed)

ifeq ($(UNIQ), ON)
    UNIQID = _$(rseed)
else
    UNIQID =
endif

#-----------------------------------------------------------------------------
# Include Required Files
#-----------------------------------------------------------------------------
export SIM_DIR =${PROJ_DIR}axi4-mm/full_examples/sims
export tbench_dir = $(SIM_DIR)/tb_mh2.1_sh1_d32

## Define RTL directory
export AIB_ROOT=${PROJ_DIR}../aib-phy-hardware
AIBv1_1_ROOT=${AIB_ROOT}/v2.0/rev1.1
AIBv1_ROOT=${AIB_ROOT}/v2.0/rev1
export RTL_ROOT=${AIBv1_RTL_ROOT}

#Gen1 Root
GEN1_ROOT=${AIB_ROOT}/v1.0/rev2/rtl/
export V1S_ROOT=${GEN1_ROOT}/v1_slave

#Rev 1 Root
export AIBv1_RTL_ROOT=${AIBv1_ROOT}/rtl
export AIBV1_DV_ROOT=${AIBv1_ROOT}/dv

#Rev 1.1 Root
AIB2v1_1_RTL_ROOT=${AIBv1_1_ROOT}/rtl/bca
export MAIBv1_1_RTL_ROOT=${AIBv1_1_ROOT}/rtl/maib_rev1.1
export AIBv1_1_DV_ROOT =${AIBv1_1_ROOT}/dv
export AIB2_RTL_ROOT=${AIB2v1_1_RTL_ROOT}
export FM_ROOT=${MAIBv1_1_RTL_ROOT}


#-----------------------------------------------------------------------------
# Example VCS execution command.
#-----------------------------------------------------------------------------

WAVES_FORMAT ?= WAVES_VPD ## This option compiles in possibility to record VPD. But this can be disabled via plusarg +WAVES_OFF in runtime arguments.

VCS = xelab -sv -debug all -timescale=1ps/1ps -top top_tb -snapshot tb_top_snapshot

COMPILE_OPTION ?=

VLOG_COMM = xvlog -sv -d ${WAVES_FORMAT} -i ${SIM_DIR} -i ${AIBv1_1_DV_ROOT}/interface/ -i ${AIBv1_1_DV_ROOT}/test/data -i ${AIBV1_DV_ROOT}/interface/ -i ${AIBV1_DV_ROOT}/test/data

compile_aibrtl:
	 ${VLOG_COMM} -sverilog +v2k -full64 -timescale=1ps/1ps -work WORK -ntb_opts uvm -f ${AIB2v1_1_RTL_ROOT}/AIB2.0_RTL_filelist.f -l compile_aib2v1_1.log
	 ${VLOG_COMM} -sverilog +v2k -full64 -timescale=1ps/1ps -work WORK -ntb_opts uvm -f ${AIBV1_DV_ROOT}/flist/ms.cf -l compile_aib2v1.log
	 ${VLOG_COMM} -sverilog +v2k -full64 -timescale=1ps/1ps +define+AIB_MODEL +define+VCS+SL_AIB_GEN1+MAIB_REV1DOT1+MS_AIB_BCA +define+SIM_DIR=${SIM_DIR} -work WORK -ntb_opts uvm -f ${SIM_DIR}/../flist/axi_mm_d128_h2h.f -l compile_aximm.log
	 ${VLOG_COMM} -sverilog +v2k -full64 -timescale=1ps/1ps +define+TIMESCALE_EN+VCS+BEHAVIORAL+MAIB_PIN96+ALTR_HPS_INTEL_MACROS_OFF -f ${AIB2v1_1_RTL_ROOT}/../../dv/flist/maib_rev1.1.cf -l compile_maibv1_1.log
	 ${VLOG_COMM} -sverilog  +v2k -full64  -timescale=1ps/1ps +define+VCS+SL_AIB_GEN1+MAIB_REV1DOT1 +define+AIB_MODEL -work WORK -f ${SIM_DIR}/../flist/tb_rtl.cf -l compile_tb.log
	 ${VCS} -debug_acc+all -full64 +lint=TFIPC-L +error+100 +lint=PCWM -top top_tb -l vcs.log

compile:
	 
	 ${VLOG_COMM} --work WORK -f ${AIBV1_DV_ROOT}/flist/ms.cf
	 ${VLOG_COMM} -d SL_AIB_GEN1 -d SIM_DIR=${SIM_DIR} -d AIB_MODEL --work WORK -f ${SIM_DIR}/../flist/axi_mm_d128_h2h.f
	 ${VLOG_COMM} -d FOR_SIM_ONLY -d TIMESCALE_EN -d BEHAVIORAL -d MAIB_PIN96 -d ALTR_HPS_INTEL_MACROS_OFF --work WORK -f ${AIBV1_DV_ROOT}/flist/sl_v1.cf
	 ${VLOG_COMM} -d SL_AIB_GEN1 -d MAIB_REV1DOT1 -d AIB_MODEL --work WORK -f ${SIM_DIR}/../flist/tb_rtl.cf
	 ${VCS}

syn:
	vivado -mode tcl -source syn.tcl
sim:
	xsim tb_top_snapshot -R
	
sim_gui :
	xsim tb_top_snapshot --gui -onfinish stop

sim_gui_db :
	xsim tb_top_snapshot --gui -onfinish stop --t run_sim.tcl

run : clean gen_cfg compile sim

run_gui : clean gen_cfg compile sim_gui

run_db : clean gen_cfg compile sim_gui_db

run_aibrtl : clean gen_cfg compile_aibrtl sim

gen_cfg :
	python3 ${PROJ_DIR}/llink/script/llink_gen.py --cfg aximm_ll.cfg

#-----------------------------------------------------------------------------
# Help - display gmake option
#-----------------------------------------------------------------------------
help:
	@echo "=========================================================================================="
	@echo "                                       makefile options                                   "
	@echo "=========================================================================================="
	@echo "    	make compile		- Compiles DUT and TB files with AIB2v1.0/MAIB1.0 for simulation"
	@echo "    	make compile_aibrtl	- Compiles DUT and TB files with AIB2v1.1/MAIB1.1 for simulation"
	@echo "  	make run    		- Clears, compiles and runs simulation with AIB2v1.0/MAIB1.0"
	@echo "  	make run_aibrtl		- Clears, compiles and runs simulation with AIB2v1.1/MAIB1.1"
	@echo "    	make sim    		- Simulates the design "
	@echo "    	make clean  		- Remove all generated files"
	@echo "    	make gen_cfg  		- Generates Leader and Follower files"
	@echo " "

#-----------------------------------------------------------------------------
# Clean up
#-----------------------------------------------------------------------------

clean:
	rm -rf *.log
	rm -rf *.vpd
	rm -rf simv*
	rm -rf csrc_debug/
	rm -rf DVEfiles/
	rm -rf AN.DB/
	rm -rf work.lib++/
	rm -rf ucli.key
	rm -rf axi_mm
	rm -rf novas.conf verdiLog/ verdi_config_file novas.rc
	rm -rf .fsm.sch.verilog.xml
	rm -rf *.fsdb
	rm -rf tb_top_snapshot
	rm -rf *.pb
	rm -rf *.jou
	rm -rf *.str
	rm -rf *.wdb
	rm -rf xsim.dir
	rm -rf .Xil
