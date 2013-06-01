#!/bin/bash

if [ -z "$1" ]; then
	echo "required git command argument missing"
	exit 1
fi

FAILED=""

for GITDIR in `find . -name .git -print`; do
	DIR=`dirname $GITDIR`
	echo "working in $DIR"
	pushd $DIR > /dev/null
	COUNT=0
	while [ 1 ]; do
		echo "attempt $COUNT"
		git "$1"
		if [ $? -ne 0 ]; then
			COUNT=`expr $COUNT + 1`
			if [ $COUNT -gt 10 ]; then
				echo "giving up on $DIR"
				FAILED="$FAILED $DIR"
				break
			fi
		else
			break
		fi
	done

	DIRNAME=$(basename $(pwd))
	if [ x"$DIRNAME" = x"meta-openembedded" -o x"$DIRNAME" = x"openembedded-core" -o x"$DIRNAME" = x"meta-poky" ]; then
		echo "fetching contrib"
		git fetch contrib
	fi

	popd > /dev/null
	echo ""
done

if [ -n "$FAILED" ]; then
	echo "FAILED: $FAILED"
fi
