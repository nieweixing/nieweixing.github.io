---
title: TKE上部署metrics-server
author: VashonNie
date: 2020-08-13 14:10:00 +0800
updated: 2020-08-13 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE]
math: true
---

kubectl top 是基础命令，但是需要部署配套的组件才能获取到监控值

* 1.8以下：部署 heapter

* 1.8以上：部署 metric-server

下面我们来在TKE上配置下1.8版本以上的metric-server


# 获取metric-server的部署yaml

登录能执行kubectl命令的客户端机器，执行下面命令下载

```
# git clone https://github.com/kubernetes-incubator/metrics-server
# cd metrics-server/manifests/base
[root@VM_0_13_centos base]# ll
total 24
-rw-r--r-- 1 root root  298 Jul  8 11:57 apiservice.yaml
-rw-r--r-- 1 root root 1386 Aug 13 10:35 deployment.yaml
-rw-r--r-- 1 root root  158 Jul  8 11:57 kustomization.yaml
-rw-r--r-- 1 root root  239 Jul  8 11:57 pdb.yaml
-rw-r--r-- 1 root root 1714 Jul  8 11:57 rbac.yaml
-rw-r--r-- 1 root root  297 Jul  8 11:57 service.yaml
```

# 修改yaml文件参数

修改对应的metrics-server-deployment.yaml文件，需要改镜像源，国外的镜像需要科学上网下载，还需要添加如下参数

command:
\- /metrics-server
\- --kubelet-preferred-address-types=InternalIP
\- --kubelet-insecure-tls

不添加参数报错，metrics-server 启动提示no metrics known for pod?

首先需要知道的是metrics-server默认会使用hostname 来进行通讯。

如果没有进行相应配置的话，那么通过hostname是无法正常通讯的。

所以使用默认命令行启动，由于无法正常通过hostname通信就会产生错误， 从而提示no metrics known for pod

实际上metrics-server不只支持通过hostname进行通讯，还支持使用IP来进行通讯，只不过需要显式指定命令行参数：

--kubelet-preferred-address-types=InternalIP

其中InternalIP可以修改为以下值:

InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP (具体含义这里就不展开了，感兴趣的可以自行了解。)

但是呢，事情到这里还没有结束，当你加上命令行参数后，会发现出现另一个错误x509: cannot validate certificate。

这是由于证书验证不通过导致的，所以我们需要让metrics-server忽略掉证书错误。而忽略证书错误也是有命令行支持的，我们添加如下命令行参数就可以解决了：

--kubelet-insecure-tls

修改后的yaml如下：

```
[root@VM_0_13_centos base]# cat deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    k8s-app: metrics-server
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      volumes:
      # mount in tmp so we can safely use from-scratch images and/or read-only containers
      - name: tmp-dir
        emptyDir: {}
      containers:
      - name: metrics-server
        image: ccr.ccs.tencentyun.com/mirrors/metrics-server-amd64:v0.3.1
        imagePullPolicy: IfNotPresent
        command:
          - /metrics-server
          - --kubelet-preferred-address-types=InternalIP
          - --kubelet-insecure-tls
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
        ports:
        - name: main-port
          containerPort: 4443
          protocol: TCP
        readinessProbe:
          httpGet:
            path: /healthz
            port: main-port
            scheme: HTTPS
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
      nodeSelector:
        kubernetes.io/os: linux
```

# 执行apply部署对应的yaml文件

我们在对应的部署目录文件中发现有一个kustomization.yaml，这个文件的作用可以先了解下kustomize这个项目。

kustomize是sig-cli的一个子项目，它的设计目的是给kubernetes的用户提供一种可以重复使用同一套配置的声明式应用管理，从而在配置工作中用户只需要管理和维护kubernetes的API对象，而不需要学习或安装其它的配置管理工具，也不需要通过复制粘贴来得到新的环境的配置。

我们这里不做kustomize的部署，所以后续不需要applykustomization.yaml这个yaml。

我们这里直接部署目录下的所有yaml文件，有一个报错不用管，是因为我们没安装kustomize。

