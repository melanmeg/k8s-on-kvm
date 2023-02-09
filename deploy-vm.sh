#!/bin/bash
set -eu

# region : set variables

IMAGE_SIZE=50G
IMAGE_PATH=/var/kvm/images

VM_LIST=(
    #vmid #vmname  #cpu #mem #vmsrvip
    "1001 k8s-cp-1 4    8192 192.168.11.111"
    "1002 k8s-cp-2 2    4096 192.168.11.112"
    "1003 k8s-cp-3 2    4096 192.168.11.113"
    "1101 k8s-wk-1 4    8192 192.168.11.121"
    "1102 k8s-wk-2 4    8192 192.168.11.122"
    "1103 k8s-wk-3 2    4096 192.168.11.123"
)

# endregion

# ---

# region : create template

# download the image(ubuntu 22.04 LTS)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
mv jammy-server-cloudimg-amd64.img image.img

# resize the downloaded disk
qemu-img resize image.img ${IMAGE_SIZE}

# endregion

# ---

# region : preparation

for array in "${VM_LIST[@]}"
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
  - name: user
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    chpasswd: {expire: False}
    lock_passwd: false
    ssh_import_id: gh:megutamago
    passwd: \$6\$rounds=4096\$iLPqVWPhF9FMY3Le\$7ukCEP1NijC5n7/D/jccsOf5fnrPyuk03sI9A8uhHjhmiwu7tkbT7c80fTd6X5cbbM.itwCnj7tUGHT9rk6LO0
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
