
# retrieve the latest tinycore version available from their website.
COREVER=$(shell curl 'http://www.tinycorelinux.net/downloads.html' | grep 'Version ' | awk -F'Version ' '{print $$2}' | awk '{print $$1}')

# extra packages to pre-install in our little distro
EXTRA_PKGS="\
	avahi.tcz\
	dbus.tcz\
	expat2.tcz\
	gcc_libs.tcz\
	glib2.tcz\
	libavahi.tcz\
	libdaemon.tcz\
	libffi.tcz\
	liblvm2.tcz\
	libpci.tcz\
	ncursesw.tcz\
	nss-mdns.tcz\
	openssh.tcz\
	openssl-1.1.1.tcz\
	parted.tcz\
	pci-utils.tcz\
	readline.tcz\
	sc101-nbd.tcz\
	udev-lib.tcz\
"

# we use uid and gid to keep files with the correct permissions, since docker
# runs as root user!
UID=$(shell id -u)
GID=$(shell id -g)

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

all: netbootcd/README build_docker_image_and_run
build_docker_image_and_run:
	cd $(ROOT_DIR)/src/ &&\
	docker build . -t netbootcd-ipxe-bootchain-build &&\
	docker run \
		--rm \
		--privileged=true \
		-v $(ROOT_DIR):$(ROOT_DIR) \
		netbootcd-ipxe-bootchain-build \
		/bin/bash -c 'cd $(ROOT_DIR) && make UID=$(UID) GID=$(GID) docker_build'

# we use our custom src/Build.sh file to create a Build_bootchain.sh
# script on netbootcd. Here we setup the tinycore version and extra_pkgs
# that will be download and pre-installed.
patch_build_sh: src/Build.sh
	cat $(ROOT_DIR)/src/Build.sh \
		| sed 's/__COREVER__/$(COREVER)/g' \
		| sed 's/__EXTRA_PKGS__/$(EXTRA_PKGS)/g' \
	> $(ROOT_DIR)/netbootcd/Build_bootchain.sh &&\
	chmod a+x $(ROOT_DIR)/netbootcd/Build_bootchain.sh

# we replace wget by curl on nbscript, so we can also
# use tftp to download nb_provisionurl script with tftp://
patch_nbscript_sh:
	cp $(ROOT_DIR)/netbootcd/nbscript.sh /dev/shm &&\
	cat /dev/shm/nbscript.sh \
		| sed 's/wget -O /curl -L -o /g' \
	> $(ROOT_DIR)/netbootcd/nbscript.sh

netbootcd/README:
	cd $(ROOT_DIR)/ && \
	git pull --recurse-submodules && \
	git submodule update --init && \
	git submodule update --recursive

docker_build: patch_build_sh patch_nbscript_sh
	cd $(ROOT_DIR)/netbootcd &&\
	./Build_bootchain.sh && \
	cd $(ROOT_DIR) &&\
	mkdir -p $(ROOT_DIR)/boot/ && \
	cp -rfv $(ROOT_DIR)/netbootcd/done/vmlinuz $(ROOT_DIR)/boot/ &&\
	cp -rfv $(ROOT_DIR)/netbootcd/done/nbinit4.gz $(ROOT_DIR)/boot/ &&\
	cp -rfv $(ROOT_DIR)/example/* $(ROOT_DIR)/boot/ &&\
	if [ "$$(mount | grep tcisomnt)" != "" ] ; then\
	 	umount $(ROOT_DIR)/netbootcd/work/tcisomnt ; \
	fi ;\
	rm -rf $(ROOT_DIR)/netbootcd/Build_bootchain.sh ;\
	chmod a+xwr -R $(ROOT_DIR)/netbootcd/work ; \
	chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/work ;\
	chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/done ;\
	chown -R $(UID):$(GID) $(ROOT_DIR)/netbootcd/Core* ;\
	chown -R $(UID):$(GID) $(ROOT_DIR)/boot

clean:
	rm -rf \
		$(ROOT_DIR)/boot \
		$(ROOT_DIR)/netbootcd/work \
		$(ROOT_DIR)/netbootcd/done \
		$(ROOT_DIR)/netbootcd/Core* \
		$(ROOT_DIR)/netbootcd/Build_bootchain.sh
	cd netbootcd && git checkout -f
