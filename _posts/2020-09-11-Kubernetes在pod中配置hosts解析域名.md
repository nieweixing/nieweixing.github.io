---
title: Kubernetes在pod中配置hosts解析域名
author: VashonNie
date: 2020-09-11 14:10:00 +0800
updated: 2020-09-11 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes]
math: true
---

本篇文章介绍了如何给pod配置host域名解析

当 DNS 配置以及其它选项不合理的时候，通过向 Pod 的 /etc/hosts 文件中添加条目，可以在 Pod 级别覆盖对主机名的解析。在 1.7 版本后，用户可以通过 PodSpec 的 HostAliases 字段来添加这些自定义的条目。

建议通过使用 HostAliases 来进行修改，因为该文件由 Kubelet 管理，并且可以在 Pod 创建/重启过程中被重写

```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
  creationTimestamp: "2020-09-11T08:35:00Z"
  generation: 2
  labels:
    k8s-app: nginx-hosts-alis
    qcloud-app: nginx-hosts-alis
  name: nginx-hosts-alis
  namespace: test
  resourceVersion: "12673987137"
  selfLink: /apis/apps/v1beta2/namespaces/test/deployments/nginx-hosts-alis
  uid: 61493e8e-b0c9-4b5d-a031-6ea2799e9de8
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: nginx-hosts-alis
      qcloud-app: nginx-hosts-alis
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: nginx-hosts-alis
        qcloud-app: nginx-hosts-alis
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx-hosts-alis
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          privileged: false
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      hostAliases:
      - hostnames:
        - foo.local
        - bar.local
        ip: 127.0.0.1
      - hostnames:
        - foo.remote
        - bar.remote
        ip: 10.1.2.3
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
```

yaml修改好之后，我们可以进入pod内进行验证，查看下pod的/etc/hosts文件是否有加上配置的域名解析

```
root@nginx-hosts-alis-5db8d7c54c-gf6km:/# cat /etc/hosts
# Kubernetes-managed hosts file.
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
fe00::0 ip6-mcastprefix
fe00::1 ip6-allnodes
fe00::2 ip6-allrouters
172.16.2.188    nginx-hosts-alis-5db8d7c54c-gf6km

# Entries added by HostAliases.
127.0.0.1       foo.local       bar.local
10.1.2.3        foo.remote      bar.remote
```

从上面的结果看，这里域名解析已经加入到对应的pod中。

注意事项：这里修改yaml需要注意字段的缩进，HostAliases是在.spec.hostAliases这个层级，和containers是同级的。
