#!/bin/bash -e

if [ "x$1" = "x" ]; then
	echo "missing version argument"
	echo "usage: recreate_for-next.sh v4.6"
	exit 1
fi

which realpath > /dev/null
if [ "$?" != "0" ]; then
	echo "realpath not found"
	exit 1
fi

PWD=`realpath $0`
PWD=`dirname $PWD`

if [ ! -f $PWD/create_for-next.sh ]; then
	echo "create_for-next.sh not found"
	exit 1
fi

if [ "x$2" = "x" ]; then
	gitrev="master"
else
	gitrev=$2
fi

git checkout $gitrev
git branch -D for-next
git checkout -b for-next
$PWD/create_for-next.sh $1
