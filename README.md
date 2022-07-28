# netbootcd-ipxe-bootchain

A modified version of the amazing [IsaacSchemm/netbootcd](https://github.com/IsaacSchemm/netbootcd) to be booted over iPXE, without internet, and bootchain a linux image distro over the network.

The main reason netbootcd-ipxe-bootchain exists is to bootstrap a linux environment as an intermediate (more advanced and flexible) boot environment than grub.

Within this environment we can do clever things, like for example:

    * customize the actual boot process via a custom script that is downloadable from the network, either via tftp or http (by passing nb_provisionurl=<url> as kernel parameter)
    * debug a faulty boot remotely, by logging in over ssh (something we can't do with grub).
    * extract the kernel and ramdisk files from inside an actual boot disk image, and use kexec to boot from it.
    * make a copy of the actual boot image file from the network storage to a local disk cache and boot from it, instead of using NBD, iSCSI or NFS to load the image directly from the network storage.

Associated with iPXE, netbootcd-ipxe-bootchain is a very useful and effective way to remotely administer bare metal computers boot process.

## Build

Just run `make` and it should build it using docker.
After the build, you should find tinycore kernel and initrd inside ./boot/ folder.
In ./boot/ you will also find a messy init.sh example script that can be used by passing `nb_provisionurl=<tftp/http url>/init.sh` parameter to the kernel.

An example of a grub menu option, assuming we have a tftp server at 192.168.0.1, serving this git depot as tftp root:
```
menuentry 'netbootcd-ipxe-bootchain' --class os {
     echo Reading kernel
     linux  boot/vmlinuz  quiet nb_provisionurl=tftp://192.168.0.1/boot/http/init.sh nofstab waitusb norestore base console=tty0 console=ttyS0,115200n8
     echo Reading ramdisk
     initrd boot/nbinit4.gz
     echo booting...
}
```
