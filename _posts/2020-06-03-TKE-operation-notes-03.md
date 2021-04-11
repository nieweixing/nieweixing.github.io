---
title: TKE操作笔记03
author: VashonNie
date: 2020-06-03 14:10:00 +0800
updated: 2020-06-03 14:10:00 +0800
categories: [TKE,腾讯云]
tags: [Kubernetes,Docker,TKE]
math: true
---

该文章主要介绍了存储卷在TKE上的使用。

# PV，PVC，StoragClass配置使用

## StoragClass配置使用

StorageClass 描述存储的类型，集群管理员可以为集群定义不同的存储类别。腾讯云 TKE 服务默认提供块存储类型的 StorageClass，通过 StorageClass 配合 PersistentVolumeClaim 可以动态创建需要的存储资源。

![upload-image](/assets/images/blog/tke03/1.png) 

找到你的集群，选择存储中的storaeclass，点击新建

![upload-image](/assets/images/blog/tke03/2.png) 

根据实际需求，设置 StorageClass 参数。关键参数信息如下：

* 名称：自定义。（我填写的是nwx-sc）
* 计费模式：根据实际需求进行选择。（我选择的是按量计费）
* 可用区：根据实际需求进行设置，默认为 “随机可用区”。（我这里选择广州三区）
* 云盘类型：根据实际需求进行选择。（我选择的是高性能云硬盘）
* 回收策略：根据实际需求进行选择。（我选择的是删除）

单击【创建StorageClass】，完成创建。

![upload-image](/assets/images/blog/tke03/3.png) 

至此，storageclass创建完成！

## PVC的配置使用
### 创建PVC

PersistentVolumeClaim（PVC）：集群内的存储请求。例如，PV 是 Pod 使用节点资源，PVC 则声明使用 PV 资源。当 PV 资源不足时，PVC 也可以动态创建 PV。

![upload-image](/assets/images/blog/tke03/4.png) 

点击存储，选择PVC,再点击新建

![upload-image](/assets/images/blog/tke03/5.png) 

填写pvc名称，我这里写的是nwx-test-pvc，选择命名空间为test，读写权限为单机读写，SC选择我们之前创建的nwx-sc，大小为10G。

![upload-image](/assets/images/blog/tke03/6.png) 

PVC已经创建完成

### 控制台配置挂载PVC

我们把新建的pvc挂载到之前的nginx服务中，我们可以通过修改yaml和在控制台修改配置进行挂载

![upload-image](/assets/images/blog/tke03/7.png) 

找到我们之前创建的deployment，然后点击pod配置修改

![upload-image](/assets/images/blog/tke03/8.png) 

数据卷选择我们之前创建的PVC，然后在挂载点钟选择挂载的PVC和挂载路径，我们这里挂载到/tmp

### 修改yaml挂载PVC

在控制台修改yaml

![upload-image](/assets/images/blog/tke03/9.png) 

命令修改yaml
```
[root@VM_0_13_centos ~]# kubectl get deployment -n test
[root@VM_0_13_centos ~]# kubectl edit deployment new-nginx -n test
```
![upload-image](/assets/images/blog/tke03/10.png) 

完整的yaml文件
```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
  creationTimestamp: "2020-06-02T09:36:11Z"
  generation: 2
  labels:
    k8s-app: new-nginx
    qcloud-app: new-nginx
  name: new-nginx
  namespace: test
  resourceVersion: "8614784222"
  selfLink: /apis/apps/v1beta2/namespaces/test/deployments/new-nginx
  uid: 7e77455e-a4b4-11ea-9c35-e28957d7d0b3
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: new-nginx
      qcloud-app: new-nginx
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: new-nginx
        qcloud-app: new-nginx
    spec:
      containers:
      - env:
        - name: RUNTIME
          valueFrom:
            configMapKeyRef:
              key: RUNTIME
              name: nginx-env
              optional: false
        - name: TZ
          valueFrom:
            configMapKeyRef:
              key: TZ
              name: nginx-env
              optional: false
        image: ccr.ccs.tencentyun.com/tmptest/nwx-nginx
        imagePullPolicy: IfNotPresent
        name: new-my-nginx
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          privileged: false
          procMount: Default
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /tmp
          name: data-volume
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: test-secret
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: nwx-pvc1
status:
  availableReplicas: 1
  conditions:
  - lastTransitionTime: "2020-06-03T02:41:32Z"
    lastUpdateTime: "2020-06-03T02:41:32Z"
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: "2020-06-02T09:36:11Z"
    lastUpdateTime: "2020-06-03T02:51:59Z"
    message: ReplicaSet "new-nginx-86774775f6" has successfully progressed.
    reason: NewReplicaSetAvailable
    status: "True"
    type: Progressing
  observedGeneration: 2
  readyReplicas: 1
  replicas: 1
  updatedReplicas: 1
```
### 验证PVC是否挂载成功

![upload-image](/assets/images/blog/tke03/11.png) 

## PV的配置使用

### 动态创建PV

PersistentVolume（PV）：集群内的存储资源，例如节点是集群的资源。PV 独立于 Pod 的生命周期，根据不同的 StorageClass 类型创建不同类型的 PV。

![upload-image](/assets/images/blog/tke03/12.png) 

当我们在PVC中引用对应的SC，会动态的创建PV。

### 静态创建CBS类型PV

![upload-image](/assets/images/blog/tke03/13.png) 

![upload-image](/assets/images/blog/tke03/14.png) 

静态PV支持三种类型，CFS和COS需要去扩展组件中安装组件

![upload-image](/assets/images/blog/tke03/15.png) 

安装COS和CFS组件

![upload-image](/assets/images/blog/tke03/16.png) 

静态创建CBS类型pv，选择关联的SC即可

### 静态创建CFS类型PV并关联到PVC

![upload-image](/assets/images/blog/tke03/17.png)

先要创建好CFS类型的SC

![upload-image](/assets/images/blog/tke03/18.png)

![upload-image](/assets/images/blog/tke03/19.png) 

在集群的同一个私有网络下创建NFS

![upload-image](/assets/images/blog/tke03/20.png) 

![upload-image](/assets/images/blog/tke03/21.png) 

静态创建pv,并关联之前的sc和新建的NFS

![upload-image](/assets/images/blog/tke03/22.png) 

创建PVC，关联创建的nfs类型pv,创建成功，即可引用

![upload-image](/assets/images/blog/tke03/23.png) 

创建成功，可以在yaml中或者控制台修改deployment配置进行挂载

### 静态创建CBS类型PV并关联到PVC

首先在云服务器中创建你所需要的CBS卷

![upload-image](/assets/images/blog/tke03/24.png) 

创建pv，选择你创建的云盘

![upload-image](/assets/images/blog/tke03/25.png) 

创建PVC，选择你的容量，注意，如果你之前创建了多个PV，PVC关联的规则选择容量大于或等于当前PVC设置的容量大小的静态创建的PersistentVolume

![upload-image](/assets/images/blog/tke03/26.png) 

创建成功，可以在yaml中或者控制台修改deployment配置进行挂载

