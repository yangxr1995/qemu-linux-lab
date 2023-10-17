#!/bin/bash
set -e

topdir=${PWD}
patchdir=${topdir}/patch
imagedir=${topdir}/images
rootfsdir=${topdir}/rootfs
toolsdir=${topdir}/tools
builddir=${topdir}/build

busybox_src="busybox-1.32.0"
linux_src="linux-5.10.183"
uboot_src="u-boot-2020.10"
gdb_src="gdb-13.2"
qemu_src="qemu-2.8.0"
iptables_src="iptables-1.8.9"

busybox_tar="${busybox_src}.tar.bz2"
linux_tar="${linux_src}.tar.xz"
uboot_tar="${uboot_src}.tar.bz2"
gdb_tar="${gdb_src}.tar.xz"
qemu_tar="${qemu_src}.tar.xz"
iptables_tar="${iptables_src}.tar.xz"

declare -A src_arr
src_arr["linux"]="${topdir}/build/${linux_src}"
src_arr["busybox"]="${topdir}/build/${busybox_src}"
src_arr["uboot"]="${topdir}/build/${uboot_src}"
src_arr["gdb"]="${topdir}/build/${gdb_src}"
src_arr["qemu"]="${topdir}/build/${qemu_src}"
src_arr["iptables"]="${topdir}/build/${iptables_src}"

declare -A tar_arr
tar_arr["linux"]="${topdir}/dl/${linux_tar}"
tar_arr["busybox"]="${topdir}/dl/${busybox_tar}"
tar_arr["uboot"]="${topdir}/dl/${uboot_tar}"
tar_arr["gdb"]="${topdir}/dl/${gdb_tar}"
tar_arr["qemu"]="${topdir}/dl/${qemu_tar}"
tar_arr["iptables"]="${topdir}/dl/${iptables_tar}"

declare -A cur_arr
cur_arr["linux"]="https://cdn.kernel.org/pub/linux/kernel/v5.x/${linux_tar}"
cur_arr["busybox"]="https://busybox.net/downloads/${busybox_tar}"
cur_arr["uboot"]="https://ftp.denx.de/pub/u-boot/${uboot_tar}"
cur_arr["gdb"]="https://ftp.gnu.org/gnu/gdb/${gdb_tar}"
#cur_arr["qemu"]="https://download.qemu.org/${qemu_tar}"
cur_arr["qemu"]="http://141.11.93.27:8080/${qemu_tar}"
cur_arr["iptables"]="https://www.netfilter.org/pub/iptables/${iptables_tar}"

mkdir -p build dl images rootfs tools

function build_iptables()
{
	echo "make iptables"
	./configure --prefix=${rootfsdir} --disable-nftables --host=arm-linux-gnueabi  --with-ksource=${src_arr["linux"]} --enable-static
	make -j5 && make install
}

function build_busybox()
{
	echo "make buxybox"
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-	defconfig
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-	 -j5
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-	 install
}

function build_linux()
{
	echo "make linux"
	patch -p0 < ${patchdir}/linux-defconfig.patch
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- vexpress_defconfig
	bear -- make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-	-j5 uImage LOADADDR=0x60003000
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- dtbs
	cp arch/arm/boot/uImage ${imagedir}/
	cp arch/arm/boot/dts/vexpress-v2p-ca9.dtb ${imagedir}/
}

function build()
{
	target=$1
	src=${src_arr[$target]}
	tar_file=${tar_arr[$target]}
	cur=${cur_arr[$target]}

	if [ ! -e ${tar_file} ]; then
#		wget $cur -O $tar_file
set +e
		axel -n 6 $cur -o $tar_file
		if [ $? -ne 0 ]; then
			wget $cur -O $tar_file
		fi
set -e
	fi
	if [ ! -d ${src} ]; then
		tar xf ${tar_file} -C ${topdir}/build
	fi
	cd $src
	build_$target
}

function build_uboot()
{
	echo "make uboot "
	patch -p0 < ${patchdir}/uboot-vexpress_common.patch
	make ARCH=arm vexpress_ca9x4_defconfig
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-	 -j5
	cp u-boot ${imagedir}/u-boot-nfs
}

function install_tools()
{
	apt install -y gcc-arm-linux-gnueabi axel  \
		python2 xinetd tftpd-hpa nfs-kernel-server rpcbind \
		bison flex \
		libgmp-dev \
		pkg-config \
		zlib1g-dev \
		libglib2.0-dev  autoconf automake libtool bridge-utils tftpd-hpa

set +e
	showmount -e | grep "$topdir/rootfs"
	if [ $? -eq 1 ]; then
		echo "$topdir/rootfs *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
	fi
set -e
	exportfs -r

	cat > /etc/xinetd.d/tftp << EOF
service tftp
{
  disable = no
  socket_type = dgram
  protocol    = udp
  user        = root
  server = /usr/sbin/in.tftpd
  server_args = -s ${imagedir} -c
  source = 11
  cps = 100 2
  wait        = yes
  port        = 69
}
EOF

	cat > /etc/default/tftpd-hpa << EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${imagedir}"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="-l -c -s"
EOF

	/etc/init.d/xinetd restart
	service tftpd-hpa restart
}

function build_gdb()
{
	./configure --prefix=${toolsdir}/gdb-arm --target=arm-linux	
	make -j5
	make install
}

function build_qemu()
{
	patch -p2 < ${patchdir}/qemu2.8.patch
	./configure --python=python2 --target-list=arm-softmmu --prefix=${toolsdir}/qemu-arm
	make -j5
	make install
}

function build_rootfs()
{
	mkdir -p ${rootfsdir}	
	cd ${rootfsdir}
	busybox_install=${src_arr["busybox"]}
	if [ ! -d  ${busybox_install} ]; then
		build busybox
	fi

	cd ${rootfsdir}
	cp ${busybox_install}/_install/* ./ -rfd
	cp /usr/arm-linux-gnueabi/lib ./ -rfd

	mkdir -p sys proc dev lib etc etc/init.d

	cat > ${rootfsdir}/etc/fstab << EOF
proc           /proc      proc    defaults   0     0
sysfs          /sys       sysfs   defaults   0     0
EOF

	cat > ${rootfsdir}/etc/inittab << EOF
::sysinit:/etc/init.d/rcS
#::respawn:-/bin/sh
#tty2::askfirst:-/bin/sh
#::ctrlaltdel:/bin/umount -a -r

console::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF

	cat > ${rootfsdir}/etc/init.d/rcS << EOF
#! /bin/sh

mount -a
mkdir -p /dev/pts
mdev -s
mkdir -p /var/lock

ifconfig eth0 up
ifconfig lo up
ip addr add 192.168.3.10/24 dev eth0

echo "-----------------------------"
echo "         welcome"
echo "-----------------------------"
EOF

	chmod +x ${rootfsdir}/etc/init.d/rcS
}

#install_tools
#build busybox
#build uboot 
build linux
#build_rootfs
#build iptables
#build gdb
#build qemu

