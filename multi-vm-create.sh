#!/bin/bash

scale=$1
if [[ -z $scale ]]; then
    echo "Parameter scale should not be vacant!"
    exit 1
fi

# . /home/chml/keystonerc_chml 
# . ./force-remove.sh
# remove_legacy

project_id=7d9268e60ea54683ba4a39d40fdd2bf3
flavor_id=2u2g
image_id=e2f989bc-28f3-472e-b382-21949ffee517
net_id=1ced5673-f751-44fd-95b4-8e25b26174f5
available_zone=az-host123
vm_name=test_poc_${scale}vm

#================以下不可更改====================================================================
sysVolumeSize=8
source_type=image
prall_count=$scale
vm_operate=create

nova boot --flavor $flavor_id  --block-device id=$image_id,source=$source_type,dest=volume,type=disk,size=$sysVolumeSize,bootindex=0  --nic net-id=$net_id --availability-zone=$available_zone --min-count=$prall_count $vm_name &
echo waiting create_vm complete  
sleep 25
#==================检查VM状态======================================
while [[ 1 -eq 1 ]]
do
    active_res=`nova list |grep $vm_name  |grep -w ACTIVE |wc -l`
    echo success_num=$active_res &
    if((active_res==prall_count)); then
        break;
    fi
done

# Show distribution of instances
hypervisors=$(mysql nova -Nse "select hypervisor_hostname from compute_nodes" | xargs)
for hv in $hypervisors; do
    echo 
    nova list --host $hv
    vm_count=$(mysql nova -Nse "select uuid from instances where project_id='$project_id' and host='$hv' and deleted=0" | wc -l)
    echo There were $vm_count instances created on $hv
done

#==================获取端到端精确时间==============================
time_item_array=()
for vmid in `nova list |grep $vm_name  |grep -w ACTIVE | awk '{print $2}'`; do
    s2e=$(mysql nova -Nse "select start_time,finish_time from instance_actions_events where action_id in (select id from instance_actions where instance_uuid='$vmid' and action='create' and deleted=0)")
    st=$(echo $s2e | awk '{print $1,$2}')
    start_time=$(date -d "$st" +%s.%N) 
    ft=$(echo $s2e | awk '{print $3,$4}')
    finish_time=$(date -d "$ft" +%s.%N)
    time_item_array=(${time_item_array[*]} `echo "$start_time"` `echo "$finish_time"`)
    echo vmid=$vmid  start_time=`echo $start_time`  finish_time=`echo $finish_time`
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
