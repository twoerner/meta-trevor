#!/bin/bash

if [ -z "$1" ]; then
	echo "required git command argument missing"
	exit 1
fi

FAILED=""
STATUS=0
BADDIRS=""
ALLUPTODATE=0 # 0->yes 1->no

# cmdline args
KEEPGOING=0
TEMP=$(getopt -o 'k' --long 'keep-going' -n 'gitcmd.sh' -- "$@")
if [ $? -ne 0 ]; then
	echo "getopt error"
	exit 1
fi
eval set -- "$TEMP"
unset TEMP
while true; do
	case "$1" in
		'-k'|'--keep-going')
			KEEPGOING=1
			shift
			continue
			;;
		'--')
			shift
			break
			;;
		*)
			echo "getopt internal error"
			exit 1
			;;
	esac
done
GITCMD=$*

GITCMDIGNORE=""
if [ -f GITCMDIGNORE ]; then
	GITCMDIGNORE=$(cat GITCMDIGNORE)
fi

for GITDIR in `find . -maxdepth 2 -name .git -print | grep -v FAILED | sort`; do
	DIR=`dirname $GITDIR | cut -d'/' -f2`

	# check if we should ignore this directory
	echo $GITCMDIGNORE | grep -w $DIR > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "ignoring \"$DIR\" due to GITCMDIGNORE"
		echo "...done with $DIR"
		echo ""
		continue
	fi

	# check this isn't a build directory
	echo $DIR | grep "build/tmp" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "skipping build dir: $DIR"
		echo "...done with $DIR"
		echo ""
		continue
	fi

	echo "working in $DIR"
	pushd $DIR > /dev/null

	# display git version and branch (before)
	echo -n "  current HEAD (before): "
	git rev-parse HEAD
	echo -n "  branch: "
	git rev-parse --abbrev-ref HEAD

	# check if this repository is already up-to-date
	if [ $ALLUPTODATE -eq 0 ]; then
		if [ "$GITCMD" = "pull" ]; then
			OUTPUT=$(git fetch --dry-run 2>&1)
			if [ -n "$OUTPUT" ]; then
				ALLUPTODATE=1
			fi
		fi
	fi

	git $GITCMD
	if [ $? -ne 0 ]; then
		if [ $KEEPGOING -ne 1 ]; then
			exit 1
		fi
		STATUS=$((STATUS+1))
		BADDIRS="$BADDIRS $DIR"
	fi

	if [ x"$GITCMD" = x"pull" ]; then
		git remote -v | grep "^contrib" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "fetching contrib"
			git fetch contrib

			# cleanup stale branches
			echo "pruning contrib branches"
			git remote prune contrib
		fi
	fi

	# display git version and branch (after)
	echo -n "  current HEAD (after):  "
	git rev-parse HEAD
	echo -n "  branch: "
	git rev-parse --abbrev-ref HEAD

	echo "...done with $DIR"

	popd > /dev/null
	echo ""
done

if [ -n "$FAILED" -a "$GITCMD" = "pull" ]; then
	echo "FAILED: $FAILED"

	for REP in $FAILED; do
		REP=$(echo $REP | cut -d'/' -f2)
		echo "re-cloning failed repository $REP"
		pushd $REP
			REMOTE=$(git remote -v | grep origin | grep fetch | head -1 | cut -f2 | cut -d' ' -f1)
		popd
		git clone $REMOTE ${REP}.new
		if [ $? -eq 0 ]; then
			mkdir -p FAILED
			rm -fr FAILED/$REP
			mv $REP FAILED
			mv ${REP}.new $REP
		else
			echo "clone failure on $REP"
		fi
	done
fi

if [ "$GITCMD" = "pull" ]; then
	if [ $ALLUPTODATE -eq 0 ]; then
		echo "gitcmd.sh: All repositories are up-to-date"
		exit 255
	fi
fi

if [ $STATUS -ne 0 ]; then
	echo "gitcmd.sh: bad dirs -> $BADDIRS"
	exit $STATUS
fi
