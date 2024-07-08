#!/bin/bash

rm -rf *.log
rm -rf *.vpd
rm -rf simv*
rm -rf csrc_debug/
rm -rf DVEfiles/
rm -rf AN.DB/
rm -rf work.lib++/
rm -rf axi_mm
rm -rf .fsm.sch.verilog.xml
rm -rf *.fsdb
rm -rf tb_top_snapshot
rm -rf *.pb
rm -rf *.jou
rm -rf *.str
rm -rf *.wdb
rm -rf xsim.dir
rm -rf .Xil

export PROJ_DIR="../../../../"
export SIM_DIR="${PROJ_DIR}axi4-mm/full_examples/sims"
export tbench_dir="${SIM_DIR}/tb_mh2.1_sh1_d32"

export RTL_ROOT="../../../../../aib-phy-hardware/v2.0/rev1/rtl"
export V1M_ROOT="$RTL_ROOT"

make gen_cfg

xvlog -sv -f ../../../../../aib-phy-hardware/v2.0/rev1/dv/flist/ms.cf

xvlog -sv -f ../../flist/axi.f

xvlog -sv -f ../../../../../aib-phy-hardware/v2.0/rev1/dv/flist/tb_rtl_ch.cf

xelab -sv -debug all -timescale=1ps/1ps -top top_tb -snapshot tb_top_snapshot

if [ $1 = "gui" ]; then
xsim tb_top_snapshot --gui -onfinish stop
else
xsim tb_top_snapshot -R
fi
