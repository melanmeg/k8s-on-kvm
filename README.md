# k8s-on-kvm

```
# machine info

Host k8s-cp-1
  HostName 192.168.11.111
  User user
  IdentityFile ~/.ssh/id_ed25519

Host k8s-wk-1
  HostName 192.168.11.121
  User user
  IdentityFile ~/.ssh/id_ed25519

Host k8s-wk-2
  HostName 192.168.11.122
  User user
  IdentityFile ~/.ssh/id_ed25519
```

```
.
├── git.sh
└── k8s-on-kvm
    ├── LICENSE
    ├── README.md
    ├── argocd-apps-helm-chart-values.yaml
    ├── argocd-helm-chart-values.yaml
    └── k8s-manifests
        └── apps
            ├── cluster-wide-app-resources
            │   └── argocd-server-lb.yaml
            ├── cluster-wide-apps
            │   └── metallb
            │       ├── kustomization.yaml
            │       └── metallb-cm.yaml
            └── root
                ├── apps.yaml
                └── projects.yaml
```

### ref: https://github.com/unchama/kube-cluster-on-proxmox
