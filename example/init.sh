#reset
NETBOOT_SERVER=192.168.1.231
NETBOOT_IMG_PATH="/root/docker/pxe-manager/tftp"

debug() {
	# install ssh and start it!
	su tc -c 'tce-load -wi openssh'
	cp /usr/local/etc/ssh/sshd_config.orig /usr/local/etc/ssh/sshd_config
	echo "PermitRootLogin	yes" >> /usr/local/etc/ssh/sshd_config
	/usr/local/etc/init.d/openssh start
	echo -e 't\nt\n' | passwd

	# install avahi
	su tc -c 'tce-load -wi avahi'
	/usr/local/etc/init.d/avahi start

	# install nbd
	su tc -c 'tce-load -wi sc101-nbd'
	su tc -c 'tce-load -wi parted'
	depmod -a
	modprobe nbd

	# install lspci
	su tc -c 'tce-load -wi pci-utils'

	ifconfig eth0
}
[ "$(grep debug /proc/cmdline)" != "" ] && debug || echo -n fedora35 > /tmp/selection.txt

mountBoot() {
	if [ "$(mount | grep .tmp.img)" == "" ] ; then
		mkdir -p /tmp/img
		mount -o vers=3,nolock $NETBOOT_SERVER:$NETBOOT_IMG_PATH /tmp/img
	fi
}
umountBoot() {
	umount -f -l /tmp/xx
	# umount -f -l /tmp/root
	#tune2fs -c 0 -i 0 /dev/loop30
	losetup -d /dev/loop30 2>/dev/null || true
	umount -f -l /tmp/img
	sync
}

