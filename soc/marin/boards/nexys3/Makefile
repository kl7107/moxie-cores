COREGEN_SOURCES = clk_wiz_v3_6.v fifo_generator_v9_3.v ram4k16bit.v 

SOURCES = $(wildcard ../../../../cores/MoxieLite/*.vhd) \
	  $(wildcard ../../../../cores/MoxieLite/*.v) \
	  $(wildcard ../../../../cores/nexys7seg/*.v) \
	  $(wildcard ../../../../cores/wishbone/*.v) \
	  ../../../../cores/uart3/uart.v \
	  ../../../../cores/uart3/uart_wb.v \
	  $(wildcard ../../../../cores/ram16bit/*.v) \
	  $(wildcard ../../../../cores/gdbtarget/*.v) \
	  $(wildcard ../../../../cores/statled/rtl/*.v) \
	  $(wildcard ../../../../cores/psram/psram_wb.v) \
	  ../../../../cores/mpic/mpic.v \
	  ../../../../cores/mtimer/mtimer.v \
	  $(wildcard ../../rtl/*.v) \
	  $(COREGEN_SOURCES) 

#	  /opt/Xilinx/14.2/ISE_DS/ISE/verilog/src/iSE/unisim_comp.v

PROJECT = marin

all: hello.srec $(PROJECT).bit

program: $(PROJECT).bit
	djtgcfg prog -d Nexys3 -i 0 -f $<

hello.srec: hello.elf
	moxie-elf-objcopy -O srec --srec-forceS3 hello.elf hello.srec

hello.elf: hello.c m.S
	moxie-elf-gcc -Wl,-Map,hello.map -Os hello.c m.S -T../../moxie-marin.ld -o hello.elf -lnosys 

ram4k16bit.v: ram4k16bit.xco coregen.cgp
	XIL_CG_LOAD_ALL_FAMILIES=true coregen -b ram4k16bit.xco -p coregen.cgp

clk_wiz_v3_6.v: clk_wiz_v3_6.xco coregen.cgp
	XIL_CG_LOAD_ALL_FAMILIES=true coregen -b clk_wiz_v3_6.xco -p coregen.cgp

fifo_generator_v9_3.v: fifo_generator_v9_3.xco coregen.cgp
	XIL_CG_LOAD_ALL_FAMILIES=true coregen -b fifo_generator_v9_3.xco -p coregen.cgp

CFLAGS = -Os -g -ffunction-sections -mno-crt0

BOOTROM_SOURCES = ../../../../firmware/tinystart.S \
		../../../../firmware/tinystub.c \
		../../../../firmware/handler.S

bootrom.elf: $(BOOTROM_SOURCES) ../../moxie-marin-onchip.ld
	moxie-elf-gcc $(CFLAGS) -c -o tinystart.o \
		../../../../firmware/tinystart.S
	moxie-elf-gcc $(CFLAGS) -c -o tinystub.o \
		../../../../firmware/tinystub.c -Wall 
	moxie-elf-gcc $(CFLAGS) -c -o handler.o ../../../../firmware/handler.S
	moxie-elf-gcc $(CFLAGS) -Wl,-Map,bootrom.map tinystart.o \
		tinystub.o handler.o -o bootrom.elf -Wl,--gc-sections \
		-T../../moxie-marin-onchip.ld -lnosys

bootrom.vh: bootrom.elf
	# Adjust the loadable section addresses down by 1k so they will load
	# properly into bootrom16.v.  Use bootrom.elf for simulators like
	# qemu, and bootrom0.elf for input into the verilog code.
	moxie-elf-objcopy --change-section-lma .rodata-0x1000 \
		--change-section-lma .text-0x1000 bootrom.elf bootrom0.elf
	data2mem -bd bootrom0.elf -d -o m bootrom0.mem
	grep -v @ bootrom0.mem > bootrom.vh
	rm bootrom0*

$(PROJECT).prj: bootrom.vh ../../../../cores/gdbtarget/messages.vh $(SOURCES)
	rm -f $(PROJECT).prj
	for i in `echo $^`; do \
	  case $$i in \
	    *.vhd) \
		echo "vhdl work $$i" >> $@; \
		;; \
	    *.v) \
		echo "verilog work $$i" >> $@; \
		;; \
	  esac; \
	done;

$(PROJECT).bit: $(PROJECT).ncd $(PROJECT).ut
	bitgen -f $(PROJECT).ut $(PROJECT).ncd

$(PROJECT).ngd: $(PROJECT).ngc
	ngdbuild -dd . -nt timestamp -uc Nexys3_Master.ucf -p xc6slx16-csg324-3 $(PROJECT).ngc $(PROJECT).ngd

$(PROJECT).ngc $(PROJECT).syr: $(PROJECT).prj $(PROJECT).xst
	xst -ifn $(PROJECT).xst -ofn $(PROJECT).syr

$(PROJECT)_map.ncd $(PROJECT).pcf: $(PROJECT).ngd
	map -w -o $(PROJECT)_map.ncd $(PROJECT).ngd $(PROJECT).pcf

$(PROJECT).ncd: $(PROJECT)_map.ncd $(PROJECT).pcf
	par -w $(PROJECT)_map.ncd $(PROJECT).ncd $(PROJECT).pcf

clean: 
	-rm -rf *.prj *.ngd *.srp *~ *.lso *.xrpt xst _xmsgs
	-rm -rf *.map *.par *.syr *.log *.ncd *.twr *xprt *.lso
	-rm -rf *.bld xlnx_auto_0_xdb *.mrp *.ngm *.ngc *.xml 
	-rm -rf *.lst *.pcf *.bgn *.bit *.xwbt *.drc *.csv
	-rm -rf *.txt *.ptwx *.unroutes *.xpi *.html *.pad
	-rm -rf _impact.cmd *.ipf auto_project* *.xsl *.svf
	-rm -rf tmp coregen.cgc bootrom.vh bootrom.x
	-rm -rf $(COREGEN_SOURCES) $(COREGEN_SOURCES:.v=.ucf)
	-rm -rf $(COREGEN_SOURCES:.v=.asy)
	-rm -rf $(COREGEN_SOURCES:.v=.gise)
	-rm -rf $(COREGEN_SOURCES:.v=.veo)
	-rm -rf $(COREGEN_SOURCES:.v=.xdc)
	-rm -rf $(COREGEN_SOURCES:.v=.xise)
	-rm -rf $(COREGEN_SOURCES:.v=_xmdf.tcl)
	-rm -rf $(COREGEN_SOURCES:.v=.cgc)
	-rm -rf $(COREGEN_SOURCES:.v=)
	-rm -rf *.elf *.srec *.o *.mem
