
PXE_TEMP_IP:=192.168.1.250
PXE_TFTP:=192.168.1.231

UID=$(shell id -u)
GID=$(shell id -g)

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

all:
	if [ "$$(grep Debian /etc/os-release)" == "" ] ; then \
		docker build . -t netbootcd-ipxe-bootchain-build ;\
		docker run --privileged=true -v $(ROOT_DIR):$(ROOT_DIR) netbootcd-ipxe-bootchain-build /bin/bash -c 'cd $(ROOT_DIR) && make UID=$(UID) GID=$(GID)' ;\
	else \
		apt install -y zip dosfstools syslinux-utils genisoimage ;\
		cp -rfv $(ROOT_DIR)/Build.sh $(ROOT_DIR)/netbootcd/Build_bootchain.sh &&\
		cd $(ROOT_DIR)/netbootcd &&\
		./Build_bootchain.sh &&\
		cd $(ROOT_DIR) &&\
		cp -rfv $(ROOT_DIR)/netbootcd/done/vmlinuz $(ROOT_DIR)/ &&\
		cp -rfv $(ROOT_DIR)/netbootcd/done/nbinit4.gz $(ROOT_DIR)/ &&\
		if [ "$$(mount | grep tcisomnt)" != "" ] ; then\
		 	umount $(ROOT_DIR)/netbootcd/work/tcisomnt ; \
		fi ;\
		chmod a+xwr -R $(ROOT_DIR)/netbootcd/work ; \
		chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/work ;\
		chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/done ;\
		chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/Core* ;\
		chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/Build_bootchain* ;\
		chown -R $(UID):$(GID) $(ROOT_DIR)/nbinit4.gz ;\
		chown -R $(UID):$(GID) $(ROOT_DIR)/vmlinuz ;\
	fi

clean:
	rm -rf \
		nbinit4.gz vmlinuz \
		./netbootcd/work \
		./netbootcd/done \
		./netbootcd/Core* \
		./netbootcd/Build_bootchain.sh

#include $(GRUB_ROOT_DIR)Makefile
