---
title: kubeadm证书过期如何替换
author: VashonNie
date: 2021-01-10 14:10:00 +0800
updated: 2021-01-10 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,Kubeadm]
math: true
---

通常我们通过kubeadm搭建的集群，证书都是由kubeadm生成的，证书的有效期只有1年，如果证书过期后，你再访问集群就会报错Unable to connect to the server: x509: certificate has expired or is not yet valid，今天我们来说下如何替换下证书过期的问题，本次集群的版本是1.15.10。

# 查看当前证书有效期

```
[root@master ~]# sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text |grep ' Not '
            Not Before: Dec 21 10:47:36 2019 GMT
            Not After : Dec 20 10:47:36 2020 GMT
```

# 配置集群kubeadm.conf

master节点上配置kubeadm.conf，然后填写集群的master和node节点ip信息，配置文件创建在master的/root/kubeadm.conf目录下

```
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.15.10  # kubernetes 版本
apiServer:
  certSANs:
  - 192.168.21.21 # master 所有节点IP地址，包括master和slave
  - 192.168.21.22 # slave
  - 192.168.21.23 # slave
  extraArgs:
    service-node-port-range: 80-32767
    advertise-address: 0.0.0.0
controlPlaneEndpoint: "192.168.21.21:6443"  # APIserver 地址,也就是master节点地址
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers #这里使用国内的镜像仓库，否则在重新签发的时候会报错
```

# 更新证书

```
[root@master ~]# kubeadm alpha certs renew all --config kubeadm.conf
certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
certificate for serving the Kubernetes API renewed
certificate the apiserver uses to access etcd renewed
certificate for the API server to connect to kubelet renewed
certificate embedded in the kubeconfig file for the controller manager to use renewed
certificate for liveness probes to healtcheck etcd renewed
certificate for etcd nodes to communicate with each other renewed
certificate for serving etcd renewed
certificate for the front proxy client renewed
certificate embedded in the kubeconfig file for the scheduler manager to use renewed
[root@master ~]# sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text |grep ' Not '
            Not Before: Dec 21 10:47:36 2019 GMT
            Not After : Feb 10 04:10:04 2022 GMT
```

# 重新生成配置文件

```
[root@master ~]# mv /etc/kubernetes/*.conf ~/.
[root@master ~]# kubeadm init phase kubeconfig all --config kubeadm.conf
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
```

# 更新kubeconfig

```
[root@master ~]# mv $HOME/.kube/config $HOME/.kube/config.old
[root@master ~]# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@master ~]# sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

# 重启master组件pod

重启kube-apiserver,kube-controller,kube-scheduler,etcd这4个容器

```
[root@master ~]# docker ps | grep -v pause | grep -E "etcd|scheduler|controller|apiserver" | awk '{print $1}' | awk '{print "docker","restart",$1}' | bash
a3e5533b5fe9
da6f74758c54
01053200a9ee
```

# 生成token

这里生成token是为了用于给node节点重新加入集群

```
[root@master ~]# kubeadm token create
xdy3g8.4nzmh2eezaz3ccx0
```

# 重启master节点kubelet

这里生成了新的证书后，发现master节点一直是Notready，然后查看kubelet日志发现是证书问题，这里是kubelet没重启，没有读取到最新的证书，重启kubelet即可

```
[root@master ~]# kubectl get nodes
NAME     STATUS     ROLES    AGE    VERSION
master   NotReady   master   416d   v1.15.0
node1    Ready      <none>   416d   v1.15.0
node2    Ready      <none>   416d   v1.15.0
[root@master ~]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since 六 2020-08-22 15:53:38 CST; 5 months 19 days ago
     Docs: https://kubernetes.io/docs/
 Main PID: 10568 (kubelet)
    Tasks: 20
   Memory: 80.8M
   CGroup: /system.slice/kubelet.service
           └─10568 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=syste...

