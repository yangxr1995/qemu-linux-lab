
#./tools/qemu-arm/bin/qemu-system-arm 

qemu-system-arm  \
	-kernel ./images/u-boot-nfs  \
	-M vexpress-a9  \
	-m 1024M \
	-net nic,  \
	-nographic  \
	-net tap,ifname=tap0,script=./scripts/qemu-ifup,downscript=./scripts/qemu-ifdown  \
	-s -S

