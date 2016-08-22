#!/bin/bash -e

USEPROC=yes
USEDEVFS=no
USEDEVPTS=yes
USESYSFS=yes
USENETWORK=no
USERUNSHM=yes

# use pbuilder modules for common chroot tasks
. /usr/lib/pbuilder/pbuilder-modules

for i in `cat /home/devel/nfs/instances`; do
	ARCH=`echo $i | cut -d ":" -f 2`
	INST=`echo $i | cut -d ":" -f 1`

	if [ ! -d /home/devel/nfs/$INST ]; then
		echo "instace $INST not found"
		exit 1
	fi

	BUILDPLACE=/home/devel/nfs/$INST
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
done

echo "all package updates done"