```
[root@VM_0_13_centos base]# kubectl apply -f .
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io unchanged
deployment.apps/metrics-server configured
poddisruptionbudget.policy/metrics-server unchanged
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader unchanged
serviceaccount/metrics-server unchanged
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader unchanged
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator unchanged
clusterrole.rbac.authorization.k8s.io/system:metrics-server unchanged
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server unchanged
service/metrics-server unchanged
error: unable to recognize "kustomization.yaml": no matches for kind "Kustomization" in version "kustomize.config.k8s.io/v1beta1"
```

# 验证和执行命令查看pod和node的内存及cpu指标

这边metrics-server运行正常后，执行命令是可以正常查看node和pod的性能指标的

```
[root@VM_0_13_centos base]# kubectl get pod -n kube-system | grep metrics-server
metrics-server-6b59b7fc98-wkvmz         1/1     Running   0          136m

[root@VM_0_13_centos base]# kubectl top nodes
NAME            CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
10.168.1.4      432m         5%     7360Mi          52%
10.168.1.5      1342m        34%    5489Mi          82%
10.168.100.22   109m         2%     4401Mi          62%
[root@VM_0_13_centos base]# kubectl top node 10.168.1.4
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
10.168.1.4   432m         5%     7360Mi          52%
[root@VM_0_13_centos base]# kubectl top pod -n kube-system
NAME                                    CPU(cores)   MEMORY(bytes)
ccs-log-collector-7h4qv                 8m           182Mi
ccs-log-collector-jgh88                 4m           499Mi
ccs-log-collector-t4gsc                 3m           187Mi
cls-provisioner-5c5dcfb9fc-bsjrb        1m           9Mi
coredns-7f47d46d54-257rj                2m           13Mi
coredns-7f47d46d54-h6czg                3m           23Mi
csi-attacher-cfsplugin-0                2m           14Mi
csi-coslauncher-mc488                   1m           30Mi
csi-coslauncher-nxjsb                   1m           60Mi
csi-coslauncher-wfs7m                   1m           11Mi
csi-cosplugin-external-runner-0         2m           14Mi
csi-cosplugin-s8xf6                     1m           6Mi
csi-cosplugin-vzdfn                     1m           7Mi
csi-cosplugin-xpkbp                     1m           33Mi
csi-nodeplugin-cfsplugin-j467w          1m           24Mi
csi-nodeplugin-cfsplugin-jpctb          1m           12Mi
csi-nodeplugin-cfsplugin-r2kjc          1m           10Mi
csi-provisioner-cfsplugin-0             2m           16Mi
ip-masq-agent-cvrsl                     1m           10Mi
ip-masq-agent-hv2p6                     1m           6Mi
ip-masq-agent-zfmg5                     1m           8Mi
kube-proxy-hzzhb                        14m          74Mi
kube-proxy-lrh8l                        21m          45Mi
kube-proxy-pjbmm                        15m          64Mi
kubernetes-dashboard-654cb6dc56-pql6z   1m           16Mi
l7-lb-controller-5b49444bc9-wbt8j       2m           28Mi
metrics-server-6b59b7fc98-wkvmz         1m           18Mi
swift-566d576-2rtsz                     1m           25Mi
tiller-deploy-698956c985-7njgz          1m           15Mi
tke-bridge-agent-c86n7                  2m           14Mi
tke-bridge-agent-hstm7                  2m           10Mi
tke-bridge-agent-sl5j5                  1m           9Mi
tke-cni-agent-fllwd                     0m           4Mi
tke-cni-agent-js9ls                     0m           18Mi
tke-cni-agent-q7vb8                     0m           13Mi
tke-eni-agent-694nz                     1m           28Mi
tke-eni-agent-sskl9                     1m           8Mi
tke-eni-agent-vkt92                     1m           14Mi
tke-eni-ipamd-b866c887f-bgq5z           3m           20Mi
tke-log-agent-6jt2l                     2m           42Mi
tke-log-agent-jwpwq                     994m         96Mi
tke-log-agent-vmndp                     4m           112Mi
tke-persistent-event-5d6fc9bccd-nrsqp   1m           82Mi
```