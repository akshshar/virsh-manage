#!/bin/bash


usage="
$(basename "$0") [-h] [-u/--up -d/--down -v/--verbose -f/--virshfile] -- cron script to enforce port forwarding if systemd kills forwarding. 

where:
    -h  show this help text
    -v  get more verbose information during script execution
    -f  Specify location of Virshfile, if not specfied, Virshfile is looked for in the current directory
"

while true; do
  case "$1" in
    -v | --verbose )     VERBOSE=true; shift ;;
    -h | --help )        echo "$usage"; exit 0 ;;
    -f | --virshfile )   VIRSHFILE=$2; shift; shift;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done


if [[ $VIRSHFILE == "" ]]; then
    if [[ -f ${PWD}/Virshfile ]]; then
        VIRSHFILE=${PWD}/Virshfile
    else
        echo "No Virshfile specified and no Virshfile found in current directory - bailing out"
        exit 1
    fi
fi

virshdirectory=`dirname $(readlink -f $VIRSHFILE)`
source $VIRSHFILE

port_down=0


function check_port_open()
{
    tunnel_port=$1
    node_type=$2
    port_open=`nc -w 2 localhost $tunnel_port </dev/null >/dev/null 2>&1; echo $?`    

    if [[ $port_open != 0 ]]; then
        echo "Port $tunnel_port for node $node_type is down"
        port_down=1
    else
        if [[ $VERBOSE == true ]]; then
          echo "Port $tunnel_port for node $node_type is up"
        fi
    fi

}


function check_ssh_tunnel_port()
{
    node_tunnel=$1
    port_list=${node_ssh_ports[${node_tunnel}]}
    offset=$(( ${node_id[${node_tunnel}]}*10 ))

    port_count=0

    if [[ ${node_type[${node_tunnel}]} == "xr" ]]; then
        # Forwarding port 22 for access to XR CLI
            ssh_port_xr=$(( $ssh_port_range + $offset + 1 ))
            check_port_open $ssh_port_xr $node_tunnel

        # Forwarding port 830 for access to XR Netconf
            netconf_port_xr=$(( $netconf_port_range + $offset + 1 ))
            check_port_open $netconf_port_xr $node_tunnel 

        # Forwarding port grpc for access to XR grpc server
            grpc_port_xr=$(( $grpc_port_range + $offset + 1 ))
            check_port_open $grpc_port_xr $node_tunnel

        # Forwarding port 57722 for access to XR bash
            ssh_port_linux=$(( $ssh_port_range + $offset + 2))
            check_port_open $ssh_port_linux $node_tunnel
    else
        ssh_port_linux=$(( $ssh_port_range + $offset + 1 ))
        check_port_open $ssh_port_linux $node_tunnel
    fi
}

# Setup the tunnels to enable ssh access over the nat

for node in "${node_vm_list[@]}"
do
    check_ssh_tunnel_port $node
done

if [[ $port_down == 1 ]]; then
    # Atleast one of the ports is down
    # Bring up the topology
    sudo systemctl stop virsh_manage
    sudo systemctl start virsh_manage
fi
