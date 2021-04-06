---
title: Kubernetes强制删除Terminating的ns
author: VashonNie
date: 2020-10-14 14:10:00 +0800
updated: 2020-11-08 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes]
math: true
---

本文主要介绍了在使用k8s的过程中Terminating的ns无法删除，如何强制删除Terminating的ns。

## kubectl get ns 查看处于Terminating的ns
```
[root@VM_1_4_centos ~]# kubectl get ns | grep testns
testns                   Terminating   21d
```

## 将处于Terminating的ns的描述文件保存下来
```
[root@VM_1_4_centos ~]# kubectl get ns testns -o json > tmp.json
[root@VM_1_4_centos ~]# cat tmp.json 
{
    "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
        "creationTimestamp": "2020-10-13T14:28:07Z",
        "name": "testns",
        "resourceVersion": "13782744400",
        "selfLink": "/api/v1/namespaces/testns",
        "uid": "9ff63d71-a4a1-43bc-89e3-78bf29788844"
    },
    "spec": {
        "finalizers": [
            "kubernetes"
        ]
    },
    "status": {
        "phase": "Terminating"
    }
}
```

## 本地启动kube proxy
```
kubectl proxy --port=8081
```

## 新开窗口执行删除操作
```
curl -k -H "Content-Type: application/json" -X PUT --data-binary @tmp.json http://127.0.0.1:8081/api/v1/namespaces/testns/finalize
```

