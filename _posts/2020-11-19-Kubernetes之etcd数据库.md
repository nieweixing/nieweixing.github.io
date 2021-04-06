---
title: Kubernetes之etcd数据库
author: VashonNie
date: 2020-11-19 14:10:00 +0800
updated: 2020-11-19 14:10:00 +0800
categories: [Kubernetes,etcd]
tags: [Kubernetes,etcd]
math: true
---

etcd是CoreOS团队于2013年6月发起的开源项目，它的目标是构建一个高可用的分布式键值(key-value)数据库。etcd内部采用raft协议作为一致性算法，etcd基于Go语言实现。

etcd作为服务发现系统，有以下的特点：

* 简单：安装配置简单，而且提供了HTTP API进行交互，使用也很简单
* 安全：支持SSL证书验证
* 快速：根据官方提供的benchmark数据，单实例支持每秒2k+读操作
* 可靠：采用raft算法，实现分布式系统数据的可用性和一致性

由于上面的特点和优势，etcd也被作为k8s默认的存储数据库，今天我们来讲一讲如何部署etcd数据库集群以及etcd的一些常见使用方法。

# Docker-compose搭建etcd集群

编写docker-compose.yml文件，具体内容如下

```
version: '2'
networks:
  byfn:

services:
  etcd1:
    image: quay.io/coreos/etcd
    container_name: etcd1
    command: etcd -name etcd1 -advertise-client-urls http://0.0.0.0:2379 -listen-client-urls http://0.0.0.0:2379 -listen-peer-urls http://0.0.0.0:2380 -initial-cluster-token etcd-cluster -initial-cluster "etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380" -initial-cluster-state new
    ports:
      - 2379
      - 2380
    networks:
      - byfn
 
  etcd2:
    image: quay.io/coreos/etcd
    container_name: etcd2
    command: etcd -name etcd2 -advertise-client-urls http://0.0.0.0:2379 -listen-client-urls http://0.0.0.0:2379 -listen-peer-urls http://0.0.0.0:2380 -initial-cluster-token etcd-cluster -initial-cluster "etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380" -initial-cluster-state new
    ports:
      - 2379
      - 2380
    networks:
      - byfn
  
  etcd3:
    image: quay.io/coreos/etcd
    container_name: etcd3
    command: etcd -name etcd3 -advertise-client-urls http://0.0.0.0:2379 -listen-client-urls http://0.0.0.0:2379 -listen-peer-urls http://0.0.0.0:2380 -initial-cluster-token etcd-cluster -initial-cluster "etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380" -initial-cluster-state new
    ports:
      - 2379
      - 2380
    networks:
      - byfn
```

参数介绍：

* data-dir 指定节点的数据存储目录，这些数据包括节点ID，集群ID，集群初始化配置，
* Snapshot文件，若未指定—wal-dir，还会存储WAL文件；
* wal-dir 指定节点的was文件的存储目录，若指定了该参数，wal文件会和其他数据文件分开存储。
* name 节点名称
* initial-advertise-peer-urls 告知集群其他节点url.
* listen-peer-urls 监听URL，用于与其他节点通讯
* advertise-client-urls 告知客户端url, 也就是服务的url
* initial-cluster-token 集群的ID
* initial-cluster 集群中所有节点
* initial-cluster-state 监听客户端状态
* listen-client-urls 监听客户端地址
* initial-cluster-state new 初始化集群 为新节点

然后docker-compose运行etcd的yaml文件，并且插入数据进行检查验证

```
[root@VM-0-13-centos docker-compose]# docker-compose up -d
//查看集群节点状态
[root@VM-0-13-centos docker-compose]# etcdctl --endpoints 127.0.0.1:32771 member list
ade526d28b1f92f7, started, etcd1, http://etcd1:2380, http://0.0.0.0:2379, false
bd388e7810915853, started, etcd3, http://etcd3:2380, http://0.0.0.0:2379, false
d282ac2ce600c1ce, started, etcd2, http://etcd2:2380, http://0.0.0.0:2379, false
//给etcd1节点插入数据
[root@VM-0-13-centos docker-compose]# curl -L http://127.0.0.1:32771/v2/keys/etcd -XPUT -d value="Hello etcd1"
{"action":"set","node":{"key":"/etcd","value":"Hello etcd1","modifiedIndex":8,"createdIndex":8}}
//检查在etcd2中是否能够查到
[root@VM-0-13-centos docker-compose]# curl -L http://127.0.0.1:32773/v2/keys/etcd
{"action":"get","node":{"key":"/etcd","value":"Hello etcd1","modifiedIndex":8,"createdIndex":8}}
//检查在etcd3中是否能够查到
[root@VM-0-13-centos docker-compose]# curl -L http://127.0.0.1:32769/v2/keys/etcd
{"action":"get","node":{"key":"/etcd","value":"Hello etcd1","modifiedIndex":8,"createdIndex":8}}
```

