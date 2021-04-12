---
title: TKE上搭建集群Dashboard
author: VashonNie
date: 2020-07-30 14:10:00 +0800
updated: 2020-07-30 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE,Dashboard]
math: true
---

如果需要将TKE的信息展示给多个部门的人查看，但是又不想让他们通过控制台查看，这边可以搭建一个dashborad用来展示。

# 申请证书

因为dashborad需要https的访问，这边需要提供下证书，这个证书可以是自建从，也可以从腾讯云上申请一个免费的1年证书

![upload-image](/assets/images/blog/Dashboard/1.png)

![upload-image](/assets/images/blog/Dashboard/2.png) 

购买成功后，需要审核，审核通过可以下载对应的证书和rsa key

![upload-image](/assets/images/blog/Dashboard/3.png) 

# 创建命名空间来部署dashboard

```
# kubectl  create namespace kubernetes-dashboard
```

# 引用申请的证书创建secret

将证书上传到linux机器上$HOME/certs目录，并分别改名为tls.key和tls.crt

```
# mkdir $HOME/certs
# kubectl create secret generic kubernetes-dashboard-certs --from-file=$HOME/certs -n kubernetes-dashboard
```

# 创建deployement

首先拉取yaml文件，需要修改下yaml文件中的部分配置，再apply这个yaml文件

```
# wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta6/aio/deploy/recommended.yaml
```

```
$ vim recommended.yaml

# 把创建 kubernetes-dashboard-certs Secret 注释掉，前面已通过命令创建

#apiVersion: v1
#kind: Secret
#metadata:
#  labels:
#    k8s-app: kubernetes-dashboard
#  name: kubernetes-dashboard-certs
#  namespace: kubernetes-dashboard
#type: Opaque

# 添加ssl证书路径，关闭自动更新证书，添加多长时间登出

      containers:
      - args:
        #- --auto-generate-certificates
        - --tls-cert-file=/tls.crt
        - --tls-key-file=/tls.key
        - --token-ttl=3600 #这个是登陆token的过期时间，如果不想重复输入token,可以设置长点
```

```
# kubectl  apply -f recommended.yaml

[root@VM_1_4_centos ~]# kubectl  get pods -n kubernetes-dashboard
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-555dc8bbb4-c8wtd   1/1     Running   0          24h
kubernetes-dashboard-755c66fc9f-p4tjd        1/1     Running   0          135m
```

# 创建登陆用户

```
# vim create-admin.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

创建账户

```
# kubectl apply -f create-admin.yaml
```

# 获取登陆token

```
# kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```

# 修改访问的svc为lb类型提供公网访问

Dashborad会创建2个svc，kubernetes-dashboard是用来页面访问的

![upload-image](/assets/images/blog/Dashboard/4.png) 

# 浏览器输入公网ip用https访问

输入https://vip 后会让你输入token，将第6步获取的token输入，就可以进行查看

![upload-image](/assets/images/blog/Dashboard/5.png)

