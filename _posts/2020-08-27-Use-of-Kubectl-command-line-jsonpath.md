---
title: Kubectl命令行jsonpath的使用
author: VashonNie
date: 2020-08-27 14:10:00 +0800
updated: 2020-08-27 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,kubectl]
math: true
---

本篇文章主要介绍了jsonpath的语法和使用。

# jsonpath的语法介绍

Kubectl 支持 JSONPath 模板。

JSONPath 模板由 {} 包起来的 JSONPath 表达式组成。Kubectl 使用 JSONPath 表达式来过滤 JSON 对象中的特定字段并格式化输出。除了原始的 JSONPath 模板语法，以下函数和语法也是有效的:

1. 使用双引号将 JSONPath 表达式内的文本引起来。
2. 使用 range，end 运算符来迭代列表。
3. 使用负片索引后退列表。负索引不会"环绕"列表，并且只要 -index + listLength> = 0 就有效。

|函数|描述|示例|结果|
|----|----|----|----|
|text|纯文本|kind is {.kind}|kind is List|
|@|当前对象|{@}|与输入相同|
|. or []|子运算符|{.kind} or {['kind']}|List|
|..|递归下降|{..name}|127.0.0.1 127.0.0.2 myself e2e|
|*|通配符。获取所有对象|{.items[*].metadata.name}|[127.0.0.1 127.0.0.2]|
|[start:end :step]|下标运算符|{.users[0].name}|myself|
|[,]|并集运算符|{.items[*]['metadata.name', 'status.capacity']}|127.0.0.1 127.0.0.2 map[cpu:4] map[cpu:8]|
|?()|过滤|{.users[?(@.name=="e2e")].user.password}|secret|
|range, end|迭代列表|{range .items[*]}[{.metadata.name}, {.status.capacity}] {end}|[127.0.0.1, map[cpu:4]] [127.0.0.2, map[cpu:8]]|
|''|引用解释执行字符串|{range .items[*]}{.metadata.name}{'\t'}{end}|127.0.0.1 127.0.0.2|

下面我们在k8s中使用jsonpath来获取我们想要的内容

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o json
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "annotations": {
            "tke.cloud.tencent.com/networks-status": "[{\n    \"name\": \"tke-bridge\",\n    \"ips\": [\n        \"172.16.3.92\"\n    ],\n    \"default\": true,\n    \"dns\": {}\n}]"
        },
        "creationTimestamp": "2020-08-25T09:15:55Z",
        "generateName": "redis-5b4495ddb4-",
        "labels": {
            "k8s-app": "redis",
            "pod-template-hash": "5b4495ddb4",
            "qcloud-app": "redis"
        },
        "name": "redis-5b4495ddb4-szjtz",
        "namespace": "default",
        "ownerReferences": [
            {
                "apiVersion": "apps/v1",
                "blockOwnerDeletion": true,
                "controller": true,
                "kind": "ReplicaSet",
                "name": "redis-5b4495ddb4",
                "uid": "bef91151-d94e-46d5-a8a9-59a8f3ae634e"
            }
        ],
        "resourceVersion": "12100505479",
        "selfLink": "/api/v1/namespaces/default/pods/redis-5b4495ddb4-szjtz",
        "uid": "968a56ba-80ed-41d3-ad27-deb7d060bfe7"
    },
    "spec": {
        "containers": [
            {
                "image": "redis",
                "imagePullPolicy": "Always",
                "name": "redis",
                "resources": {
                    "limits": {
                        "cpu": "500m",
                        "memory": "1Gi"
                    },
                    "requests": {
                        "cpu": "250m",
                        "memory": "256Mi"
                    }
                },
                "securityContext": {
                    "privileged": false
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeMounts": [
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "default-token-cl2h8",
                        "readOnly": true
                    }
                ]
            }
        ],
        "dnsPolicy": "ClusterFirst",
        "enableServiceLinks": true,
        "imagePullSecrets": [
            {
                "name": "qcloudregistrykey"
            }
        ],
        "nodeName": "10.168.1.4",
        "restartPolicy": "Always",
        "schedulerName": "default-scheduler",
        "securityContext": {},
        "serviceAccount": "default",
        "serviceAccountName": "default",
        "terminationGracePeriodSeconds": 30,
        "volumes": [
            {
                "name": "default-token-cl2h8",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "default-token-cl2h8"
                }
            }
        ]
    },
    "status": {
        "conditions": [
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2020-08-25T09:15:55Z",
                "status": "True",
                "type": "Initialized"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2020-08-25T09:15:59Z",
                "status": "True",
                "type": "Ready"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2020-08-25T09:15:59Z",
                "status": "True",
                "type": "ContainersReady"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2020-08-25T09:15:55Z",
                "status": "True",
                "type": "PodScheduled"
            }
        ],
        "containerStatuses": [
            {
                "containerID": "docker://0a4540282684c9dd282d13eba9a4ae44433f625e65ef40473cda7ca00b2ea73e",
                "image": "redis:latest",
                "imageID": "docker-pullable://redis@sha256:09c33840ec47815dc0351f1eca3befe741d7105b3e95bc8fdb9a7e4985b9e1e5",
                "lastState": {},
                "name": "redis",
                "ready": true,
                "restartCount": 0,
                "started": true,
                "state": {
                    "running": {
                        "startedAt": "2020-08-25T09:15:59Z"
                    }
                }
            }
        ],
        "hostIP": "10.168.1.4",
        "phase": "Running",
        "podIP": "172.16.3.92",
        "podIPs": [
            {
                "ip": "172.16.3.92"
            }
        ],
        "qosClass": "Burstable",
        "startTime": "2020-08-25T09:15:55Z"
    }
}

