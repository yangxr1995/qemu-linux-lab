
./tools/qemu-arm/bin/qemu-system-arm  \
	-kernel ./images/u-boot-nfs  \
	-M vexpress-a9  \
	-m 1024M \
	-net nic,vlan=0  \
	-nographic  \
	-net tap,vlan=0,ifname=tap0,script=./scripts/qemu-ifup,downscript=./scripts/qemu-ifdown  


