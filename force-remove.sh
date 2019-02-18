#!/usr/bin/env bash

network_id=1ced5673-f751-44fd-95b4-8e25b26174f5
project_id=7d9268e60ea54683ba4a39d40fdd2bf3
# runcom_file="/home/chml/keystonerc_chml"


function reset_quota_usage() {

    # instances relate usage
    mysql nova -e "update quota_usages set in_use=0 where project_id='$project_id' and resource='instances' and deleted=0"
    mysql nova -e "update quota_usages set in_use=0 where project_id='$project_id' and resource='ram' and deleted=0"
    mysql nova -e "update quota_usages set in_use=0 where project_id='$project_id' and resource='cores' and deleted=0"
    mysql nova -e "select project_id,resource,in_use from quota_usages where project_id='$project_id'"
    
    # port usage
    mysql neutron -e "update quotausages set in_use=0 where tenant_id='$project_id' and resource='port'"
    mysql neutron -e "select tenant_id,resource,in_use,reserved from quotausages where tenant_id='$project_id'"

    # volume relate usage
    mysql cinder -e "update quota_usages set in_use=0 where project_id='$project_id' and resource='volumes' and deleted=0"
    mysql cinder -e "update quota_usages set in_use=0 where project_id='$project_id' and resource='gigabytes' and deleted=0"
    mysql cinder -e "select project_id,resource,in_use,reserved from quota_usages where project_id='$project_id' and deleted=0"
}

function remove_instances() {
    # Remove all instances of current project
    ilist=$(mysql nova -Nse "select uuid from instances where project_id='$project_id' and deleted=0")
    for i in $ilist;do
        mysql nova -e "delete from block_device_mapping where instance_uuid='$i'"
        mysql nova -e "delete from instance_info_caches where instance_uuid='$i'"
        mysql nova -e "update fixed_ips set allocated=0 where instance_uuid='$i'"
        mysql nova -e "delete from instance_actions_events where action_id in (select id from instance_actions where instance_uuid='$i')"
        mysql nova -e "delete from instance_actions where instance_uuid='$i'"
        mysql nova -e "delete from instance_faults where instance_uuid='$i'"
        mysql nova -e "delete from instance_extra where instance_uuid='$i'"
        mysql nova -e "delete from instance_system_metadata where instance_uuid='$i'"
        mysql nova -e "delete from instances where uuid='$i'"
    done
}

function remove_volumes() {
    # Forcely remove cinder volumes
    vlist=$(mysql cinder -Nse "select id from volumes where project_id='$project_id' and deleted=0" | xargs)
    for v in $vlist;do
        cinder reset-state --state available $v
        mysql cinder -e "delete from volume_admin_metadata where volume_id='$v'"
        mysql cinder -e "delete from volume_attachment where volume_id='$v'"
        mysql cinder -e "delete from volume_glance_metadata where volume_id='$v'"
        mysql cinder -e "delete from volumes where id='$v'"
    done
}

function remove_ports() {
    # Remove all ports relate to 1ced5673-f751-44fd-95b4-8e25b26174f5
    mysql neutron -e "delete from ports where network_id='$network_id' and tenant_id='$project_id'"
}


function remove_legacy() {
    # # Remove legacy resources
    vms=$(nova list | awk -F '|' '/test_poc_/{print $2}' | xargs)
    for vm in $vms;do
        nova delete $vm 1>/dev/null
    done

    sleep 10

    avolume=$(cinder list | awk -F '|' '/available/{print $2}' | xargs)
    for v in $avolume;do 
        cinder delete $v 1>/dev/null
    done

    # For some reason, nova delete and cinder delete can not remove some resources
    # Following function get rid of them from database.
    remove_instances
    remove_volumes
    remove_ports

    reset_quota_usage
}

# . $runcom_file
# remove_legacy