# 二进制部署etcd集群

这个可以参考之前的文章 二进制搭建k8s集群  <https://www.niewx.cn/kubernetes/docker/2020/09/20/%E4%BA%8C%E8%BF%9B%E5%88%B6%E9%83%A8%E7%BD%B2k8s/>

其中部署etcd集群章节有说明如何搭建

# kubeadm集群如何使用etcd集群

一般我们如果通过kubeadm创建的集群都是单节点的etcd，那么如何配置一个高可用的etcd集群给kubeadm的集群。首先你需要通过kubeadm搭建一个集群，你可以参考文章进行部署<https://www.niewx.cn/kubernetes/docker/2020/09/15/kubeadm%E9%83%A8%E7%BD%B2k8s/>

也可以通过<https://www.niewx.cn/kubernetes/docker/2020/05/10/k8s%E4%B8%80%E9%94%AE%E9%83%A8%E7%BD%B2%E8%84%9A%E6%9C%AC/> 一键部署包进行安装，这里就不细说了

集群部署好之后，我们下面来部署etcd集群，并接入对应的集群中，大致步骤如下

* 新建一个 2 节点的 etcd cluster
* 查看 etcd 的状态
* 迁移原来 master 节点上的 etcd 数据到上面新建的 etcd cluster 中
* 切换 kube-apiserver 使用新的 etcd endpoint 地址
* 清理掉原来的单节点 etcd 服务
* 重建一个 etcd 服务，加入新集群
* 部署新的 etcd 节点
* 更新另外2个节点的 etcd.yaml 配置

## 新建一个2节点的 etcd cluster

```
//基于当前 master 节点 tvm-00 的 etcd 配置来修改：
[root@tvm-00 ~]# scp /etc/kubernetes/manifests/etcd.yaml 10.10.9.68:/tmp/
[root@tvm-00 ~]# scp /etc/kubernetes/manifests/etcd.yaml 10.10.9.69:/tmp/
//修改 etcd 配置，设置成一个全新的 cluster
[root@tvm-01 ~]# cat /tmp/etcd.yaml // (略过部分没有改动的输出内容)
spec:
 containers:
 - command:
 - etcd
 - --name=etcd-01
 - --initial-advertise-peer-urls=http://10.10.9.68:2380
 - --listen-peer-urls=http://10.10.9.68:2380
 - --listen-client-urls=http://127.0.0.1:2379,http://10.10.9.68:2379
 - --advertise-client-urls=http://10.10.9.68:2379
 - --initial-cluster-token=etcd-cluster
 - --initial-cluster=etcd-01=http://10.10.9.68:2380,etcd-02=http://10.10.9.69:2380
 - --initial-cluster-state=new
 - --data-dir=/var/lib/etcd
 image: gcr.io/google_containers/etcd-amd64:3.1.10 // (略过部分没有改动的输出内容)
[root@tvm-02 ~]# cat /tmp/etcd.yaml // (略过部分没有改动的输出内容)
spec:
 containers:
 - command:
 - etcd
 - --name=etcd-02
 - --initial-advertise-peer-urls=http://10.10.9.69:2380
 - --listen-peer-urls=http://10.10.9.69:2380
 - --listen-client-urls=http://127.0.0.1:2379,http://10.10.9.69:2379
 - --advertise-client-urls=http://10.10.9.69:2379
 - --initial-cluster-token=etcd-cluster
 - --initial-cluster=etcd-01=http://10.10.9.68:2380,etcd-02=http://10.10.9.69:2380
 - --initial-cluster-state=new
 - --data-dir=/var/lib/etcd
 image: gcr.io/google_containers/etcd-amd64:3.1.10 //(略过部分没有改动的输出内容)
//启动 etcd cluster### 配置文件同步到 manifests 后将会被 kubelet 检测到然后自动将 pod 启动
[root@tvm-01 ~]# rm /var/lib/etcd -fr
[root@tvm-01 ~]# cp -a /tmp/etcd.yaml /etc/kubernetes/manifests/
[root@tvm-02 ~]# rm /var/lib/etcd -fr
[root@tvm-02 ~]# cp -a /tmp/etcd.yaml /etc/kubernetes/manifests/
```