```

# 通过jsonpath获取信息示例

## 纯文本方式

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='kind is {.kind}'
kind is Pod

```
## 获取当前对象

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath={@}
map[apiVersion:v1 kind:Pod metadata:map[annotations:map[tke.cloud.tencent.com/networks-status:[{
    "name": "tke-bridge",
    "ips": [
        "172.16.3.92"
    ],
    "default": true,
    "dns": {}
}]] creationTimestamp:2020-08-25T09:15:55Z generateName:redis-5b4495ddb4- labels:map[k8s-app:redis pod-template-hash:5b4495ddb4 qcloud-app:redis] name:redis-5b4495ddb4-szjtz namespace:default ownerReferences:[map[apiVersion:apps/v1 blockOwnerDeletion:true controller:true kind:ReplicaSet name:redis-5b4495ddb4 uid:bef91151-d94e-46d5-a8a9-59a8f3ae634e]] resourceVersion:12100505479 selfLink:/api/v1/namespaces/default/pods/redis-5b4495ddb4-szjtz uid:968a56ba-80ed-41d3-ad27-deb7d060bfe7] spec:map[containers:[map[image:redis imagePullPolicy:Always name:redis resources:map[limits:map[cpu:500m memory:1Gi] requests:map[cpu:250m memory:256Mi]] securityContext:map[privileged:false] terminationMessagePath:/dev/termination-log terminationMessagePolicy:File volumeMounts:[map[mountPath:/var/run/secrets/kubernetes.io/serviceaccount name:default-token-cl2h8 readOnly:true]]]] dnsPolicy:ClusterFirst enableServiceLinks:true imagePullSecrets:[map[name:qcloudregistrykey]] nodeName:10.168.1.4 restartPolicy:Always schedulerName:default-scheduler securityContext:map[] serviceAccount:default serviceAccountName:default terminationGracePeriodSeconds:30 volumes:[map[name:default-token-cl2h8 secret:map[defaultMode:420 secretName:default-token-cl2h8]]]] status:map[conditions:[map[lastProbeTime:<nil> lastTransitionTime:2020-08-25T09:15:55Z status:True type:Initialized] map[lastProbeTime:<nil> lastTransitionTime:2020-08-25T09:15:59Z status:True type:Ready] map[lastProbeTime:<nil> lastTransitionTime:2020-08-25T09:15:59Z status:True type:ContainersReady] map[lastProbeTime:<nil> lastTransitionTime:2020-08-25T09:15:55Z status:True type:PodScheduled]] containerStatuses:[map[containerID:docker://0a4540282684c9dd282d13eba9a4ae44433f625e65ef40473cda7ca00b2ea73e image:redis:latest imageID:docker-pullable://redis@sha256:09c33840ec47815dc0351f1eca3befe741d7105b3e95bc8fdb9a7e4985b9e1e5 lastState:map[] name:redis ready:true restartCount:0 started:true state:map[running:map[startedAt:2020-08-25T09:15:59Z]]]] hostIP:10.168.1.4 phase:Running podIP:172.16.3.92 podIPs:[map[ip:172.16.3.92]] qosClass:Burstable startTime:2020-08-25T09:15:55Z]]
```

## 获取pod的apiversion

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{.apiVersion}'
v1
```

## 获取pod的name

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{.metadata.name}'
redis-5b4495ddb4-szjtz
```

## 递归获取yaml所有的name

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{..name}'
qcloudregistrykey default-token-cl2h8 redis default-token-cl2h8 redis redis-5b4495ddb4-szjtz redis-5b4495ddb4
```

## 获取所有状态条件中的类型

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath={.status.conditions[*].type}
Initialized Ready ContainersReady PodScheduled[
```

## 获取状态第一个条件的类型

```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath={.status.conditions[0].type}
Initialized
```

## 从第一个状态条件开始到最后一个结束，每隔2个获取一次
```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath={.status.conditions[0:3:2].type}
Initialized ContainersReady
```

## 获取状态条件中的状态和类型
```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{range .status.conditions[*]}[{..status}, {..type}]{end}'
[True, Initialized][True, Ready][True, ContainersReady][True, PodScheduled]
```

## 空格和换行符的引用
```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{range .status.conditions[*]}[{..status}, {..type}]{"\n"}{end}'
[True, Initialized]
[True, Ready]
[True, ContainersReady]
[True, PodScheduled]
```

## 获取request中的cpu值
```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{range .spec.containers[0].resources}[{..cpu}]{end}'
[500m 250m]
```

## 获取request中的cpu和memory
```
[root@VM_1_4_centos ~]# kubectl get pod redis-5b4495ddb4-szjtz -o=jsonpath='{range .spec.containers[0].resources}[{..cpu}, {..memory}]{end}'
[500m 250m, 1Gi 256Mi]
```

## 获取promotheus这个pod中alertmanage的容器端口
prometheus的yaml文件只截取部分

```
[root@VM_1_4_centos ~]# kubectl get pod prometheus-7674d56d7f-dqxfx -n kube-ops -o json
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "name": "prometheus-7674d56d7f-dqxfx",
        "namespace": "kube-ops",
    },
    "spec": {
        "containers": [
            {
                "args": [
                    "--config.file=/etc/alertmanager/config.yml",
                    "--storage.path=/alertmanager/data"
                ],
                "image": "prom/alertmanager:v0.15.3",
                "imagePullPolicy": "IfNotPresent",
                "name": "alertmanager",
                "ports": [
                    {
                        "containerPort": 9093,
                        "name": "http",
                        "protocol": "TCP"
                    }
                ],  
             .........
            },
            {
                "command": [
                    "/bin/prometheus"
                ],
                "image": "prom/prometheus:v2.4.3",
                "imagePullPolicy": "IfNotPresent",
                "name": "prometheus",
                "ports": [
                    {
                        "containerPort": 9090,
                        "name": "http",
                        "protocol": "TCP"
                    }
            }
.......
[root@VM_1_4_centos ~]# kubectl get pod prometheus-7674d56d7f-dqxfx -n kube-ops -o=jsonpath='{.spec.containers[?(@.name=="alertmanager")].ports}'
[map[containerPort:9093 name:http protocol:TCP]]

```

# 参考文档

<https://kubernetes.io/zh/docs/reference/kubectl/jsonpath/>