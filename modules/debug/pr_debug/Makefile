kernel_path := /root/qemu-linux-lab/build/linux-5.10.183

obj-m += pr_debug_test.o

CROSS_COMPILE := arm-linux-gnueabi-

all:
	make ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) -C  ${kernel_path} M=`pwd` modules 
# KCFLAGS=-DDEBUG

clean:
	make ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) -C ${kernel_path} M=`pwd` clean

