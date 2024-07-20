#!/bin/bash

set -euo pipefail

cd `dirname $0`

echo -e "\e[1;36m apply.sh started. \e[m"

# region : set variables

IMAGE_SIZE=50G
IMAGE_PATH=/var/kvm/images

VM_LIST=(
    #vmid #vmname  #cpu #mem #vmsrvip
    "1001 k8s-cp-1 2    4096 192.168.11.111"
    # "1002 k8s-cp-2 2    4096 192.168.11.112"
    # "1003 k8s-cp-3 2    4096 192.168.11.113"
    "1101 k8s-wk-1 4    8192 192.168.11.121"
    "1102 k8s-wk-2 4    8192 192.168.11.122"
    # "1103 k8s-wk-3 4    8192 192.168.11.123"
)

if [ -z "$1" ]; then
    echo "Error: No VM name provided."
    exit 1
fi

vm_name="$1"
vm_info=""
for line in "${VM_LIST[@]}"; do
    if [[ "$line" == *"$vm_name"* ]]; then
        vm_info="$line"
        break
    fi
done
if [[ -n "$vm_info" ]]; then
    VM_INFO=("$vm_info")
else
    echo "VM '$vm_name' not found."
    exit
fi

# endregion

# ---

# region : create template

# download the image(ubuntu 24.04 LTS)
# wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
cp img/noble-server-cloudimg-amd64.img ./image.img

# resize the downloaded disk
qemu-img resize image.img ${IMAGE_SIZE}

# endregion

# ---

# region : preparation

for array in "${VM_INFO[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip
    do
        # move the image and rename the vm name
        cp image.img ${IMAGE_PATH}/${vmname}.img

        # owner setting
        chown libvirt-qemu:kvm ${IMAGE_PATH}/${vmname}.img

        # create snippet for cloud-init(meta-data)
        # START irregular indent because heredoc
# ----- #
cat > meta-data.yaml <<EOF
instance-id: ${vmid}
local-hostname: ${vmname}
EOF
# ----- #
        # END irregular indent because heredoc

        # create snippet for cloud-init(user-data)
        # START irregular indent because heredoc
# ----- #
cat > user-data.yaml <<EOF
#cloud-config
users:
  - default
  - name: melanmeg
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    chpasswd:
      expire: False
    lock_passwd: false
    ssh_import_id: gh:melanmeg
    passwd: \$6\$rounds=4096\$iLPqVWPhF9FMY3Le\$7ukCEP1NijC5n7/D/jccsOf5fnrPyuk03sI9A8uhHjhmiwu7tkbT7c80fTd6X5cbbM.itwCnj7tUGHT9rk6LO0
timezone: Asia/Tokyo
runcmd:
  - sed -i.bak -r 's!http://(security|archive).ubuntu.com/ubuntu!http://ftp.riken.go.jp/Linux/ubuntu!' /etc/apt/sources.list.d/ubuntu.sources
  - apt update -y && apt upgrade -y
  - apt purge -y needrestart
  - echo "set bell-style none" | tee -a /etc/inputrc # Suppress beep sound
  - chmod -x /etc/update-motd.d/* # Suppress login Log
  - sed -i 's/^#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config # Suppress last Log
  - nc -l -p 12345
EOF
# ----- #
        # END irregular indent because heredoc

        # create snippet for cloud-init(network-config)
        # START irregular indent because heredoc
# ----- #
cat > network-config.yaml << EOF
version: 2
ethernets:
  enp1s0:
    dhcp4: false
    dhcp6: false
    addresses: [${vmsrvip}/24]
    gateway4: 192.168.11.1
    nameservers:
      addresses: [192.168.11.1]
EOF
# ----- #
        # END irregular indent because heredoc

        # create Cloud-Init CD-ROM drive
        cloud-localds seed.img user-data.yaml meta-data.yaml -N network-config.yaml

        # move the seed image and rename
        mv seed.img ${IMAGE_PATH}/seed${vmid}.img

        # owner setting
        chown libvirt-qemu:kvm ${IMAGE_PATH}/seed${vmid}.img

        # cleanup
        rm -f meta-data.yaml
        rm -f user-data.yaml
        rm -f network-config.yaml

# endregion

# ---

# region : setup vm on kvm

        # create vm
        # START irregular indent because heredoc
# ----- #
virt-install \
  --name ${vmname} \
  --vcpus ${cpu} --memory ${mem} \
  --network bridge=br0 \
  --disk ${IMAGE_PATH}/${vmname}.img,device=disk,bus=virtio,format=qcow2 \
  --disk ${IMAGE_PATH}/seed${vmid}.img,device=cdrom \
  --os-variant ubuntu22.04 \
  --console pty,target_type=serial \
  --virt-type kvm --graphics none \
  --import --noautoconsole
# ----- #
        # END irregular indent because heredoc
    done
done

# endregion

# ---

# region : Last

# cleanup
rm -f image.img

# endregion

# wait for runcmd
for array in "${VM_INFO[@]}"
do
  echo "${array}" | while read -r vmid vmname cpu mem vmsrvip
  do
    echo "Waiting for runcmd to start..."
    while ! nc -z -w5 "${vmsrvip}" 12345 > /dev/null 2>&1; do
      echo "Waiting for runcmd on $vmsrvip:12345..."
      sleep 5
    done
    echo "refresh known_hosts"
    ssh-keygen -R %h && ssh-keyscan %h >> ~/.ssh/known_hosts
    echo "service ssh restarted"
    ssh -n melanmeg@"${vmsrvip}" 'sudo systemctl restart ssh'
  done
done
echo "HealthCheck OK."

echo -e "\e[1;36m Install completed!!!! \e[m"