## 查看 etcd 的状态

```
//下载一个 etcdctl 工具来管理集群：
[root@tvm-00 ~]# cd /usr/local/bin/
[root@tvm-00 ~]# wget 
https://github.com/coreos/etcd/releases/download/v3.1.10/etcd-v3.1.10-linux-amd64.tar.gz
[root@tvm-00 ~]# tar zxf etcd-v3.1.10-linux-amd64.tar.gz
[root@tvm-00 ~]# mv etcd-v3.1.10-linux-amd64/etcd* .
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints
 "http://10.10.9.68:2379,http://10.10.9.69:2379" endpoint status
http://10.10.9.68:2379, 21b9c7066a7e525, 3.1.10, 25 kB, true, 7, 194
http://10.10.9.69:2379, 516e519b2158e83a, 3.1.10, 25 kB, false, 7, 194
//注意：输出的列从左到右分别表示：endpoint URL, ID, version, database size, leadership status, raft term, and raft status.### 符合预期。
```

## 迁移原来 master 节点上的 etcd 数据到上面新建的 etcd cluster 中

```
//注意：etcdctl 3.x 版本提供了一个 make-mirror 功能来同步数据### 在当前 master 节点 
tvm-00 上执行：
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl make-mirror --no-dest-prefix=true 
--endpoints=127.0.0.1:2379 --insecure-skip-tls-verify=true 10.10.9.68:2379
//将数据同步到远端刚才新建的 etcd 集群中### 注意1：数据是从 127.0.0.1:2379 写入到 10.10.9.68:2379### 注意2：这个同步只能是手动中止，间隔 30s 打印一次输出
//通过对比集群到状态来判断是否同步完成：###（新开一个窗口）
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl endpoint status
127.0.0.1:2379, 8e9e05c52164694d, 3.1.10, 1.9 MB, true, 2, 342021
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints 
"http://10.10.9.68:2379,http://10.10.9.69:2379" endpoint status
http://10.10.9.68:2379, 21b9c7066a7e525, 3.1.10, 1.9 MB, true, 7, 1794
http://10.10.9.69:2379, 516e519b2158e83a, 3.1.10, 1.9 MB, false, 7, 1794
```

## 切换 kube-apiserver 使用新的 etcd endpoint 地址

```
//停止 kubelet 服务：
[root@tvm-00 ~]# systemctl stop kubelet
//更新 kube-apiserver.yaml 中 etcd 服务到地址，切到我们到新集群中：
[root@tvm-00 ~]# sed -i 's#127.0.0.1:2379#10.10.9.68:2379#' 
/etc/kubernetes/manifests/kube-apiserver.yaml
//启动 kubelet 服务：
[root@tvm-00 ~]# systemctl start kubelet
[root@tvm-00 ~]# kubectl get pods --all-namespaces |grep 'etcd-tvm'
kube-system etcd-tvm-00 1/1 Running 1 4h
kube-system etcd-tvm-01 1/1 Running 0 1h
kube-system etcd-tvm-02 1/1 Running 0 1h
```

## 清理掉原来的单节点 etcd 服务

```
[root@tvm-00 ~]# mv /etc/kubernetes/manifests/etcd.yaml /tmp/orig.master.etcd.yaml
[root@tvm-00 ~]# mv /var/lib/etcd /tmp/orig.master.etcd // 观察 pods 的变化：
[root@tvm-00 ~]# kubectl get pods --all-namespaces |grep 'etcd-tvm'
kube-system etcd-tvm-01 1/1 Running 0 1h
kube-system etcd-tvm-02 1/1 Running 0 1h
//符合预期 etcd-tvm-00 停止服务
```

## 重建一个 etcd 服务，加入新集群

```
[root@tvm-00 ~]# cat /tmp/etcd.yaml //(略过部分没有改动的输出内容)
spec:
 containers:
 - command:
 - etcd
 - --name=etcd-00
 - --initial-advertise-peer-urls=http://10.10.9.67:2380
 - --listen-peer-urls=http://10.10.9.67:2380
 - --listen-client-urls=http://127.0.0.1:2379,http://10.10.9.67:2379
 - --advertise-client-urls=http://10.10.9.67:2379
 - --initial-cluster-token=etcd-cluster
- --initial-cluster=etcd-00=http://10.10.9.67:2380,etcd-01=http://10.10.9.68:2380,etcd-02=http://10.10.9.69:2380
 - --initial-cluster-state=existing
 - --data-dir=/var/lib/etcd
 image: gcr.io/google_containers/etcd-amd64:3.1.10 //(略过部分没有改动的输出内容)
//注意：上述新节点的配置有一个地方不一样：
--initial-cluster-state=existing
```

