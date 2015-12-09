#!/bin/bash

set -eu

### functions
msg(){
    echo "$@"
}
warn(){
    echo "$@" >&2
}
# "var_name" "message" "default selected" "selectable value" "selectable value"... [-e(allow empty)] [-r(receive all input(without empty))] [-i(ignore case)] [-l(return lower case)]
question(){
    local var_name=""
    local msg=""
    local default=""
    local reg=""
    local allow_empty=false
    local allow_all=false
    local ignore_case=false
    local lower_case=false
    local cnt=0
    for arg in "${@}"
    do
        case "${arg}" in
            "-e")
                allow_empty=true
                continue
                ;;
            "-r")
                allow_all=true
                continue
                ;;
            "-i")
                ignore_case=true
                continue
                ;;
            "-l")
                lower_case=true
                continue
                ;;
        esac

        case ${cnt} in
            0)
                var_name="${arg}"
                ;;
            1)
                msg="${arg}"
                ;;
            2)
                default="${arg}"
                ;;
            *)
                reg+="${reg:+|}${arg}"
                ;;
        esac
        cnt=$(( $cnt + 1 ))
    done

    to_lower(){
        echo "${1}" | tr "[:upper:]" "[:lower:]"
    }
    set_to_var(){
        ${lower_case} \
            && eval "${var_name}='$( to_lower "${1}")'"\
            || eval "${var_name}='${1}'"
    }

    $ignore_case && reg=$(to_lower "${reg}")

    while true
    do
        msg -n "${msg}"$([ "${reg}" ] && echo " [${reg}]")$([ "${default}" ] && echo " (default: ${default})")": "; read -r answer

        $ignore_case && answer=$(to_lower "${answer}")

        if [ ! "${answer}" ]
        then
            [  "${default}" ] && { set_to_var "${default}"; break; }
            ${allow_empty} && { set_to_var ''; break; }
        fi
        ${allow_all} && { set_to_var "${answer}"; break; }
        [ "${reg}" ] && bash -c "[[ '${answer}' =~ ${reg} ]]" \
            && { set_to_var "${answer}"; break; }
    done
}

### network
network_setting()
{
    local iflist=( $(ip -o l | cut -d' ' -f2 | tr -d ':' | grep -v 'lo') )

    msg "##### network settings
    target:
    $(echo -e "\t${iflist[@]}")
    "

    for if in "${iflist[@]}"
    do
        question 'input' "Do you setup the '${if}' NIC?" 'Y' 'y' 'yes' 'n' 'no' -i -l
        case "${input}" in
            n*)
                ;;
            y*)
                question 'nettype' 'Please select type' 'D' 'd' 'dhcp' 's' 'static' -i -l
                case "${nettype}" in
                    s*)
                        local ip="static"
                        question 'addr' 'Please input IP Address' -r
                        question 'mask' 'Please input Subnet Mask' '24' -r
                        question 'gateway' 'Please input Gateway Address' -r
                        question 'dns' 'Please input DNS Address' -r
                    ;;
                    d*)
                        local ip="dhcp"
                    ;;
                esac

                question 'desc' 'Please input Description' -r
                cat <<CONF > /etc/netctl/${if}
Description='${desc}'
Interface=${if}
Connection=ethernet
CONF
                [ "${ip}" = 'static' ] && \
                    cat <<CONF >> /etc/netctl/${if}
IP=${ip}
$([ "${addr}" ] && echo "Address=('${addr}/${mask}')" || echo "Address=()")
Gateway='${gateway}'
DNS=('${dns}')
CONF
                question is_start "Do you start ${if} network?" 'Y' 'y' 'yes' 'n' 'no' -i -l
                [[ ${is_start} =~ ^y ]] && netctl $(netctl status ${if} >/dev/null 2>&1 && echo restart || echo start) ${if}

                [ "$(netctl is-enabled ${if})" != 'enabled' ] && {
                    question is_start "Do you register ${if} network to auto start?" 'Y' 'y' 'yes' 'n' 'no' -i -l
                    [[ ${is_start} =~ ^y ]] && netctl enable "${if}"
                }
                ;;
        esac
    done
}

### local setting
local_setting()
{
    msg "##### local settings"

    cat <<EOF > /etc/profile.d/alias.sh
alias 'll=ls -l --color'
alias 'vi=vim'
alias 'tmux=tmux -2'
EOF
}

