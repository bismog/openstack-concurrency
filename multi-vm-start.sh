#!/bin/bash

scale=$1

if [[ -z $scale ]]; then
    echo "Parameter scale should not be vacant!"
    exit 1
fi

vm_name=test_poc_${scale}vm
prall_count=$scale

vm_stat=SHUTOFF
vm_operate=start
vm_end_stat=ACTIVE

vms=$(nova list | awk -F '|' '/test_poc_/{print $2}' | xargs)
for vm in $vms;do
    nova $vm_operate $vm
done

while [[ 1 -eq 1 ]]; do
    if nova list | grep ${vm_name} | awk -F '|' '{print $4}' | grep -v $vm_end_stat; then
        echo "Has instance which wasn't $vm_end_stat, continue waiting"
    else
        break
    fi
    sleep 2
done

#==================获取端到端精确时间==============================
time_item_array=()
for vmid in `nova list |grep $vm_name  |grep -w $vm_end_stat | awk '{print $2}'`; do
    s2e=$(mysql nova -Nse "select start_time,finish_time from instance_actions_events where action_id in (select id from instance_actions where instance_uuid='$vmid' and action='$vm_operate' and deleted=0)")
    st=$(echo $s2e | awk '{print $1,$2}')
    start_time=$(date -d "$st" +%s.%N)
    ft=$(echo $s2e | awk '{print $3,$4}')
    finish_time=$(date -d "$ft" +%s.%N)
    time_item_array=(${time_item_array[*]} `echo "$start_time"` `echo "$finish_time"`)
    echo vmid=$vmid  vm_reqId=$vm_reqId   start_time=`echo $start_time`  finish_time=`echo $finish_time`
done

min_start_time=`printf '%s\n' "${time_item_array[@]}" | sort -n | head -1`
max_end_time=`printf '%s\n' "${time_item_array[@]}" | sort -n | tail -1`
interval=$(echo "scale=2;($max_end_time-$min_start_time)/1" | bc)
echo $vm_operate $prall_count VM, spfinishTime=$interval s, startTime=`date -d @$min_start_time +"%Y-%m-%d %H:%M:%S.%N"`  finishTime=`date -d @$max_end_time +"%Y-%m-%d %H:%M:%S.%N"`

# Write to out file
out_dir=/home/chml/perf/all_in_one/${vm_operate}/
mkdir -p $out_dir
out_file=$(date +%Y_%m_%d_%H_%M)
echo $vm_operate $scale $interval >> ${out_dir}${out_file}
