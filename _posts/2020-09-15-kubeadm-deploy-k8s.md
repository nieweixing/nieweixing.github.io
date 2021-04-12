---
title: kubeadm部署k8s
author: VashonNie
date: 2020-09-15 14:10:00 +0800
updated: 2020-09-15 14:10:00 +0800
categories: [Kubernetes,Docker]
tags: [Kubernetes,Docker]
math: true
top: 100
---

本文主要介绍了如何在centos上采用kubeadm搭建k8s集群。

## 环境准备
### 服务器
master01:192.168.1.110 （最少2核CPU）  
node01:192.168.1.100  
### 规划
services网络：10.96.0.0/12  
pod网络：10.244.0.0/16  

## 配置hosts解析各主机
```
vim /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.1.110 master01
192.168.1.100 node01
```
## 同步各主机时间
```
yum install -y ntpdate
ntpdate time.windows.com
14 Mar 16:51:32 ntpdate[46363]: adjust time server 13.65.88.161 offset -0.001108 sec
```
## 关闭SWAP，关闭selinux
```
swapoff -a
vim /etc/selinux/config

# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=disabled
```
## 安装docker-ce
```
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache fast
yum -y install docker-ce

Docker 安装后出现：WARNING: bridge-nf-call-iptables is disabled 的解决办法
vim /etc/sysctl.conf

# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-arptables=1

systemctl enable docker && systemctl start docker
```
## 安装kubernetes
```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
```
## 初始化集群
```
kubeadm init --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.13.1 --pod-network-cidr=10.244.0.0/16
Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/
You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.1.110:6443 --token wgrs62.vy0trlpuwtm5jd75 --discovery-token-ca-cert-hash sha256:6e947e63b176acf976899483d41148609a6e109067ed6970b9fbca8d9261c8d0
```

## 手动部署flannel
```
flannel网址：https://github.com/coreos/flannel for Kubernetes v1.7+

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
podsecuritypolicy.extensions/psp.flannel.unprivileged created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.extensions/kube-flannel-ds-amd64 created
daemonset.extensions/kube-flannel-ds-arm64 created
daemonset.extensions/kube-flannel-ds-arm created
daemonset.extensions/kube-flannel-ds-ppc64le created
daemonset.extensions/kube-flannel-ds-s390x created
```
## node配置
安装docker kubelet kubeadm docker安装同步骤4。  
kubelet kubeadm安装同步骤5

## node加入到master
```
kubeadm join 192.168.1.110:6443 --token wgrs62.vy0trlpuwtm5jd75 --discovery-token-ca-cert-hash sha256:6e947e63b176acf976899483d41148609a6e109067ed6970b9fbca8d9261c8d0
kubectl get nodes  #查看node状态
NAME                    STATUS     ROLES    AGE     VERSION
localhost.localdomain   NotReady   <none>   130m    v1.13.4
master01                Ready      master   4h47m   v1.13.4
node01                  Ready      <none>   94m     v1.13.4

kubectl get cs  #查看组件状态
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-0               Healthy   {"health": "true"}  

kubectl get ns  #查看名称空间
NAME          STATUS   AGE
default       Active   4h41m
kube-public   Active   4h41m
kube-system   Active   4h41m

kubectl get pods -n kube-system  #查看pod状态
NAME                               READY   STATUS    RESTARTS   AGE
coredns-78d4cf999f-bszbk           1/1     Running   0          4h44m
coredns-78d4cf999f-j68hb           1/1     Running   0          4h44m
etcd-master01                      1/1     Running   0          4h43m
kube-apiserver-master01            1/1     Running   1          4h43m
kube-controller-manager-master01   1/1     Running   2          4h43m
kube-flannel-ds-amd64-27x59        1/1     Running   1          126m
kube-flannel-ds-amd64-5sxgk        1/1     Running   0          140m
kube-flannel-ds-amd64-xvrbw        1/1     Running   0          91m
kube-proxy-4pbdf                   1/1     Running   0          91m
kube-proxy-9fmrl                   1/1     Running   0          4h44m
kube-proxy-nwkl9                   1/1     Running   0          126m
kube-scheduler-master01            1/1     Running   2          4h43m
```