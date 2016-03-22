#!/bin/bash
a=$@
echo "arguments=${a}"
timeout=`echo $a | awk -F : '{print $1 }' ` #minute 
timeout=$(( timeout * 60 ))
command=`echo $a | awk -F : '{print $2 }' `
echo "nohup $command"
nohup $command &
command_id=$!
echo "`date` command_id=${command_id}"
echo "`date` watching for ${timeout} seconds to kill ${command_id}"
counter=0
sleeptime=5
while [ true ]; do
	if [ -d /proc/${command_id} ]; then
		if [ ${counter} -gt ${timeout} ]; then
			break
		fi
		echo " ... still watching after $counter seconds ... "
	else
		break
	fi
        sleep ${sleeptime}
        counter=$(( counter + sleeptime ))
done
#sleep $timeout
echo "`date` killing ${command_id} "
kill -9 ${command_id}
echo "`date` done"
