#!/bin/bash
set -eu

TARGET_BRANCH=main
KUBE_API_SERVER_VIP=192.168.11.100
NFS_SERVER_IP=192.168.11.111
NFS_SERVER_PATH=/mnt/share

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
    --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=${KUBE_API_SERVER_VIP} \
    --set k8sServicePort=8443

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
    --version 5.19.14 \
    --create-namespace \
    --namespace argocd \
    --values https://raw.githubusercontent.com/megutamago/k8s-on-kvm/"${TARGET_BRANCH}"/k8s-manifests/argocd-helm-chart-values.yaml
helm install argocd argo/argocd-apps \
    --version 0.0.7 \
    --values https://raw.githubusercontent.com/megutamago/k8s-on-kvm/"${TARGET_BRANCH}"/k8s-manifests/argocd-apps-helm-chart-values.yaml

# NFS Add
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-client -n kube-system --set nfs.server=${NFS_SERVER_IP} --set nfs.path=${NFS_SERVER_PATH} nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
