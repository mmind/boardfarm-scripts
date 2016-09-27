#!/bin/bash -e

numarg=$#
board=$1
newstate=$2

for i in `cat /home/devel/nfs/instances | grep -v "^#"`; do
	INST=`echo $i | cut -d ":" -f 1`

	if [ "$INST" != "$board" ]; then
		continue
	fi

	PWRMETHOD=`echo $i | cut -d ":" -f 4`
	PWRDEVICE=`echo $i | cut -d ":" -f 5`
	PWRINDEX=`echo $i | cut -d ":" -f 6`

	case $PWRMETHOD in
		"ykush")
			# if we want to do a state change
			if [ "$numarg" = "2" ]; then
				if [ "$newstate" = "1" ]; then
					ykush -s $PWRDEVICE -u $PWRINDEX 2>/dev/null
				else
					ykush -s $PWRDEVICE -d $PWRINDEX 2>/dev/null
				fi
			fi

			tmp=`ykush -s $PWRDEVICE -g $PWRINDEX 2>/dev/null | grep "Downstream port" | cut -d ":" -f 2`
			if [ "$tmp" = " DOWN" ]; then
				state="off"
			else
				state="on"
			fi
			;;
		"fritzdect")
			# if we want to do a state change
			if [ "$numarg" = "2" ]; then
				/home/devel/hstuebner/bootfarm/fritzdect/powerain.php $PWRDEVICE $newstate
			fi

			tmp=`/home/devel/hstuebner/bootfarm/fritzdect/queryain.php $PWRDEVICE | grep "state" | cut -d ":" -f 2`
			if [ "$tmp" = "1" ]; then
				state="on"
			else
				state="off"
			fi
			;;
		*)
			echo "unknown method $PWRMETHOD"
			exit 1
			;;
	esac
done

echo "Board $board is $state"
