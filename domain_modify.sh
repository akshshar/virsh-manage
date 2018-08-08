#!/bin/bash

apt-get install -y sshpass libguestfs-tools

virt-copy-in -a ~/sandbox/disks/xr-devbox-ubuntu-16.04.3-server-amd64.vmdk  interfaces /etc/network/

virsh destroy xr-devbox
virsh undefine xr-devbox
virsh define ~/virsh-manage/domains/xr-devbox.xml

sshpass -p admin scp  -o StrictHostKeyChecking=no ~/virsh-manage/rtrconfigs/r1.config admin@10.10.20.180:/misc/scratch/
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.180 "run service sshd_operns start"
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.180 "run chkconfig --add sshd_operns_global-vrf"
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.180 "run echo \"admin ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers && cat /etc/sudoers"
timeout 30 sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.180 "run source /pkg/bin/ztp_helper.sh && xrreplace /misc/scratch/r1.config"
virsh destroy xr-r1

sshpass -p admin scp  -o StrictHostKeyChecking=no ~/virsh-manage/rtrconfigs/r2.config admin@10.10.20.181:/misc/scratch/
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.181 "run service sshd_operns start"
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.181 "run chkconfig --add sshd_operns_global-vrf"
sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.181 "run echo \"admin ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers && cat /etc/sudoers"
timeout 30  sshpass -p admin ssh  -o StrictHostKeyChecking=no admin@10.10.20.181 "run source /pkg/bin/ztp_helper.sh && xrreplace /misc/scratch/r2.config"
virsh destroy xr-r2

echo -e "GatewayPorts yes" | tee --append /etc/ssh/sshd_config && cat /etc/ssh/sshd_config
systemctl restart sshd

cp ~/virsh-manage/virsh-manage /usr/local/bin/
