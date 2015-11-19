#!/bin/zsh

## Get script directory.
export SCRIPTD=${0:a:h}

export ROOTFS=arch-rootfs
export ROOTFS_SIZE=400M

## List of packages to be installed
export PKGS=()

## List of additional to be installed after main PKGS
export PKGS_ADD=()

## List of files and their destination to be copied to rootfs.
## Using associative array.
typeset -A FILES

FILES=(${SCRIPTD}/bootstrap.sh ${ROOTFS}/)

rootfs_must_root() {
	if [[ $EUID != 0 ]]; then
		echo "This script must be run with root privileges"
		exit 1
	fi
}

rootfs_create() {
	echo "==> create rootfs ${ROOTFS}"
	mkdir -p $ROOTFS
}

rootfs_mount() {
	echo "==> mounting ${ROOTFS} as tmpfs"
	## safety first, make sure we do not mount rootfs recursively
	umount -R "$ROOTFS"
	mount -t tmpfs -o size=${ROOTFS_SIZE} tmpfs "$ROOTFS"
}

rootfs_install() {
	${SCRIPTD}/pacstrap.sh -c -d "$ROOTFS" ${PKGS}

	if [[ ${#PKGS_ADD} > 0 ]]; then
		${SCRIPTD}/pacstrap.sh -c -d "$ROOTFS" ${PKGS_ADD}
	fi
}

rootfs_copy() {
	echo "==> copying files ..."

	for k in "${(@k)FILES}"; do
		echo "    from $k to $FILES[$k]"
		cp $k $FILES[$k]
	done
}

rootfs_bootstrap() {
	RUN_BOOTSTRAP="${ROOTFS}/run_bootstrap.sh"
	VAR_BOOTSTRAP="${ROOTFS}/vars.sh"

	echo "==> bootstraping ... ${RUN_BOOTSTRAP}"

	## generate vars for bootstrap
	echo '#!/bin/bash' > ${VAR_BOOTSTRAP}
	echo "PKGS_REMOVED=($PKGS_REMOVED)" >> ${VAR_BOOTSTRAP}

	## generate bootstrap script.
	echo '#!/bin/bash' > ${RUN_BOOTSTRAP}
	echo '. ./vars.sh' >> ${RUN_BOOTSTRAP}

	for (( i = 1; i <= ${#BOOTSTRAP_S}; i++ )) do
		echo ". $BOOTSTRAP_S[$i]" >> ${RUN_BOOTSTRAP}
	done
	chmod +x ${RUN_BOOTSTRAP}

	## run the bootstrap script.
	arch-chroot "$ROOTFS" /bin/sh -c "/`basename ${RUN_BOOTSTRAP}`"
}

##
## (1) set root fs.
## (2) create root fs directory.
## (3) mount root fs as tmpfs.
## (4) run pacstrap.
## (5) copy bootstrap script and default pacman config.
## (6) run bootstrap script in new root fs.
##
rootfs_main() {
	rootfs_create
	rootfs_mount
	rootfs_install
	rootfs_copy
	rootfs_bootstrap
}

##
## Convert rootfs to docker image.
##
rootfs_to_docker() {
	if [[ $# < 2 ]]; then
		echo "args: rootfs_to_docker [image-name]"
		exit 1
	fi

	sudo tar --numeric-owner --xattrs --acls -C "$ROOTFS" -c . |
		docker import ${@:2} - $1
}

##
## Unmount and remove rootfs.
##
rootfs_clean() {
	sudo umount -R $ROOTFS
	rm -f ${ROOTFS}/*
	rmdir ${ROOTFS}
}