## 先配置 etcd cluster 增加一个 member 用于后续操作

```
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints="http://10.10.9.68:2379" member list
21b9c7066a7e525, started, etcd-01, http://10.10.9.68:2380, http://10.10.9.68:2379
516e519b2158e83a, started, etcd-02, http://10.10.9.69:2380, http://10.10.9.69:2379
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints="http://10.10.9.68:2379" member add etcd-00 --peer-urls=http://10.10.9.67:2380
 Member 6cc2e7728adb6b28 added to cluster 3742ed98339167da
ETCD_NAME="etcd-00"
 ETCD_INITIAL_CLUSTER="etcd-01=http://10.10.9.68:2380,etcd-02=http://10.10.9.69:2380,etcd-00=http://10.10.9.67:2380"
 ETCD_INITIAL_CLUSTER_STATE="existing"
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints="http://10.10.9.68:2379" member list
 21b9c7066a7e525, started, etcd-01, http://10.10.9.68:2380, http://10.10.9.68:2379
 516e519b2158e83a, started, etcd-02, http://10.10.9.69:2380, http://10.10.9.69:2379
 6cc2e7728adb6b28, unstarted, , http://10.10.9.67:2380,
//部署新的 etcd 节点
[root@tvm-00 ~]# rm /var/lib/etcd -fr
[root@tvm-00 ~]# cp -a /tmp/etcd.yaml /etc/kubernetes/manifests/
//再次查看 k8s cluster 信息
[root@tvm-00 ~]# kubectl get pods --all-namespaces |grep 'etcd-tvm'
kube-system etcd-tvm-00 1/1 Running 1 4h
kube-system etcd-tvm-01 1/1 Running 0 1h
kube-system etcd-tvm-02 1/1 Running 0 1h
//etcd 的日志：
[root@tvm-00 ~]# kubectl logs -n kube-system --tail=20 etcd-tvm-00
//etcd clister 状态：
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl 
--endpoints="http://10.10.9.67:2379,http://10.10.9.68:2379,http://10.10.9.69:2379" member List
21b9c7066a7e525, started, etcd-01, http://10.10.9.68:2380, http://10.10.9.68:2379
516e519b2158e83a, started, etcd-02, http://10.10.9.69:2380, http://10.10.9.69:2379
6cc2e7728adb6b28, started, etcd-00, http://10.10.9.67:2380, http://10.10.9.67:2379
[root@tvm-00 ~]# ETCDCTL_API=3 etcdctl --endpoints
"http://10.10.9.67:2379,http://10.10.9.68:2379,http://10.10.9.69:2379" endpoint status
http://10.10.9.67:2379, 6cc2e7728adb6b28, 3.1.10, 3.8 MB, false, 7, 5236
http://10.10.9.68:2379, 21b9c7066a7e525, 3.1.10, 3.3 MB, true, 7, 5236
http://10.10.9.69:2379, 516e519b2158e83a, 3.1.10, 3.3 MB, false, 7, 5236
```

## 更新另外2个节点的 etcd.yaml 配置

```
//区别之处：
- --initial-cluster=etcd-00=http://10.10.9.67:2380,etcd-01=http://10.10.9.68:2380,etcd-02=http://10.10.9.69:2380
- --initial-cluster-state=existing
//将节点 tvm-00 上 kube-apiserver 使用的 etcd endpoint 切换回来
[root@tvm-00 ~]# sed -i 's#10.10.9.68:2379#127.0.0.1:2379#' 
/etc/kubernetes/manifests/kube-apiserver.yaml
[root@tvm-00 ~]# kubectl get pods --all-namespaces |grep api
kube-system kube-apiserver-tvm-00 1/1 Running 0 1m
```

## kubeadm使用已有etcd集群

假如我们已经提前搭建好了一个etcd集群，那么在kubeadm进行部署的时候如何去使用这个集群，其实只需要在kubeadm中进行配置即可

