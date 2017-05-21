#!/bin/bash -e

USEPROC=yes
USEDEVFS=no
USEDEVPTS=yes
USESYSFS=yes
USENETWORK=no
USERUNSHM=yes

# use pbuilder modules for common chroot tasks
. /usr/lib/pbuilder/pbuilder-modules

update_chroot() {
	local ARCH=$1
	local INST=$2

	if [ ! -d /home/devel/nfs/rootfs-$INST ]; then
		echo "instace $INST not found"
		exit 1
	fi

	BUILDPLACE=/home/devel/nfs/rootfs-$INST
	CHROOTEXEC="chroot $BUILDPLACE "

	mountproc
	set +e

	echo "Updating packages of $INST"
	$CHROOTEXEC apt-get -q "${APTGETOPT[@]}" update
	$CHROOTEXEC apt-get -q -y "${APTGETOPT[@]}" "${FORCE_CONFNEW[@]}" dist-upgrade
	$CHROOTEXEC apt-get -q -y "${APTGETOPT[@]}" autoremove
	$CHROOTEXEC apt-get clean

	set -e
	umountproc
}

#update source repos
update_chroot arm64 arm64-base
update_chroot arm32 armhf-base

#update real instances
for i in `cat /home/devel/nfs/instances | grep -v "^#"`; do
	ARCH=`echo $i | cut -d ":" -f 2`
	INST=`echo $i | cut -d ":" -f 1`

	update_chroot $ARCH $INST
done

echo "all package updates done"