### vpn setting
vpn_setting()
{
    msg "##### vpn settings"

    pacman -Sy docker --noconfirm
    systemctl start docker; systemctl enable docker
    docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter

    docker_dir=/tmp/docker_vpn
    mkdir -p ${docker_dir}
    cd ${docker_dir}
    curl 'http://gitbucket/il10103/vpngateway/archive/master.tar.gz' | tar -zx
    docker build -t vpngateway .

    cd ~
    rm -rf ${docker_dir}

    cat <<EOF > /root/vpn.sh
ip r a 10.0.0.0/8 via 172.17.252.1 dev docker0
docker run --rm -it --cap-add=NET_ADMIN -e USER=ymaeda -e ALIAS=172.17.252.1/16 -e DIST=10.0.0.0/8 vpngateway ra001.hypermediasystems.com
EOF
}

### ip tables
iptables_setting()
{
    msg "##### iptables settings"

    local iflist=( $(ip -o l | cut -d' ' -f2 | tr -d ':' | grep -v 'lo') )
    question 'lannic' "Please select NIC for LAN" "" "${iflist[@]}"
    question 'wannic' "Please select NIC for WAN" "" "${iflist[@]}"

    local file=/root/iptables.sh

cat <<TABLE_SH > ${file}
#!/bin/sh

lan_nic=${lannic}
wan_nic=${wannic}

TABLE_SH

cat <<'TABLE_SH' >> ${file}
iptables -F
iptables -t nat -F

iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

### get data
lan=$( ip -o -4 a s dev ${lan_nic} | awk 'BEGIN{FS=" "} {print $4}' )
lanaddr=${lan%/*}
lanmask=${lan#*/}
lannet=$(
    bits=( $(  for i in $(seq 1 32); do [ ${i} -le ${lanmask} ] && echo -n 1 || echo -n 0 ; [ $((${i} % 8)) -eq 0 ] && echo -n ' ' ;done ) )
    addr_seq=( $( IFS='.'; arr=( ${lanaddr} ); echo "${arr[@]}" ) )
    for idx in 0 1 2 3
    do
        echo -n $(( ${addr_seq[$idx]} & 2#${bits[$idx]}))
        [ $idx -ne 3 ] && echo -n '.'
    done
)

wan=$( ip -o -4 a s dev ${wan_nic} | awk 'BEGIN{FS=" "} {print $4}' )
wanaddr=${lan%/*}
wanmask=${lan#*/}
wannet=$(
    bits=( $(  for i in $(seq 1 32); do [ ${i} -le ${wanmask} ] && echo -n 1 || echo -n 0 ; [ $((${i} % 8)) -eq 0 ] && echo -n ' ' ;done ) )
    addr_seq=( $( IFS='.'; arr=( ${wanaddr} ); echo "${arr[@]}" ) )
    for idx in 0 1 2 3
    do
        echo -n $(( ${addr_seq[$idx]} & 2#${bits[$idx]}))
        [ $idx -ne 3 ] && echo -n '.'
    done
)

vpn_dist=10.0.0.0/8

### filter
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -i ${lan_nic} -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A FORWARD -s ${lannet}/${lanmask} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu


### NAT
iptables -t nat -A POSTROUTING -s ${lannet}/${lanmask} -d ${vpn_dist} -o docker0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${lannet}/${lanmask} -o eno16777736 -j MASQUERADE


### system setting
iptables-save > /etc/iptables/iptables.rules
systemctl restart iptables; systemctl enable iptables
TABLE_SH

    chmod +x ${file}
    ${file}
}

### install apps
install_apps()
{
    msg "##### install apps"

    pacman -Sy openssh netcat vim --noconfirm
    systemctl start sshd; systemctl enable sshd
}

### virtualbox efi setting
virtualbox_efi_setting()
{
    msg "##### virtualbox with efi setting"

    mkdir -p /boot/efi/EFI/boot
    echo 'fs0:\EFI\grub\grubx64.efi' > /boot/efi/EFI/boot/startup.nsh
}

### auth system setting
auth_system_setting()
{
    msg "##### auth system setting"
}

virtualbox_efi_setting
local_setting
iptables_setting
network_setting
install_apps
vpn_setting
#auth_system_setting
