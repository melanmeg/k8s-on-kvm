# k8s-on-kvm

aa
### Prerequiremanets
- kvm
- ansible

### Usage
```
# vm deploy
./deploy.sh

# ansible 
ansible-playbook -i hosts site.yml
ansible-playbook -i hosts site.yml -C
```

### MachineInfo
```
# common info
  User         user
  IdentityFile ~/.ssh/id_ed25519

Host k8s-cp-1
IP   192.168.11.111
Host k8s-cp-2
IP   192.168.11.112
Host k8s-cp-3
IP   192.168.11.113

Host k8s-wk-1
IP   192.168.11.121
Host k8s-wk-2
IP   192.168.11.122
Host k8s-wk-3
IP   192.168.11.123
```

### ref: https://github.com/unchama/kube-cluster-on-proxmox