```
cat <<EOF > /etc/kubernetes/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.13.0
apiServer:
 certSANs:
 - 10.127.24.179
 - 127.0.0.1
networking:
 podSubnet: 10.244.0.0/16
etcd:
 external:
 endpoints:
 - https://10.39.14.204:2379
 - https://10.39.14.205:2379
 - https://10.39.14.206:2379
 caFile: /etc/kubernetes/pki/etcd/ca.crt
 certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
 keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
EOF
```

# 如何在k8s中搭建etcd集群

这里我们可以使用 StatefulSet 这个控制器来运行 etcd 集群，etcd 集群的编排的资源清单文件我们可以使用 Kubernetes 源码中提供的，位于目录：test/e2e/testing-manifests/statefulset/etcd下面。

```
git clone https://github.com/kubernetes/kubernetes
cd kubernetes/test/e2e/testing-manifests/statefulset/etcd
ll //查看对应的yaml文件如下
-rw-r--r-- 1 nieweixing 197121  184 11月 11 00:10 pdb.yaml
-rw-r--r-- 1 nieweixing 197121  258 11月 11 00:10 service.yaml
-rw-r--r-- 1 nieweixing 197121 6619 11月 11 00:10 statefulset.yaml
-rw-r--r-- 1 nieweixing 197121  577 11月 11 00:10 tester.yaml
```

service.yaml文件中就是一个用户 StatefulSet 使用的 headless service：

```
apiVersion: v1
kind: Service
metadata:
  name: etcd
  labels:
    app: etcd
spec:
  ports:
  - port: 2380
    name: etcd-server
  - port: 2379
    name: etcd-client
  clusterIP: None
  selector:
    app: etcd
  publishNotReadyAddresses: true
```

pdb.yaml文件是用来保证 etcd 的高可用的一个 PodDisruptionBudget 资源对象，PodDisruptionBudget 
说明详情可以参考文档<https://kubernetes.io/zh/docs/tasks/run-application/configure-pdb/>

```
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: etcd-pdb
  labels:
    pdb: etcd
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: etcd
```

statefulset.yaml，这里修改下http://${HOSTNAME}.${SET_NAME}成http://${POD_IP}:PORT这样

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app: etcd
  name: etcd
