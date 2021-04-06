---
title: k8s之externalTrafficPolicy保留客户端源IP
author: VashonNie
date: 2020-11-26 14:10:00 +0800
updated: 2020-11-26 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,externalTrafficPolicy]
math: true
---

使用k8s暴露我们的服务给外部访问的方式主要是有2种，一种就是nodeport类型，还有一种就是LoadBalancer，通常这2中都会做一个负载均衡，但是有一个问题就是服务端可能无法获取到客户端的真实ip，service.spec.externalTrafficPolicy这个字段就帮您解决了这个问题。

service.spec.externalTrafficPolicy - 表示此服务是否希望将外部流量路由到节点本地或集群范围的端点。 有两个可用选项：Cluster（默认）和 Local。 Cluster 隐藏了客户端源 IP，可能导致第二跳到另一个节点，但具有良好的整体负载分布。 Local 保留客户端源 IP 并避免 LoadBalancer 和 NodePort 类型服务的第二跳， 但存在潜在的不均衡流量传播风险。

externalTrafficPolicy存在2种模式，一种是默认的Cluster类型，一种是Local类型，Cluster类型就是service基本的模式负载均衡，今天我们来讲一下Local这种模式，为什么Local模式会出现负载不均衡。

首先我们创建一个externalTrafficPolicy为Cluster类型的service，大家都知道k8s中的网络策略都是通过kube-proxy来配置iptables规则来进行转发的，下面我们查看下externalTrafficPolicy为Cluster类型的service对应nodeport的iptables规则

```
[root@VM-0-3-centos ~]# kubectl get svc -n test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
go-test                       ClusterIP      172.16.46.161   <none>          80/TCP         4d16h
nginx                         ClusterIP      172.16.45.116   <none>          80/TCP         7d21h
nginx-externaltrafficpolicy   NodePort       172.16.22.159   <none>          80:31015/TCP   15h
nginx-log                     LoadBalancer   172.16.96.7     106.55.216.XX   80:31465/TCP   3d
springboot                    ClusterIP      172.16.77.157   <none>          8080/TCP       4d
[root@VM-0-3-centos ~]# iptables-save | grep 31465
-A KUBE-NODEPORTS -p tcp -m comment --comment "test/nginx-log:80-80-tcp" -m tcp --dport 31465 -j KUBE-MARK-MASQ
-A KUBE-NODEPORTS -p tcp -m comment --comment "test/nginx-log:80-80-tcp" -m tcp --dport 31465 -j KUBE-SVC-4MORCIL57YHWCCJM
```

我们nignx-log这个service就是Cluster类型，我们发现节点上对应31465这个nodeport的iptables规则就是放通所有来源ip来进行访问这个端口。

下面我们再看看Local类型的service，对应的iptables规则是什么样，这里我们nginx-externaltrafficpolicy这个service就是Local类型，对应service的yaml文件如下。

```
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.cloud.tencent.com/local-svc-weighted-balance: "false"
    service.kubernetes.io/local-svc-only-bind-node-with-pod: "false"
  creationTimestamp: "2020-11-26T10:11:47Z"
  managedFields:
  - apiVersion: v1
    manager: tke-apiserver
    operation: Update
    time: "2020-11-26T10:11:47Z"
  name: nginx-externaltrafficpolicy
  namespace: test
  resourceVersion: "2118736256"
  selfLink: /api/v1/namespaces/test/services/nginx-externaltrafficpolicy
  uid: 7255ae77-0d6c-45da-8171-60521535d020
spec:
  clusterIP: 172.16.22.159
  externalTrafficPolicy: Local
  ports:
  - name: 80-80-tcp
    nodePort: 31015
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    k8s-app: nginx-externaltrafficpolicy
    qcloud-app: nginx-externaltrafficpolicy
  sessionAffinity: None
  type: NodePort
status:
  loadBalancer: {}
```

```
[root@VM-0-3-centos ~]# kubectl get svc -n test | grep nginx-externaltrafficpolicy
nginx-externaltrafficpolicy   NodePort       172.16.22.159   <none>          80:31015/TCP   16h
[root@VM-0-3-centos ~]# iptables-save | grep 31015
-A KUBE-NODEPORTS -s 127.0.0.0/8 -p tcp -m comment --comment "test/nginx-externaltrafficpolicy:80-80-tcp" -m tcp --dport 31015 -j KUBE-MARK-MASQ
-A KUBE-NODEPORTS -p tcp -m comment --comment "test/nginx-externaltrafficpolicy:80-80-tcp" -m tcp --dport 31015 -j KUBE-XLB-3LS5F4HE6J2O753K
```

:KUBE-MARK-MASQ - [0:0] /*对于符合条件的包 set mark 0x4000, 有此标记的数据包会在KUBE-POSTROUTING chain中统一做MASQUERADE*/

对于KUBE-MARK-MASQ链中所有规则设置了kubernetes独有MARK标记，在KUBE-POSTROUTING链中对NODE节点上匹配kubernetes独有MARK标记的数据包，进行SNAT处理。

查看节点上nginx-externaltrafficpolicy的nodeport端口的iptables规则，细心的你肯定发现有个地方和Cluster类型的是不一样的，那就是第一条规则中加了一个源ip网段的访问限制，默认只有127.0.0.0/8才能访问这个，那么Local模式的原理这里就清楚了，其实就是这个iptables规则配置的源ip导致的。

这也就是为啥你访问对应的nodeport的时候，只有pod所在的节点才能访问通，我们在同一个vpc下非集群节点进行访问nginx-externaltrafficpolicy这个pod测试一下

```
[root@VM-0-3-centos ~]# kubectl get pod -n test -o wide | grep nginx-externaltrafficpolicy-6654865c87-25cnq
nginx-externaltrafficpolicy-6654865c87-25cnq   2/2     Running   0          16h     10.0.2.37    10.0.0.3    <none>           1/1
```

```
[root@VM-0-13-centos ~]# curl 10.0.0.3:31015
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
[root@VM-0-13-centos ~]# curl 10.0.0.10:31015

```

我们发现nginx-externaltrafficpolicy这个pod部署在10.0.0.3这个node上，我们在10.0.0.13这个节点访问nodeport，只有10.0.0.3这个节点的31015这个nodeport可以通，这也是符合Local模式的。

有的时候我们在定位问题也可以注意一下这个配置，可能出现只能访问pod所在节点才能通，这里可以检查下这个配置是否配置成了Local。