2月 10 12:19:20 master kubelet[10568]: E0210 12:19:20.349191   10568 reflector.go:125] k8s.io/client-go/informers/factory.go:133: Failed to list *v1beta1.RuntimeClass: runtimeclasses.n... cluster scope
2月 10 12:19:20 master kubelet[10568]: E0210 12:19:20.549091   10568 reflector.go:125] k8s.io/kubernetes/pkg/kubelet/kubelet.go:453: Failed to list *v1.Node: nodes "master" is forbidde... cluster scope
2月 10 12:19:20 master kubelet[10568]: W0210 12:19:20.748794   10568 status_manager.go:485] Failed to get status for pod "kube-scheduler-master_kube-system(72815ad5dd205fae43f0c83b411c... "kube-system"
2月 10 12:19:20 master kubelet[10568]: E0210 12:19:20.948658   10568 reflector.go:125] k8s.io/kubernetes/pkg/kubelet/kubelet.go:444: Failed to list *v1.Service: services is forbidden: ... cluster scope
2月 10 12:19:21 master kubelet[10568]: E0210 12:19:21.149729   10568 reflector.go:125] k8s.io/kubernetes/pkg/kubelet/config/apiserver.go:47: Failed to list *v1.Pod: pods is forbidden: ... cluster scope
2月 10 12:19:21 master kubelet[10568]: E0210 12:19:21.349456   10568 reflector.go:125] object-"kube-system"/"kube-proxy-token-xr7jb": Failed to list *v1.Secret: secrets "kube-proxy-tok... "kube-system"
2月 10 12:19:21 master kubelet[10568]: E0210 12:19:21.548626   10568 reflector.go:125] object-"kube-system"/"kube-flannel-cfg": Failed to list *v1.ConfigMap: configmaps "kube-flannel-c... "kube-system"
2月 10 12:19:21 master kubelet[10568]: E0210 12:19:21.749376   10568 reflector.go:125] k8s.io/client-go/informers/factory.go:133: Failed to list *v1beta1.CSIDriver: csidrivers.storage.... cluster scope
2月 10 12:19:21 master kubelet[10568]: E0210 12:19:21.948609   10568 reflector.go:125] object-"kube-system"/"kube-proxy": Failed to list *v1.ConfigMap: configmaps "kube-proxy" is forbi... "kube-system"
2月 10 12:19:22 master kubelet[10568]: E0210 12:19:22.149386   10568 reflector.go:125] object-"kube-system"/"coredns-token-b7r9d": Failed to list *v1.Secret: secrets "coredns-token-b7r... "kube-system"
2月 10 12:19:22 master kubelet[10568]: E0210 12:19:22.348419   10568 reflector.go:125] object-"kube-system"/"coredns": Failed to list *v1.ConfigMap: configmaps "coredns" is forbidden: ... "kube-system"
2月 10 12:19:22 master kubelet[10568]: E0210 12:19:22.450047   10568 transport.go:110] It has been 5m0s since a valid client cert was found, but the server is not responsive. A restart...l credentials.
2月 10 12:19:22 master kubelet[10568]: E0210 12:19:22.549144   10568 reflector.go:125] object-"kube-system"/"flannel-token-8rcqc": Failed to list *v1.Secret: secrets "flannel-token-8rc... "kube-system"
2月 10 12:19:22 master kubelet[10568]: E0210 12:19:22.749477   10568 reflector.go:125] k8s.io/client-go/informers/factory.go:133: Failed to list *v1beta1.RuntimeClass: runtimeclasses.n... cluster scope

[root@master ~]# systemctl restart kubelet
[root@master ~]# kubectl get nodes
NAME     STATUS     ROLES    AGE    VERSION
master   NotReady   master   416d   v1.15.0
node1    Ready      <none>   416d   v1.15.0
node2    Ready      <none>   416d   v1.15.0
[root@master ~]# systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since 三 2021-02-10 12:19:47 CST; 14s ago
     Docs: https://kubernetes.io/docs/
 Main PID: 107339 (kubelet)
    Tasks: 19
   Memory: 64.1M
   CGroup: /system.slice/kubelet.service
           └─107339 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=syst...

