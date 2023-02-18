#!/bin/bash
set -eu

TARGET_BRANCH=main
KUBE_API_SERVER_VIP=192.168.11.100
NFS_SERVER_IP=192.168.11.111
NFS_SERVER_PATH=/mnt/share

# NFS Add
#helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
#helm install nfs-client -n kube-system --set nfs.server=${NFS_SERVER_IP} --set nfs.path=${NFS_SERVER_PATH} nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
