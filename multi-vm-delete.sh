#!/bin/bash

scale=$1

if [[ -z $scale ]]; then
    echo "Parameter scale should not be vacant!"
    exit 1
fi

vm_name=test_poc_${scale}vm
prall_count=$scale

vm_stat=ACTIVE
vm_operate=delete
# vm_end_stat=SHUTOFF

startTime=`date +"%Y-%m-%d %H:%M:%S.%N"`

vms=$(nova list | awk -F '|' '/test_poc_/{print $2}' | xargs)
for vm in $vms;do
    nova $vm_operate $vm
done

while [[ 1 -eq 1 ]]; do
    instance_numer=$(mysql nova -Nse "select uuid from instances where project_id='7d9268e60ea54683ba4a39d40fdd2bf3' and deleted=0" | wc -l)
    if [[ $instance_number -eq 0 ]]; then
        echo "All instnaces removed"
        break
    else
        echo "Has instance which wasn't as expect, continue waiting"
    fi
    sleep 1
done

#==================获取端到端精确时间==============================
endTime=`date +"%Y-%m-%d %H:%M:%S.%N"`

start_time=`date -d  "$startTime" +%s.%N`
finish_time=`date -d "$endTime" +%s.%N`
interval=$(echo "scale=2;($finish_time-$start_time)/1" | bc)
echo $vm_operate $prall_count VM, spfinishTime=$interval s, startTime=`echo $startTime`  finishTime=`echo $endTime`

# Write to out file
out_dir=/home/chml/perf/all_in_one/${vm_operate}/
mkdir -p $out_dir
out_file=$(date +%Y_%m_%d_%H_%M)
echo $vm_operate $scale $interval >> ${out_dir}${out_file}