2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.385973  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "ca-certs" (UniqueName: "ku...6140db63012c")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.385985  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "etc-pki" (UniqueName: "kub...6140db63012c")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.385998  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "k8s-certs" (UniqueName: "k...6140db63012c")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.386012  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "ca-certs" (UniqueName: "ku...de2b46660416")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.386026  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "k8s-certs" (UniqueName: "k...de2b46660416")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.386039  107339 reconciler.go:203] operationExecutor.VerifyControllerAttachedVolume started for volume "xtables-lock" (UniqueName:...df9dafada3c6")
2月 10 12:19:51 master kubelet[107339]: I0210 12:19:51.386048  107339 reconciler.go:150] Reconciler: start to sync state
2月 10 12:19:52 master kubelet[107339]: E0210 12:19:52.490132  107339 configmap.go:203] Couldn't get configMap kube-system/coredns: couldn't propagate object cache: timed out waiting for the condition
2月 10 12:19:52 master kubelet[107339]: E0210 12:19:52.490327  107339 nestedpendingoperations.go:270] Operation for "\"kubernetes.io/configmap/571e9358-c71e-4e4c-b956-44baaf7457c8-conf....628156112 (du
2月 10 12:19:57 master kubelet[107339]: I0210 12:19:57.748120  107339 transport.go:132] certificate rotation detected, shutting down client connections to start using new credentials
Hint: Some lines were ellipsized, use -l to show in full.
```

# node节点重新加入集群

我们分别登录node1和node2节点，首先删除旧的配置文件，然后停掉kubelet，然后执行命令加入集群即可，加入集群命令在不同node节点修改成对应节点名称。

```
[root@node1 ~]# rm -rf /etc/kubernetes/kubelet.conf
[root@node1 ~]# rm -rf /etc/kubernetes/bootstrap-kubelet.conf
[root@node1 ~]# rm -rf /etc/kubernetes/pki/ca.crt
[root@node1 ~]# systemctl stop kubelet
[root@node1 ~]# sudo kubeadm join --token=xdy3g8.4nzmh2eezaz3ccx0  192.168.21.21:6443 --node-name node1 --discovery-token-unsafe-skip-ca-verification
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.15" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

# 验证集群是否正常

执行完上面操作，到master上验证下集群是否正常，查看node和pod都没问题则说明更新证书成功

```
[root@master ~]# kubectl get nodes
NAME     STATUS   ROLES    AGE    VERSION
master   Ready    master   416d   v1.15.0
node1    Ready    <none>   416d   v1.15.0
node2    Ready    <none>   416d   v1.15.0
[root@master ~]# kubectl get pod -A
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
kube-system   coredns-bccdc95cf-hpxnx          1/1     Running   22         251d
kube-system   coredns-bccdc95cf-txff8          1/1     Running   29         270d
kube-system   etcd-master                      1/1     Running   39         416d
kube-system   kube-apiserver-master            1/1     Running   39         416d
kube-system   kube-controller-manager-master   1/1     Running   31         416d
kube-system   kube-flannel-ds-amd64-94qpm      1/1     Running   12         270d
kube-system   kube-flannel-ds-amd64-knhbk      1/1     Running   21         297d
kube-system   kube-flannel-ds-amd64-vshcz      1/1     Running   21         297d
kube-system   kube-proxy-glkk9                 1/1     Running   12         270d
kube-system   kube-proxy-js6cb                 1/1     Running   29         416d
kube-system   kube-proxy-vqr5l                 1/1     Running   33         416d
kube-system   kube-scheduler-master            1/1     Running   31         416d
kube-system   tiller-deploy-75f5747884-cvhs9   1/1     Running   23         297d
```