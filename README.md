# netbootcd-ipxe-bootchain

A modified version of the amazing IsaacSchemm/netbootcd to be booted over iPXE, without internet, and bootchain a linux image distro over the network. 

The main reason netbootcd-ipxe-bootchain exists is to bootstrap a linux environment quickly, to extract the kernel and ramdisk from inside the actual boot image, and use kexec to boot it. 

We can also use it to do clever things, like make a copy of the actual boot image file to a local disk cache and boot from it, instead of using NBD, iSCSI or NFS to load the image directly from the network. 

