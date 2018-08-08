#!/bin/bash
set -x
apt-get install -y sshpass libguestfs-tools 


virsh destroy xr-devbox
virt-copy-in -a ~/sandbox/disks/xr-devbox-ubuntu-16.04.3-server-amd64.vmdk  interfaces /etc/network/
virsh undefine xr-devbox
virsh define ~/virsh-manage/domains/xr-devbox.xml

function run_scp() {
    address=$1
    username=$2
    password=$3
    file1=$4
    file2=$5
    time_out=$6


    timeout $time_out sshpass -p $password scp -o StrictHostKeyChecking=no $file1 ${username}@${address}:$file2 
    return $?
}



function run_ssh_command() {
    address=$1
    username=$2
    password=$3
    cmd=$4
    time_out=$5


    timeout $time_out sshpass -p $password ssh -o StrictHostKeyChecking=no ${username}@${address} "$cmd" 
    return $?
}

function command_retry() {
    cmdtype=$1
    address=$2
    username=$3
    password=$4

    if [[ $cmdtype == "ssh" ]];then
        cmd=$5
        time_out=$6
    elif [[ $cmdtype == "scp" ]];then
        file1=$5
        file2=$6
        time_out=$7
    fi

    count=0
    success=0
    while true
    do
        if  [[ $cmdtype == "ssh" ]];then
            run_ssh_command $address $username $password "$cmd" $time_out
            retvalue=$?
        elif [[ $cmdtype == "scp" ]];then
            run_scp $address $username $password $file1 $file2  $time_out
            retvalue=$?
        fi
        count=$(( $count + 1 ))
        if [[ $retvalue != 0 ]]; then
            if [[ $count != 3 ]]; then
                echo "Trying again"
            else
                break
            fi
        else
            success=1
            break
        fi
    done

    if [[ $success == 0 ]]; then
        if [[ $cmdtype == "ssh" ]];then
            echo "failed to run command: $cmd"
        elif [[ $cmdtype == "scp" ]];then
            echo "failed to scp $file1 to $file2 on $address"
        fi
        exit 1
    fi
}


command_retry "scp" "10.10.20.180" "admin" "admin" ~/virsh-manage/rtrconfigs/r1.config /misc/scratch/ 20
command_retry "ssh" "10.10.20.180" "admin" "admin" "run service sshd_operns start" 10
command_retry "ssh" "10.10.20.180" "admin" "admin" "run chkconfig --add sshd_operns_global-vrf" 10
command_retry "ssh" "10.10.20.180" "admin" "admin" "run echo \"admin ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers" 10
command_retry "ssh" "10.10.20.180" "admin" "admin" "run source /pkg/bin/ztp_helper.sh && xrreplace /misc/scratch/r1.config" 30
virsh destroy xr-r1


command_retry "scp" "10.10.20.181" "admin" "admin" ~/virsh-manage/rtrconfigs/r2.config /misc/scratch/ 20
command_retry "ssh" "10.10.20.181" "admin" "admin" "run service sshd_operns start " 10
command_retry "ssh" "10.10.20.181" "admin" "admin" "run chkconfig --add sshd_operns_global-vrf" 10
command_retry "ssh" "10.10.20.181" "admin" "admin" "run echo \"admin ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers" 10
command_retry "ssh" "10.10.20.181" "admin" "admin" "run source /pkg/bin/ztp_helper.sh && xrreplace /misc/scratch/r2.config" 30
virsh destroy xr-r2


echo -e "GatewayPorts yes" | tee --append /etc/ssh/sshd_config && cat /etc/ssh/sshd_config
systemctl restart sshd

cp ~/virsh-manage/virsh-manage /usr/local/bin/

apt-get purge -y --autoremove libguestfs-tools sshpass 

/usr/local/bin/virsh-manage down -f ~/virsh-manage/Virshfile >/dev/null 2>&1 