spec:
  replicas: 3
  selector:
    matchLabels:
      app: etcd
  serviceName: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
        - name: etcd
          image: k8s.gcr.io/etcd:3.2.24
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 2380
            name: peer
            protocol: TCP
          - containerPort: 2379
            name: client
            protocol: TCP
          env:
          - name: INITIAL_CLUSTER_SIZE
            value: "3"
          - name: MY_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
          - name: SET_NAME
            value: "etcd"
          command:
            - /bin/sh
            - -ec
            - |
              HOSTNAME=$(hostname)

              ETCDCTL_API=3

              eps() {
                  EPS=""
                  for i in $(seq 0 $((${INITIAL_CLUSTER_SIZE} - 1))); do
                      EPS="${EPS}${EPS:+,}http://${SET_NAME}-${i}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2379"
                  done
                  echo ${EPS}
              }

              member_hash() {
                  etcdctl member list | grep -w "$HOSTNAME" | awk '{ print $1}' | awk -F "," '{ print $1}'
              }

              initial_peers() {
                  PEERS=""
                  for i in $(seq 0 $((${INITIAL_CLUSTER_SIZE} - 1))); do
                    PEERS="${PEERS}${PEERS:+,}${SET_NAME}-${i}=http://${SET_NAME}-${i}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2380"
                  done
                  echo ${PEERS}
              }

              # etcd-SET_ID
              SET_ID=${HOSTNAME##*-}

              # adding a new member to existing cluster (assuming all initial pods are available)
              if [ "${SET_ID}" -ge ${INITIAL_CLUSTER_SIZE} ]; then
                  # export ETCDCTL_ENDPOINTS=$(eps)
                  # member already added?

                  MEMBER_HASH=$(member_hash)
                  if [ -n "${MEMBER_HASH}" ]; then
                      # the member hash exists but for some reason etcd failed
                      # as the datadir has not be created, we can remove the member
                      # and retrieve new hash
                      echo "Remove member ${MEMBER_HASH}"
                      etcdctl --endpoints=$(eps) member remove ${MEMBER_HASH}
                  fi

                  echo "Adding new member"

                  echo "etcdctl --endpoints=$(eps) member add ${HOSTNAME} --peer-urls=http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2380"
                  etcdctl member --endpoints=$(eps) add ${HOSTNAME} --peer-urls=http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2380 | grep "^ETCD_" > /var/run/etcd/new_member_envs

                  if [ $? -ne 0 ]; then
                      echo "member add ${HOSTNAME} error."
                      rm -f /var/run/etcd/new_member_envs
                      exit 1
                  fi

                  echo "==> Loading env vars of existing cluster..."
                  sed -ie "s/^/export /" /var/run/etcd/new_member_envs
                  cat /var/run/etcd/new_member_envs
                  . /var/run/etcd/new_member_envs

                  echo "etcd --name ${HOSTNAME} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --listen-peer-urls http://${POD_IP}:2380 --listen-client-urls http://${POD_IP}:2379,http://127.0.0.1:2379 --advertise-client-urls http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2379 --data-dir /var/run/etcd/default.etcd --initial-cluster ${ETCD_INITIAL_CLUSTER} --initial-cluster-state ${ETCD_INITIAL_CLUSTER_STATE}"

                  exec etcd --listen-peer-urls http://${POD_IP}:2380 \
                      --listen-client-urls http://${POD_IP}:2379,http://127.0.0.1:2379 \
                      --advertise-client-urls http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2379 \
                      --data-dir /var/run/etcd/default.etcd
              fi

              for i in $(seq 0 $((${INITIAL_CLUSTER_SIZE} - 1))); do
                  while true; do
                      echo "Waiting for ${SET_NAME}-${i}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local to come up"
                      ping -W 1 -c 1 ${SET_NAME}-${i}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local > /dev/null && break
                      sleep 1s
                  done
              done

              echo "join member ${HOSTNAME}"
              # join member
              exec etcd --name ${HOSTNAME} \
                  --initial-advertise-peer-urls http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2380 \
                  --listen-peer-urls http://${POD_IP}:2380 \
                  --listen-client-urls http://${POD_IP}:2379,http://127.0.0.1:2379 \
                  --advertise-client-urls http://${HOSTNAME}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2379 \
                  --initial-cluster-token etcd-cluster-1 \
                  --data-dir /var/run/etcd/default.etcd \
                  --initial-cluster $(initial_peers) \
                  --initial-cluster-state new
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -ec
                  - |
                    HOSTNAME=$(hostname)

                    member_hash() {
                        etcdctl member list | grep -w "$HOSTNAME" | awk '{ print $1}' | awk -F "," '{ print $1}'
                    }

                    eps() {
                        EPS=""
                        for i in $(seq 0 $((${INITIAL_CLUSTER_SIZE} - 1))); do
                            EPS="${EPS}${EPS:+,}http://${SET_NAME}-${i}.${SET_NAME}.${MY_NAMESPACE}.svc.cluster.local:2379"
                        done
                        echo ${EPS}
                    }

                    export ETCDCTL_ENDPOINTS=$(eps)
                    SET_ID=${HOSTNAME##*-}

                    # Removing member from cluster
                    if [ "${SET_ID}" -ge ${INITIAL_CLUSTER_SIZE} ]; then
                        echo "Removing ${HOSTNAME} from etcd cluster"
                        etcdctl member remove $(member_hash)
                        if [ $? -eq 0 ]; then
                            # Remove everything otherwise the cluster will no longer scale-up
                            rm -rf /var/run/etcd/*
                        fi
                    fi
          volumeMounts:
          - mountPath: /var/run/etcd
            name: datadir
  volumeClaimTemplates:
  - metadata:
      name: datadir
    spec:
      accessModes:
      - "ReadWriteOnce"
      resources:
        requests:
          # upstream recommended max is 700M
          storage: 10Gi
```

执行命令进行部署

```
kubectl apply -f .
```

等pod运行成功后，我们该如何访问呢，这我们给service改成对应的lb类型，这样可以直接通过公网ip个接口就可以访问了

```
[root@VM-0-13-centos etcd]# kubectl get svc
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)             AGE
etcd         ClusterIP      None             <none>          2380/TCP,2379/TCP   22h
etcd-test    LoadBalancer   172.16.83.34     106.53.131.xx   2379:31354/TCP      21h
kube-user    LoadBalancer   172.16.100.133   10.0.0.4        443:31745/TCP       28h
kubernetes   ClusterIP      172.16.0.1       <none>          443/TCP             29h
```

这里我们将2379端口通过LoadBalancer  类型的service映射成公网访问了，下面我们来用命令检查下集群。
首先下载etcdctl工具，我们登录客户端机器执行下面命令安装etcdctl工具

```
[root@tvm-00 ~]# cd /usr/local/bin/
[root@tvm-00 ~]# wget 
https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
[root@tvm-00 ~]# tar zxf etcd-v3.4.13-linux-amd64.tar.gz
[root@tvm-00 ~]# mv etcd-v3.4.13-linux-amd64/etcd* .
```

然后执行命令检查集群，这边查看集群都是正常，说明这边集群部署成功

```
[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 member list
42c8b94265b9b79a, started, etcd-2, http://etcd-2.etcd.default.svc.cluster.local:2380, http://etcd-2.etcd.default.svc.cluster.local:2379, false
9869f0647883a00d, started, etcd-1, http://etcd-1.etcd.default.svc.cluster.local:2380, http://etcd-1.etcd.default.svc.cluster.local:2379, false
c799a6ef06bc8c14, started, etcd-0, http://etcd-0.etcd.default.svc.cluster.local:2380, http://etcd-0.etcd.default.svc.cluster.local:2379, false

[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 endpoint status --write-out=table
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|      ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 106.53.131.xx:2379 | c799a6ef06bc8c14 |  3.4.13 |   20 kB |     false |      false |         3 |          9 |                  9 |        |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

下面我们对etcd的pod进行扩缩容看看是否会有影响

```
[root@VM-0-13-centos etcd]# kubectl scale statefulsets etcd --replicas=5
statefulset.apps/etcd scaled
[root@VM-0-13-centos etcd]# kubectl get pod | grep etcd
etcd-0   1/1     Running   0          22h
etcd-1   1/1     Running   0          22h
etcd-2   1/1     Running   0          22h
etcd-3   2/2     Running   0          78s
etcd-4   2/2     Running   2          53s
[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 endpoint status --write-out=table
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|      ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 106.53.131.xx:2379 | 42c8b94265b9b79a |  3.4.13 |   20 kB |      true |      false |         3 |         11 |                 11 |        |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 member list
42c8b94265b9b79a, started, etcd-2, http://etcd-2.etcd.default.svc.cluster.local:2380, http://etcd-2.etcd.default.svc.cluster.local:2379, false
9869f0647883a00d, started, etcd-1, http://etcd-1.etcd.default.svc.cluster.local:2380, http://etcd-1.etcd.default.svc.cluster.local:2379, false
c799a6ef06bc8c14, started, etcd-0, http://etcd-0.etcd.default.svc.cluster.local:2380, http://etcd-0.etcd.default.svc.cluster.local:2379, false
ef933addf9d37a32, started, etcd-3, http://etcd-3.etcd.default.svc.cluster.local:2380, http://etcd-3.etcd.default.svc.cluster.local:2379, false
[root@VM-0-13-centos etcd]# kubectl scale statefulsets etcd --replicas=3
statefulset.apps/etcd scaled
[root@VM-0-13-centos etcd]# kubectl get pod | grep etcd
etcd-0   1/1     Running   0          22h
etcd-1   1/1     Running   0          22h
etcd-2   1/1     Running   0          22h
[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 member list
42c8b94265b9b79a, started, etcd-2, http://etcd-2.etcd.default.svc.cluster.local:2380, http://etcd-2.etcd.default.svc.cluster.local:2379, false
9869f0647883a00d, started, etcd-1, http://etcd-1.etcd.default.svc.cluster.local:2380, http://etcd-1.etcd.default.svc.cluster.local:2379, false
c799a6ef06bc8c14, started, etcd-0, http://etcd-0.etcd.default.svc.cluster.local:2380, http://etcd-0.etcd.default.svc.cluster.local:2379, false
[root@VM-0-13-centos etcd]# etcdctl --endpoints 106.53.131.xx:2379 endpoint status --write-out=table
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|      ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 106.53.131.xx:2379 | c799a6ef06bc8c14 |  3.4.13 |   20 kB |     false |      false |         3 |         12 |                 12 |        |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

这边扩缩容都是正常，这边可以给etcd配置hpa来实现整真正的高可用。

# etcdctl常用的命令

为了执行命名方便，我们在客户端机器直接写这个alias，将下面命令写到root目录下的.bashrc文件然后bash一下这个文件，新开一个session窗口，后续直接执行etcdcluster这个命令加参数即可。

```
etcdcluster='etcdctl --endpoints 106.53.131.xx:2379'
```

## PUT [options] <key> <value>

```
[root@VM-0-13-centos etcd]# etcdcluster  put foo bar 
OK
[root@VM-0-13-centos etcd]# etcdcluster  get foo
foo
ba
[root@VM-0-13-centos etcd]# etcdcluster put foo bar1 --prev-kv //覆盖之前的值
OK
foo
bar[root@VM-0-13-centos etcd]# etcdcluster get foo
foo
bar1
[root@VM-0-13-centos etcd]# etcdcluster put foo "bar1 2 3" //插入多个value值
OK
```

## GET [options] <key> [range_end]

```
[root@VM-0-13-centos ~]# etcdcluster put foo1 bar1
OK
[root@VM-0-13-centos ~]# etcdcluster put foo2 bar2
OK
[root@VM-0-13-centos ~]# etcdcluster put foo3 bar3
OK
[root@VM-0-13-centos ~]# etcdcluster put foo bar
OK
[root@VM-0-13-centos ~]# etcdcluster get foo
foo
bar
[root@VM-0-13-centos ~]# etcdcluster get --from-key '' //获取所有的键
foo
bar
foo1
bar1
foo2
bar2
foo3
bar3
[root@VM-0-13-centos ~]# etcdcluster get --from-key foo1  //获取名称大于或等于的所有键
foo1
bar1
foo2
bar2
foo3
bar3[root@VM-0-13-centos ~]# etcdcluster get foo1 foo3 //获取名称大于等于foo1且小于foo2的所有键
foo1
bar1
foo2
bar2
```

## DEL [options] <key> [range_end]

```
[root@VM-0-13-centos ~]# etcdcluster put foo bar
OK
[root@VM-0-13-centos ~]# etcdcluster del foo 
1
[root@VM-0-13-centos ~]# etcdcluster put key val //删除某个键
OK
[root@VM-0-13-centos ~]# etcdcluster del --prev-kv key //返回删除的键值
1
key
val
[root@VM-0-13-centos ~]# etcdcluster put a 123
OK
[root@VM-0-13-centos ~]# etcdcluster put b 456
OK
[root@VM-0-13-centos ~]# etcdcluster put c 789
OK
[root@VM-0-13-centos ~]# etcdcluster del --from-key a //从某个键开始删除
6
[root@VM-0-13-centos ~]# etcdcluster get --from-key a //检查a后面的是否删除
[root@VM-0-13-centos ~]# etcdcluster put zoo val
OK
[root@VM-0-13-centos ~]# etcdcluster put zoo1 val1
OK
[root@VM-0-13-centos ~]# etcdcluster put zoo2 val2
OK
[root@VM-0-13-centos ~]# etcdcluster del --prefix zoo //键值前缀匹配删除
3
[root@VM-0-13-centos ~]# etcdcluster get --from-key zoo
```

## 数据备份

```
[root@VM-0-13-centos ~]# etcdcluster snapshot save snapshot.db
{"level":"info","ts":1605871537.932119,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"snapshot.db.part"}
{"level":"info","ts":"2020-11-20T19:25:37.933+0800","caller":"clientv3/maintenance.go:200","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1605871537.9336457,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"106.53.131.85:2379"}
{"level":"info","ts":"2020-11-20T19:25:37.935+0800","caller":"clientv3/maintenance.go:208","msg":"completed snapshot read; closing"}
{"level":"info","ts":1605871537.9402754,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"106.53.131.85:2379","size":"25 kB","took":0.00810019}
{"level":"info","ts":1605871537.9403143,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"snapshot.db"}
Snapshot saved at snapshot.db
```

## 数据恢复

```
[root@VM-0-13-centos ~]# etcdcluster snapshot restore snapshot.db --data-dir=/var/run/etcd
{"level":"info","ts":1605871714.2255018,"caller":"snapshot/v3_snapshot.go:296","msg":"restoring snapshot","path":"snapshot.db","wal-dir":"/var/run/etcd/member/wal","data-dir":"/var/run/etcd","snap-dir":"/var/run/etcd/member/snap"}
{"level":"info","ts":1605871714.2265532,"caller":"membership/cluster.go:392","msg":"added member","cluster-id":"cdf818194e3a8c32","local-member-id":"0","added-peer-id":"8e9e05c52164694d","added-peer-peer-urls":["http://localhost:2380"]}
{"level":"info","ts":1605871714.242329,"caller":"snapshot/v3_snapshot.go:309","msg":"restored snapshot","path":"snapshot.db","wal-dir":"/var/run/etcd/member/wal","data-dir":"/var/run/etcd","snap-dir":"/var/run/etcd/member/snap"}
```

这里只做一些常用简单的命令进行操作，更多的命令使用可以参考https://github.com/etcd-io/etcd/tree/master/etcdctl进行操作使用。