# download kernel and initrd to boot
menu() {
	mountBoot
	menu=$(ls -1 /tmp/img/*.raw | grep -v vm | sed 's/.raw//g' | awk -F'/' '{print $(NF)"  linux"}')
	rm /tmp/selection.txt
	dialog --timeout 10 --backtitle "$TITLE" --menu "Choose a distribution:" 20 70 15 $menu reboot "" 2>/tmp/selection.txt
        cat /tmp/selection.txt
}
[ "$(grep menu /proc/cmdline)" != "" ] && menu
DISTRO=$(cat /tmp/selection.txt)

getKernel() {
	disk=$1
	# mount nfs tftp
	mountBoot
	# mount image from tftp folder over nfs
	mknod -m 0660 /dev/loop30 b 7 30
	losetup -P /dev/loop30 /tmp/img/$disk
	# mount boot partition and copy kernel+initrd
	mkdir -p /tmp/xx/
	mount -o ro /dev/loop30 /tmp/xx
	vmlinuz=$(ls -rt /tmp/xx/boot/vmlinuz-* |  tail -n 1)
	cp -v $vmlinuz ./kernel
	cp -v $(ls -l /tmp/xx/boot/initr*$(echo $vmlinuz | awk -F'-' '{print $2}')* | awk '{print $(NF)}') ./initrd
	# now mount root and patch fstab if needed (fix image on first boot!)
	# mkdir -p /tmp/root
	# mount -o ro /dev/loop30p3 /tmp/root
	#if [ "$(grep 'nbd0 ' /tmp/xx/etc/fstab)" == "" ] ; then
	#	mount -o remount,rw  /tmp/xx/
	#	echo "/dev/nbd0	/		ext4	defaults			1 1" >  /tmp/xx/etc/fstab
	#	#echo "/dev/nbd0p2	/boot		ext4	defaults			1 2" >> /tmp/xx/etc/fstab
	#	#echo "/dev/nbd0p1	/boot/efi	vfat	umask=0077,shortname=winnt	0 2" >> /tmp/xx/etc/fstab

	#        echo -e "\n[ipv4]" >> /etc/NetworkManager/NetworkManager.conf
        #	echo "never-default=true" >> /etc/NetworkManager/NetworkManager.conf
	#	mount -o remount,ro /tmp/xx/
	#fi
        #if [ ! -e /etc/sysconfig/readonly-root ] ; then
        #        mount -o remount,rw  /tmp/xx/
        #        echo "READONLY=yes" > /etc/sysconfig/readonly-root
        #        mount -o remount,ro  /tmp/xx/
        #fi
	umountBoot
}

getKernelFromNBD() {
	disk=$1
	echo Retrieving kernel and initramfs from disk image $disk...
	# mount nfs tftp
	nbd-client -b 512 -N $disk -p $NETBOOT_SERVER /dev/nbd0
	# mount boot partition and copy kernel+initrd
	mkdir -p /tmp/boot/
	mount -o ro /dev/nbd0p2 /tmp/boot
#	cp -v $(ls -l /tmp/boot/vmlinuz-* | sort -V | tail -1 | awk '{print $(NF)}') ./kernel
#	cp -v $(ls -l /tmp/boot/initr*$(ls -l /tmp/boot/vmlinuz-* | sort -V | tail -1 | awk '{print $(NF)}' | awk -F'-' '{print $2}')* | awk '{print $(NF)}') ./initrd
	# now mount
	#mkdir -p /tmp/root
	#mount /dev/loop30p3 /tmp/root
	#echo "/dev/nbd0p3	/		ext4	defaults			1 1" >  /mnt/root/fstab
	#echo "/dev/nbd0p2	/boot		ext4	defaults			1 2" >> /mnt/root/fstab
	#echo "/dev/nbd0p1	/boot/efit	vfat	umask=0077,shortname=winnt	0 2" >> /mnt/root/fstab
#	umountBoot
}

if [ $DISTRO = "reboot" ] ; then
	reboot

elif [ $DISTRO = "fedora34" ] ; then
	wget -O kernel 'http://$NETBOOT_SERVER:81/tftp/disk0-boot/vmlinuz'
	wget -O initrd 'http://$NETBOOT_SERVER:81/tftp/disk0-boot/initrd'
	reset
	clear
#	kexec -l /home/tc/kernel --initrd=/home/tc/initrd --append='root=/dev/nbd0p2 netroot=nbd:'$NETBOOT_SERVER':disk0:::-b512 ip=single-dhcp ro rd.break=initqueue rd.shell=1 rd.debug systemd.debug-shell=1 net.ifnames=0 biosdevname=0 audit=0 ' 2>/dev/null
	kexec -l /home/tc/kernel --initrd=/home/tc/initrd --append='root=/dev/nbd0p2 netroot=nbd:'$NETBOOT_SERVER':disk0:none:defaults:-b512,-p ip=dhcp ro systemd.debug-shell=1 net.ifnames=0 biosdevname=0 audit=0 quiet rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 rd.skipfsck rd.info rd.fstab=0 ' 2>/dev/null
	sync
	kexec -e

#elif [ $DISTRO = "debian11" ] ; then
elif [ $DISTRO = "fedora35" ] ; then
	if [ "$(dmesg | egrep 'Hyp|base_baud')" != "" ] ; then
		export kvm=" console=ttyS0,115200n8 console=tty console=tty0 "
	fi
	disk=disk1
	getKernel $disk
	if [ -e /sys/firmware/efi/systab ] ; then
		efi="acpi_rsdp=$(sudo grep -m1 ^ACPI /sys/firmware/efi/systab | cut -f2- -d=)"
		# echo $efi
	fi
	#kexec -l /home/tc/kernel --initrd=/home/tc/initrd --append='root=/dev/nbd0 netroot=nbd:'$NETBOOT_SERVER':'$disk':none:defaults,rw,noatime:--timeout=0,-p,-s,-systemd-mark  ip=dhcp ro systemd.debug-shell=1 net.ifnames=0 biosdevname=0 audit=0 selinux=0 quiet rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 rd.skipfsck rd.info rd.fstab=0 quiet modprobe.blacklist=nouveau  console=tty0  console=ttyS0,115200n8 tftp=192.168.1.231  '$efi' reboot=acpi systemd.mask=NetworkManager systemd.mask=firewalld systemd.mask=firewall systemd.mask=docker systemd.mask=systemd-zram-setup@zram0 systemd.mask=systemd-zram-setup fsck.mode=skip rcutree.rcu_idle_gp_delay=1 mem_encrypt=off pci=nocrs,noearly audit=0 selinux=0 panic=30 fastboot ' 2>/dev/null
#		rhgb
#		overlay=/tmp/nbd1
#		console=tty console=tty0 console=ttyS0,115200n8

#	debug=" rd.debug rd.shell rd.break=pre-mount rd.break=mount "
	cache_name=$(echo $(cat /proc/cmdline) | sed 's/ /\n/g' | grep cache_label | awk  -F'=' '{print $2}')
    	if [ "$cache_name" == "" ] ; then
        	cache_name=CACHE
    	fi

	cmdline=$(echo 'root=/dev/nbd0 netroot=nbd:'$NETBOOT_SERVER':'$disk':none:defaults,rw,noatime:  rd.shell=1
		modprobe.blacklist=nouveau
		ip=dhcp
		rw systemd.debug-shell=1   tftp=192.168.1.231
		net.ifnames=0 biosdevname=0 audit=0 selinux=0
		rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 rd.skipfsck=0 rd.info=1 rd.fstab=0 fsck.mode=skip
		'$efi' reboot=acpi
		systemd.mask=firewalld
		systemd.mask=firewall
		systemd.mask=docker
		systemd.mask=systemd-zram-setup@zram0
		systemd.mask=systemd-zram-setup
		systemd.mask=NetworkManager
		systemd.mask=lvm2-monitor
		systemd.mask=abrt-desktop
		systemd.mask=abrt-cli
		systemd.mask=abrt
		rcutree.rcu_idle_gp_delay=1 mem_encrypt=off pci=nocrs,noearly
		cache_label='$cache_name'
		'$debug'
		quiet '$kvm'
	' | tr -d '\n')
	kexec -l /home/tc/kernel --initrd=/home/tc/initrd --append="$(echo $cmdline)" 2>/dev/null
	#sh
	kexec -e
fi
