---
title: 二进制部署k8s
author: VashonNie
date: 2020-09-20 14:10:00 +0800
updated: 2020-09-20 14:10:00 +0800
categories: [Kubernetes,Docker]
tags: [Kubernetes,Docker]
math: true
---

本文主要介绍了如何在centos上采用二进制搭建k8s集群。

# 软件环境

| 软件 | 版本 |  
|----|----|  
|操作系统	|CentOS7.6_x64|  
|Docker |	19-ce|  
|Kubernetes	|1.15.12|  

# 服务器角色

|角色	|IP	|组件|  
|----|----|----|  
k8s-master|	192.168.21.31|	kube-apiserver，kube-controller-manager，kube-scheduler，etcd  
k8s-node1|	192.168.21.32|	kubelet，kube-proxy，docker，flannel，etcd  
k8s-node2|	192.168.21.33	|kubelet，kube-proxy，docker，flannel，etcd  

# 部署前环境配置
以下操作每台机器都需要执行
## 关闭swap
```
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```
## 关闭selinux
```
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```
## 关闭防护墙
```
systemctl stop firewalld
```
## 设置hosts
```
echo "192.168.21.31 master
192.168.21.32 node1
192.168.21.33 node2" >> /etc/hosts
```
# 部署Etcd集群
## 下载证书生成工具
```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
mv cfssl-certinfo_linux-amd64 /usr/bin/cfssl-certinfo
```
## 生成etcd证书
```
mkdir /root/k8s/etcd
cd /root/k8s/etcd

cat <<EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "www": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat <<EOF > ca-csr.json
{
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF

cat <<EOF > server-csr.json
{
    "CN": "etcd",
    "hosts": [
    "192.168.31.63",
    "192.168.31.65",
    "192.168.31.66"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing"
        }
    ]
}
EOF
```
执行命令生成证书
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server

ls *pem
ca-key.pem  ca.pem  server-key.pem  server.pem
```
## master部署etcd
```
二进制包下载地址：https://github.com/etcd-io/etcd/releases/download/v3.3.10/etcd-v3.3.10-linux-amd64.tar.gz  

创建目录存放包
mkdir -p /root/k8s/software

获取包解压
# wget https://github.com/etcd-io/etcd/releases/download/v3.3.10/etcd-v3.3.10-linux-amd64.tar.gz
# tar zxvf etcd-v3.2.12-linux-amd64.tar.gz

创建etcd存放配置文件，bin文件和证书的目录，并拷贝对应的文件过去
mkdir /opt/etcd/{bin,cfg,ssl} -p
mv etcd-v3.3.10-linux-amd64/{etcd,etcdctl} /opt/etcd/bin/

创建etcd的配置文件
cat <<EOF > /opt/etcd/cfg/etcd   
#[Member]
ETCD_NAME="etcd01"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.21.31:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.21.31:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.21.31:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.21.31:2379"
ETCD_INITIAL_CLUSTER="etcd01=https://192.168.21.31:2380,etcd02=https://192.168.21.32:2380,etcd03=https://192.168.21.33:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

