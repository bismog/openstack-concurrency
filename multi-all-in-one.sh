#!/usr/bin/env bash

# What we need prepare before run this script
# - flavor: 2 cores + 2 Gigabytes ram
# - create a image, e.g.: openstack image create
# - create a network and subnet, e.g.: openstack network create
# - create a seperate project and user
# ...

# multi-all-in-one.sh -> multi-vm-create.sh
#                     -> multi-vm-stop.sh
#                     -> multi-vm-start.sh
#                     -> multi-vm-reboot.sh
#                     -> multi-vm-delete.sh


function set_quotas() {
    openstack quota set --cores $exp_cores $project_id
    openstack quota set --ram $exp_rams $project_id
    openstack quota set --gigabytes $exp_gigabytes $project_id
    openstack quota set --volumes $exp_volumes $project_id
    openstack quota set --instances $exp_instances $project_id
    neutron quota-update --port $exp_ports --tenant-id $project_id
}

function reset_az() {
    openstack aggregate remove host az-host123 host122
    openstack aggregate remove host az-host123 host124
    openstack aggregate add host az-host123 host123
    openstack aggregate add host az-host123 host121
    openstack aggregate remove host az-host123 host122
    openstack aggregate remove host az-host123 host124
    openstack aggregate show az-host123
}

function vm_perf() {
    scale=$1
    if [[ -z $scale ]]; then
        echo "Parameter scale should not be vacant!"
        exit 1
    fi

    hcount=$((${scale}/15))

    # Create -> Stop -> Start -> Reboot -> Delete
    ops="create stop start reboot delete"
    for op in $ops;do
        operation=${op}-
        chmod +x ./multi-vm-${op}.sh
        bash -x multi-vm-${op}.sh ${scale}
    done
}

function routine() {
    #=======================================#
    #    Initialize quotas
    #=======================================#
    start=$(date +%d-%H:%M:%s)
    echo "Start time: $start"
    
    . $runcom_file
    . ./force-remove.sh
    pushd /home/chml/concurrency/
    set_quotas
    ## reset_az            # Reset to: az-host123 = host121 + host123
    remove_legacy
    
    #=======================================#
    #    x hypervisor 15x instances
    #=======================================#
    # prall_scale="1 2 3 4 5 6 7 8 9 10"
    prall_scale="1 2 3 4"
    for scale in $prall_scale;do
        prall_count=$((scale*15))
        echo "Begin to run test of $scale hypervisor $prall_count instances"
        # available_zone=az-host123:host123
        # bash -x auto-multi-vm-perf.sh $prall_count
        vm_perf $prall_count
        sleep 10
        remove_legacy
        sleep 10
    done

    end=$(date +%d-%H:%M:%s)
    echo "Start time: $start"
    echo "End time: $end"
    popd
}

flavor_id=2u2g
image_id=e2f989bc-28f3-472e-b382-21949ffee517
network_id=1ced5673-f751-44fd-95b4-8e25b26174f5
project_id=7d9268e60ea54683ba4a39d40fdd2bf3
vm_operate=create
sysVolumeSize=8
source_type=image
runcom_file="/home/chml/keystonerc_chml"

# Expect quotas
exp_cores=200
exp_rams=204800
exp_ports=200
exp_gigabytes=5000
exp_volumes=-1
exp_instances=200

base_dir="/home/chml/perf/log/"
while true;do
    timestamp=$(date +%y-%m-%d-%H-%M)
    log_file=${base_dir}${timestamp}.log

    # If there was process in running, exit
    if pgrep -f auto-multi-vm-perf.sh;then
        echo "Already has auto-multi-vm-perf.sh in running, normal exit!"
        exit 0
    fi

    routine 2>&1 1>$log_file
    sleep 10
done
