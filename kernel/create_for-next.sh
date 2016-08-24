#!/bin/bash -e

if [ "x$1" = "x" ]; then
	echo "missing version argument"
	echo "usage: create_for-next.sh v4.6"
	exit 1
fi

git checkout for-next
for i in `git branch | grep "$1" | grep -v "shared"`; do
	echo $i
	git merge --no-edit --no-ff $i
done