设置systemd管理etcd
cat <<EOF > /usr/lib/systemd/system/etcd.service 
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=/opt/etcd/cfg/etcd
ExecStart=/opt/etcd/bin/etcd \\
--name=\${ETCD_NAME} \\
--data-dir=\${ETCD_DATA_DIR} \\
--listen-peer-urls=\${ETCD_LISTEN_PEER_URLS} \\
--listen-client-urls=\${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \\
--advertise-client-urls=\${ETCD_ADVERTISE_CLIENT_URLS} \\
--initial-advertise-peer-urls=\${ETCD_INITIAL_ADVERTISE_PEER_URLS} \\
--initial-cluster=\${ETCD_INITIAL_CLUSTER} \\
--initial-cluster-token=\${ETCD_INITIAL_CLUSTER_TOKEN} \\
--initial-cluster-state=new \\
--cert-file=/opt/etcd/ssl/server.pem \\
--key-file=/opt/etcd/ssl/server-key.pem \\
--peer-cert-file=/opt/etcd/ssl/server.pem \\
--peer-key-file=/opt/etcd/ssl/server-key.pem \\
--trusted-ca-file=/opt/etcd/ssl/ca.pem \\
--peer-trusted-ca-file=/opt/etcd/ssl/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

拷贝之前生成的etcd证书
# cp ca*pem server*pem /opt/etcd/ssl

master启动etcd
# systemctl start etcd
# systemctl enable etcd
```
## node节点部署etcd
```
node节点上部署etcd只需要把master的文件拷贝过来，然后修改下etcd的配置文件就行

scp -r /opt/etcd/ root@192.168.21.32:/opt
scp -r /opt/etcd/ root@192.168.21.33:/opt
scp /usr/lib/systemd/system/etcd.service root@192.168.21.32:/usr/lib/systemd/system
scp /usr/lib/systemd/system/etcd.service root@192.168.21.33:/usr/lib/systemd/system

node1和node2上修改/opt/etcd/cfg/etcd
修改后如下
node1
[root@node1 cfg]# cat /opt/etcd/cfg/etcd
#[Member]
ETCD_NAME="etcd02"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.21.32:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.21.32:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.21.32:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.21.32:2379"
ETCD_INITIAL_CLUSTER="etcd01=https://192.168.21.31:2380,etcd02=https://192.168.21.32:2380,etcd03=https://192.168.21.33:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

node2
[root@node2 kubernetes]# cat /opt/etcd/cfg/etcd
#[Member]
ETCD_NAME="etcd03"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.21.33:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.21.33:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.21.33:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.21.33:2379"
ETCD_INITIAL_CLUSTER="etcd01=https://192.168.21.31:2380,etcd02=https://192.168.21.32:2380,etcd03=https://192.168.21.33:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

然后再node1和node2上启动etcd
# systemctl start etcd
# systemctl enable etcd

验证etcd集群
# cd /opt/etcd/ssl
# /opt/etcd/bin/etcdctl --ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem --endpoints="https://192.168.21.31:2379,https://192.168.21.32:2379,https://192.168.21.33:2379" cluster-health
```
![upload-image](/assets/images/blog/deploy-k8s/1.png) 
# 安装docker
所有机器节点都执行
```
# sudo yum install -y yum-utils device-mapper-persistent-data lvm2
# sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# sudo yum -y install docker-ce
# curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://bc437cce.m.daocloud.io
# systemctl start docker
# systemctl enable docker
```
# 部署Flannel网络
部署flannel网络需要用etcd存储一个子网信息，所以要保证能成功连接etcd
```
master上执行命令写入
# cd /opt/etcd/ssl
# /opt/etcd/bin/etcdctl --ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem --endpoints="https://192.168.21.31:2379,https://192.168.21.32:2379,https://192.168.21.33:2379" set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'

在node1节点上执行操作,其他节点后续拷贝文件就行
下载二进制包
cd /root/k8s/software
# wget https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz
# tar zxvf flannel-v0.9.1-linux-amd64.tar.gz
# mv flanneld mk-docker-opts.sh /opt/kubernetes/bin

配置Flannel.
# mkdir -p /opt/kubernetes/{cfg,bin,ssl}
# cat << EOF > /opt/kubernetes/cfg/flanneld
FLANNEL_OPTIONS="--etcd-endpoints=https://192.168.21.31:2379,https://192.168.21.32:2379,https://192.168.21.33:2379 -etcd-cafile=/opt/etcd/ssl/ca.pem -etcd-certfile=/opt/etcd/ssl/server.pem -etcd-keyfile=/opt/etcd/ssl/server-key.pem"
EOF

systemd管理Flannel
# cat << EOF > /usr/lib/systemd/system/flanneld.service
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=/opt/kubernetes/cfg/flanneld
ExecStart=/opt/kubernetes/bin/flanneld --ip-masq \$FLANNEL_OPTIONS
ExecStartPost=/opt/kubernetes/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

配置docker启动指定子网段
cat << EOF > /usr/lib/systemd/system/docker.service 

[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=/run/flannel/subnet.env
ExecStart=/usr/bin/dockerd $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

重启flannel和docker
# systemctl daemon-reload
# systemctl start flanneld
# systemctl enable flanneld
# systemctl restart docker

其他节点部署（master上可部署也可不部署）
# scp -r /opt/kubernetes/ root@192.168.21.33:/opt
# scp -r /opt/kubernetes/ root@192.168.21.31:/opt
# scp -r /usr/lib/systemd/system/{flanneld,docker}.service root@192.168.21.31:/usr/lib/systemd/system
# scp -r /usr/lib/systemd/system/{flanneld,docker}.service root@192.168.21.33:/usr/lib/systemd/system

其他节点重启flannel和docker
# systemctl daemon-reload
# systemctl start flanneld
# systemctl enable flanneld
# systemctl restart docker

测试
确保docker0与flannel.1在同一网段。
测试不同节点互通，在当前节点访问另一个Node节点docker0 IP：
```
![upload-image](/assets/images/blog/deploy-k8s/2.png) 

# Master节点上部署组件
## 生成证书
```
# mkdir /root/k8s/master
# cd /root/k8s/master
创建ca证书
# cat << EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

# cat << EOF > ca-csr.json
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

生成apiserver证书
下面配置文件中的ip包含lb的ip，masterip和网络ip还有本地ip
# cat << EOF > server-csr.json
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "192.168.21.31",
      "192.168.21.32",
      "192.168.21.33",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson -bare server

生成kube-proxy的证书
# cat << EOF > kube-proxy-csr.json
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy

最终生成证书如下
# ls *pem
ca-key.pem  ca.pem  kube-proxy-key.pem  kube-proxy.pem  server-key.pem  server.pem
```
## 部署apiserver组件
```
下载二进制包
wget https://dl.k8s.io/v1.15.12/kubernetes-server-linux-amd64.tar.gz /root/k8s/software

拷贝所需要的文件
# mkdir /opt/kubernetes/{bin,cfg,ssl} -p
# tar zxvf kubernetes-server-linux-amd64.tar.gz
# cd kubernetes/server/bin
# cp kube-apiserver kube-scheduler kube-controller-manager kubectl /opt/kubernetes/bin

创建token文件
# head -c 16 /dev/urandom | od -An -t x | tr -d ' '
# cat << EOF > /opt/kubernetes/cfg/token.csv
231f18a1d882a5037e4374e51c6ec7e0,kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
第一列：随机字符串，自己执行第一条命令生成
第二列：用户名
第三列：UID
第四列：用户组

创建apiserver配置文件
# cat << EOF > /opt/kubernetes/cfg/kube-apiserver 
KUBE_APISERVER_OPTS="--logtostderr=true \\
--v=4 \\
--etcd-servers=https://192.168.21.31:2379,https://192.168.21.32:2379,https://192.168.21.33:2379 \\
--bind-address=192.168.21.31 \\
--secure-port=6443 \\
--advertise-address=192.168.21.31 \\
--allow-privileged=true \\
--service-cluster-ip-range=10.0.0.0/24 \\
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction \\
--authorization-mode=RBAC,Node \\
--enable-bootstrap-token-auth \\
--token-auth-file=/opt/kubernetes/cfg/token.csv \\
--service-node-port-range=30000-50000 \\
--tls-cert-file=/opt/kubernetes/ssl/server.pem  \\
--tls-private-key-file=/opt/kubernetes/ssl/server-key.pem \\
--client-ca-file=/opt/kubernetes/ssl/ca.pem \
--service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--etcd-cafile=/opt/etcd/ssl/ca.pem \\
--etcd-certfile=/opt/etcd/ssl/server.pem \\
--etcd-keyfile=/opt/etcd/ssl/server-key.pem"
EOF

systemd管理apiserver
# cat << EOF >  /usr/lib/systemd/system/kube-apiserver.service 
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-apiserver
ExecStart=/opt/kubernetes/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

启动apiserver
# systemctl daemon-reload
# systemctl enable kube-apiserver
# systemctl restart kube-apiserver
```
## 部署scheduler组件
```
创建scheduler配置文件
cat << EOF > /opt/kubernetes/cfg/kube-scheduler 
KUBE_SCHEDULER_OPTS="--logtostderr=true \\
--v=4 \\
--master=127.0.0.1:8080 \\
--leader-elect"
EOF

systemd管理scheduler组件
cat << EOF > /usr/lib/systemd/system/kube-scheduler.service 
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-scheduler
ExecStart=/opt/kubernetes/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

启动scheduler
# systemctl daemon-reload
# systemctl enable kube-scheduler
# systemctl restart kube-scheduler
```
## 部署controller-manager组件
```
创建controller-manager配置文件
cat << EOF > /opt/kubernetes/cfg/kube-controller-manager 
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \\
--v=4 \\
--master=127.0.0.1:8080 \\
--leader-elect=true \\
--address=127.0.0.1 \\
--service-cluster-ip-range=10.0.0.0/24 \\
--cluster-name=kubernetes \\
--cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
--cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem  \\
--root-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem"
EOF

systemd管理controller-manager组件
cat << EOF > /usr/lib/systemd/system/kube-controller-manager.service 
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-controller-manager
ExecStart=/opt/kubernetes/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

启动controller-manager
# systemctl daemon-reload
# systemctl enable kube-controller-manager
# systemctl restart kube-controller-manager

检查组件状态
[root@master cfg]# /opt/kubernetes/bin/kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```
# node节点上部署组件
Master apiserver启用TLS认证后，Node节点kubelet组件想要加入集群，必须使用CA签发的有效证书才能与apiserver通信，当Node节点很多时，签署证书是一件很繁琐的事情，因此有了TLS Bootstrapping机制，kubelet会以一个低权限用户自动向apiserver申请证书，kubelet的证书由apiserver动态签署。  
![upload-image](/assets/images/blog/deploy-k8s/3.png) 
 
## 将kubelet-bootstrap用户绑定到系统集群角色
```
# kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```
## 创建kubeconfig文件
在生成kubernetes证书的目录下执行以下命令生成kubeconfig文件
```
[root@node1 cfg]# cd /opt/kubernetes/ssl/
[root@master ssl]# cat kubeconfig.sh
BOOTSTRAP_TOKEN=231f18a1d882a5037e4374e51c6ec7e0
KUBE_APISERVER="https://192.168.21.31:6443"


# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

#----------------------

# 创建kube-proxy kubeconfig文件

kubectl config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

将文件拷贝到节点的配置文件目录
scp *.kubeconfig root@192.168.21.32: /opt/kubernetes/cfg
scp *.kubeconfig root@192.168.21.33: /opt/kubernetes/cfg
```
## 部署kubelet组件
```
从master上拷贝执行文件
# cd /root/k8s/software/kubernetes/server/bin
# scp kubelet kube-proxy root2192.168.21.32: /opt/kubernetes/bin
# scp kubelet kube-proxy root2192.168.21.33: /opt/kubernetes/bin

创建kubelet配置文件（node上都要执行，注意修改ip）
cat << EOF > /opt/kubernetes/cfg/kubelet
KUBELET_OPTS="--logtostderr=true \\
--v=4 \\
--hostname-override=192.168.21.32 \\
--kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \\
--bootstrap-kubeconfig=/opt/kubernetes/cfg/bootstrap.kubeconfig \\
--config=/opt/kubernetes/cfg/kubelet.config \\
--cert-dir=/opt/kubernetes/ssl \\
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
EOF

配置kubelet.config配置文件（node上都要执行，注意修改ip）
cat << EOF > /opt/kubernetes/cfg/kubelet.config
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 192.168.21.32
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["10.0.0.2"]
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
enabled: true
EOF

systemd管理kubelet组件（node上都要执行）
cat << EOF > /usr/lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kubelet
ExecStart=/opt/kubernetes/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

启动kubelet（node上都要执行）
# systemctl daemon-reload
# systemctl enable kubelet
# systemctl restart kubelet

master上审批node加入集群
启动后还没加入到集群中，需要手动允许该节点才可以。
在Master节点查看请求签名的Node：
# kubectl get csr
# kubectl certificate approve XXXXID
# kubectl get node
```
## 部署kube-proxy组件
```
创建kube-proxy配置文件（node上都要执行，注意修改ip）
cat  << EOF > /opt/kubernetes/cfg/kube-proxy
KUBE_PROXY_OPTS="--logtostderr=true \\
--v=4 \\
--hostname-override=192.168.21.32 \\
--cluster-cidr=10.0.0.0/24 \\
--kubeconfig=/opt/kubernetes/cfg/kube-proxy.kubeconfig"
EOF

systemd管理kube-proxy组件（node上都要执行）
cat << EOF > /usr/lib/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-proxy
ExecStart=/opt/kubernetes/bin/kube-proxy $KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

启动kube-proxy
# systemctl daemon-reload
# systemctl enable kube-proxy
# systemctl restart kube-proxy
```
# 部署coredns
执行下面操作部署
```
# cp /root/k8s/software/kubernetes/cluster/addons/dns/coredns/ coredns.yaml.base  /root/cordns.yam

# sed -i -e "s/__PILLAR__DNS__DOMAIN__/cluster.local./" -e "s/__PILLAR__DNS__SERVER__/10.0.0.2/" coredns.yaml

# sed -i -e "s/__PILLAR__DNS__MEMORY__LIMIT__/150Mi/" 

# sed -i -e "s/ k8s.gcr.io\/coredns:1.3.1/"coredns\/coredns:1.3.1

# kubectl apply -f /root/ coredns.yaml
```
# 运行测例测试
```
# kubectl run nginx --image=nginx --replicas=3
# kubectl expose deployment nginx --port=88 --target-port=80 --type=NodePort

[root@master coredns]# kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
busybox                  1/1     Running   12         15h
nginx-7bb7cd8db5-g7pxs   1/1     Running   0          15h
nginx-7bb7cd8db5-p22cb   1/1     Running   0          15h
nginx-7bb7cd8db5-z6dwn   1/1     Running   0          15h
[root@master coredns]# kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.0.0.1     <none>        443/TCP        16h
nginx        NodePort    10.0.0.63    <none>        88:43614/TCP   15h
```
访问集群中部署的Nginx，打开浏览器输入：http://192.168.31.32:43614

![upload-image](/assets/images/blog/deploy-k8s/4.png) 
 



