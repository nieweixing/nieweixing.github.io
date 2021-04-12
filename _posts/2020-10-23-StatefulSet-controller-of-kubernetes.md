---
title: kubernetes之StatefulSet控制器
author: VashonNie
date: 2020-10-23 14:10:00 +0800
updated: 2020-10-23 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes]
math: true
---

本文将带你了解k8s中的StatefulSet控制器，将通过实验的方式来说明StatefulSet的用法和配置，让你快速能够将StatefulSet类型的服务用到你的k8s集群中。

# 什么是StatefulSet
StatefulSet 是用来管理有状态应用的工作负载 API 对象。

StatefulSet 用来管理 Deployment 和扩展一组 Pod，并且能为这些 Pod 提供序号和唯一性保证。

和 Deployment 相同的是，StatefulSet 管理了基于相同容器定义的一组 Pod。但和 Deployment 不同的是，StatefulSet 为它们的每个 Pod 维护了一个固定的 ID。这些 Pod 是基于相同的声明来创建的，但是不能相互替换：无论怎么调度，每个 Pod 都有一个永久不变的 ID。

StatefulSet 和其他控制器使用相同的工作模式。你在 StatefulSet 对象 中定义你期望的状态，然后 StatefulSet 的 控制器 就会通过各种更新来达到那种你想要的状态。

StatefulSets 对于需要满足以下一个或多个需求的应用程序很有价值：

* 稳定的、唯一的网络标识符。
* 稳定的、持久的存储。
* 有序的、优雅的部署和缩放。
* 有序的、自动的滚动更新。 

在上面，稳定意味着 Pod 调度或重调度的整个过程是有持久性的。如果应用程序不需要任何稳定的标识符或有序的部署、删除或伸缩，则应该使用由一组无状态的副本控制器提供的工作负载来部署应用程序，比如 Deployment 或者 ReplicaSet 可能更适用于您的无状态应用部署需要。

**使用限制**

* 给定 Pod 的存储必须由 PersistentVolume 驱动 基于所请求的 storage class 来提供，或者由管理员预先提供。
* 删除或者收缩 StatefulSet 并不会删除它关联的存储卷。这样做是为了保证数据安全，它通常比自动清除 StatefulSet 所有相关的资源更有价值。
* StatefulSet 当前需要无头服务 来负责 Pod 的网络标识。您需要负责创建此服务。
* 当删除 StatefulSets 时，StatefulSet 不提供任何终止 Pod 的保证。为了实现 StatefulSet 中的 Pod 可以有序和优雅的终止，可以在删除之前将 StatefulSet 缩放为 0。
* 在默认 Pod 管理策略(OrderedReady) 时使用 滚动更新，可能进入需要 人工干预 才能修复的损坏状态。

# pod的标识符

StatefulSet Pod 具有唯一的标识，该标识包括顺序标识、稳定的网络标识和稳定的存储。该标识和 Pod 是绑定的，不管它被调度在哪个节点上。注意的是StatefulSet 需要通过无头服务才能解析到pod ip

有序索引
对于具有 N 个副本的 StatefulSet，StatefulSet 中的每个 Pod 将被分配一个整数序号，从 0 到 N-1，该序号在 StatefulSet 上是唯一的。

稳定的网络 ID 
StatefulSet 中的每个 Pod 根据 StatefulSet 的名称和 Pod 的序号派生出它的主机名。 组合主机名的格式为$(StatefulSet 名称)-$(序号)。上例将会创建三个名称分别为 web-0、web-1、web-2 的 Pod。 StatefulSet 可以使用 headless 服务 控制它的 Pod 的网络域。管理域的这个服务的格式为： $(服务名称).$(命名空间).svc.cluster.local，其中 cluster.local 是集群域。 一旦每个 Pod 创建成功，就会得到一个匹配的 DNS 子域，格式为： $(pod 名称).$(所属服务的 DNS 域名)，其中所属服务由 StatefulSet 的 serviceName 域来设定。

下面给出一些选择集群域、服务名、StatefulSet 名、及其怎样影响 StatefulSet 的 Pod 上的 DNS 名称的示例  

|  集群域名   | 服务(名字空间/名字)  | StatefulSet(名字空间/名字) |StatefulSet 域名|Pod DNS|Pod 主机名|
|  ----  | ----  | ----  | ----  |----  |----  |
| cluster.local  | default/nginx | default/web |nginx.default.svc.cluster.local |web-{0..N-1}.nginx.default.svc.cluster.local  |web-{0..N-1}|
| cluster.local  | foo/nginx |foo/web |nginx.foo.svc.cluster.local |web-{0..N-1}.nginx.foo.svc.cluster.local  |web-{0..N-1}|
| kube.local  | foo/nginx |foo/web |nginx.foo.svc.kube.local |web-{0..N-1}.nginx.foo.svc.kube.local|web-{0..N-1}|
```
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: webs
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
```
下面我们在其他容器中解析一下pod名称看一下是否能解析到pod ip

![upload-image](/assets/images/blog/StatefulSet/1.png) 

我们在centos容器中解析对应的pod名称看看,可以发现解析每个pod名称都能成功到pod ip，pod标识符也正是StatefulSet 独有的特性。

![upload-image](/assets/images/blog/StatefulSet/2.png) 

# 稳定的存储
Kubernetes 为每个 VolumeClaimTemplate 创建一个 PersistentVolumes。 在上面的 nginx 示例中，每个 Pod 将会得到基于 StorageClass  cbs  提供的 10 Gib 的 PersistentVolume。如果没有声明 StorageClass，就会使用默认的 StorageClass。 当一个 Pod 被调度（重新调度）到节点上时，它的 volumeMounts 会挂载与其 PersistentVolumeClaims 相关联的 PersistentVolume。 请注意，当 Pod 或者 StatefulSet 被删除时，与 PersistentVolumeClaims 相关联的 PersistentVolume 并不会被删除。要删除它必须通过手动方式来完成。

下面我们来测试一下将pod都删除看看，对应的pvc是否会删除

![upload-image](/assets/images/blog/StatefulSet/3.png) 

![upload-image](/assets/images/blog/StatefulSet/4.png) 

删除了所有pod，对用挂载的pvc卷是不会删除的。

# Pod 名称标签 
当 StatefulSet 控制器 创建 Pod 时，它会添加一个标签 statefulset.kubernetes.io/pod-name，该标签设置为 Pod 名称。这个标签允许您给 StatefulSet 中的特定 Pod 绑定一个 Service。
```
[root@VM_1_4_centos ~]# kubectl get pod --show-labels | grep webss
webss-0                                   2/2     Running   0          76m   app=nginx,controller-revision-hash=webss-6d657db877,k8s-app=webss,qcloud-app=webss,security.istio.io/tlsMode=istio,service.istio.io/canonical-name=nginx,service.istio.io/canonical-revision=latest,statefulset.kubernetes.io/pod-name=webss-0
webss-1                                   2/2     Running   0          75m   app=nginx,controller-revision-hash=webss-6d657db877,k8s-app=webss,qcloud-app=webss,security.istio.io/tlsMode=istio,service.istio.io/canonical-name=nginx,service.istio.io/canonical-revision=latest,statefulset.kubernetes.io/pod-name=webss-1
webss-2                                   2/2     Running   0          74m   app=nginx,controller-revision-hash=webss-6d657db877,k8s-app=webss,qcloud-app=webss,security.istio.io/tlsMode=istio,service.istio.io/canonical-name=nginx,service.istio.io/canonical-revision=latest,statefulset.kubernetes.io/pod-name=webss-2
```
```
[root@VM_1_4_centos ~]# kubectl get svc  webss-0 -o yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: "2020-10-25T03:06:35Z"
  labels:
    app: nginx
  name: webss-0
  namespace: default
  resourceVersion: "14187854412"
  selfLink: /api/v1/namespaces/default/services/webss-0
  uid: 16f50d64-533c-4c55-acb6-d7512d86cc58
spec:
  clusterIP: 172.16.255.138
  ports:
  - name: web
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    statefulset.kubernetes.io/pod-name: webss-0
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```
这边可以通过这个svc单独访问到webss-0

# StatefulSet的创建和扩缩容
* 对于包含 N 个 副本的 StatefulSet，当部署 Pod 时，它们是依次创建的，顺序为 0..N-1。
* 当删除 Pod 时，它们是逆序终止的，顺序为 N-1..0。
* 在将缩放操作应用到 Pod 之前，它前面的所有 Pod 必须是 Running 和 Ready 状态。
* 在 Pod 终止之前，所有的继任者必须完全关闭。

StatefulSet 不应将 pod.Spec.TerminationGracePeriodSeconds 设置为 0。 这种做法是不安全的，要强烈阻止。更多的解释请参考 强制删除 StatefulSet Pod。

![upload-image](/assets/images/blog/StatefulSet/5.png) 

在上面的 nginx 示例被创建后，会按照 webss-0、webss-1、webss-2 的顺序部署三个 Pod。 在 web-0 进入 Running 和 Ready 状态前不会部署 webss-1。在 webss-1 进入 Running 和 Ready 状态前不会部署 webss-2。 如果 web-1 已经处于 Running 和 Ready 状态，而 webss-2 尚未部署，在此期间发生了 web-0 运行失败，那么 webss-2 将不会被部署，要等到 webss-0 部署完成并进入 Running 和 Ready 状态后，才会部署 web-2。

如果用户想将示例中的 StatefulSet 收缩为 replicas=0，首先被终止的是 webss-2。在 webss-2 没有被完全停止和删除前，webss-1 不会被终止。当 webss-2 已被终止和删除、webss-1 尚未被终止，如果在此期间发生 webss-0 运行失败，那么就不会终止 webss-1，必须等到 webss-0 进入 Running 和 Ready 状态后才会终止 webss-1。

我们可以先删除pod，然后创建pod，看下对应的event日志
```
[root@VM_1_4_centos ~]# kubectl describe sts webss
Name:               webss
Namespace:          default
CreationTimestamp:  Sun, 25 Oct 2020 09:39:47 +0800
Selector:           app=nginx,k8s-app=webss,qcloud-app=webss
Labels:             app=nginx
                    k8s-app=webss
                    qcloud-app=webss
Annotations:        <none>
Replicas:           3 desired | 3 total
Update Strategy:    RollingUpdate
...............
Events:
  Type    Reason            Age                  From                    Message
  ----    ------            ----                 ----                    -------
  Normal  SuccessfulDelete  118s (x2 over 151m)  statefulset-controller  delete Pod webss-2 in StatefulSet webss successful
  Normal  SuccessfulDelete  111s (x2 over 151m)  statefulset-controller  delete Pod webss-1 in StatefulSet webss successful
  Normal  SuccessfulDelete  97s (x2 over 151m)   statefulset-controller  delete Pod webss-0 in StatefulSet webss successful
  Normal  SuccessfulCreate  70s (x3 over 3h49m)  statefulset-controller  create Pod webss-0 in StatefulSet webss successful
  Normal  SuccessfulCreate  47s (x3 over 3h49m)  statefulset-controller  create Pod webss-1 in StatefulSet webss successful
  Normal  SuccessfulCreate  24s (x3 over 3h48m)  statefulset-controller  create Pod webss-2 in StatefulSet webss successful
```
可以发现pod的启动是按照顺序创建和删除的

**podManagementPolicy管理pod**

那么StatefulSet 是如何保证对应的pod按照顺序启动的呢，必须需要等前面一个pod启动才能启动后面的pod，那么我们可以去除这个依赖来启动pod吗？让pod并行启动，这边当然是可以的。StatefulSet可以通过podManagementPolicy这个参数来配置pod的启动顺序。

podManagementPolicy: OrderedReady这个是默认的配置，就是按照一定的顺序先后启动。

podManagementPolicy可以将值设置为Parallel，这个值就是StatefulSet 控制器并行的启动或终止所有的 Pod， 启动或者终止其他 Pod 前，无需等待 Pod 进入 Running 和 ready 或者完全停止状态。
```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"StatefulSet","metadata":{"annotations":{},"name":"web","namespace":"default"},"spec":{"podManagementPolicy":"Parallel","replicas":3,"selector":{"matchLabels":{"app":"nginx"}},"serviceName":"nginx","template":{"metadata":{"labels":{"app":"nginx"}},"spec":{"containers":[{"image":"k8s.gcr.io/nginx-slim:0.8","name":"nginx","ports":[{"containerPort":80,"name":"web"}]}],"terminationGracePeriodSeconds":10}}}}
  creationTimestamp: "2020-10-25T05:42:38Z"
  generation: 2
  name: web
  namespace: default
  resourceVersion: "8286286"
  selfLink: /apis/apps/v1/namespaces/default/statefulsets/web
  uid: 4e50f5b0-d23d-4fca-978e-f3547c047dd3
spec:
  podManagementPolicy: Parallel
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  serviceName: nginx
....................
```
![upload-image](/assets/images/blog/StatefulSet/6.png) 

可以从上面event事件看出，我们将podManagementPolicy设置为Parallel，pod是并行同时启动的

# StatefulSet的更新
在 Kubernetes 1.7 及以后的版本中，StatefulSet 的.spec.updateStrategy字段让您可以配置和禁用掉自动滚动更新 Pod 的容器、标签、资源请求或限制、以及注解。默认的配置是滚动更新

## RollingUpdate更新
RollingUpdate更新策略对 StatefulSet 中的 Pod 执行自动的滚动更新。在没有声明.spec.updateStrategy时，RollingUpdate是默认配置。 当 StatefulSet 的.spec.updateStrategy.type被设置为RollingUpdate时，StatefulSet 控制器会删除和重建 StatefulSet 中的每个 Pod。 它将按照与 Pod 终止相同的顺序（从最大序号到最小序号）进行，每次更新一个 Pod。它会等到被更新的 Pod 进入 Running 和 Ready 状态，然后再更新其前身。
```
      terminationGracePeriodSeconds: 30
  updateStrategy:
    rollingUpdate:
      partition: 0
    type: RollingUpdate
```
下面我们修改下镜像，看看滚动更新是否和上面描述一致，我们修改镜像版本为1.17版本，从事件看，更新顺序是先更新最大号序号，再更新最小序号的
```
   nginx:
    Image:        nginx:1.17
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Volume Claims:    <none>
Events:
  Type    Reason            Age                  From                    Message
  ----    ------            ----                 ----                    -------
  Normal  SuccessfulDelete  93s                  statefulset-controller  delete Pod web-2 in StatefulSet web successful
  Normal  SuccessfulCreate  85s (x2 over 3m28s)  statefulset-controller  create Pod web-2 in StatefulSet web successful
  Normal  SuccessfulDelete  46s                  statefulset-controller  delete Pod web-1 in StatefulSet web successful
  Normal  SuccessfulCreate  36s (x2 over 4m20s)  statefulset-controller  create Pod web-1 in StatefulSet web successful
  Normal  SuccessfulDelete  12s                  statefulset-controller  delete Pod web-0 in StatefulSet web successful
  Normal  SuccessfulCreate  5s (x2 over 4m59s)   statefulset-controller  create Pod web-0 in StatefulSet web successful
```
## OnDelete 更新
OnDelete 更新策略实现了 1.6 及以前版本的历史遗留行为。当 StatefulSet 的 .spec.updateStrategy.type 设置为 OnDelete 时，它的控制器将不会自动更新 StatefulSet 中的 Pod。用户必须手动删除 Pod 以便让控制器创建新的 Pod，以此来对 StatefulSet 的 .spec.template 的变动作出反应。
```
      containers:
      - image: nginx:1.17
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
          name: web
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 10
  updateStrategy:
    type: OnDelete
```
下面我们把修改镜像成latest，看下对应的pod会不会更新
```
spec:
  podManagementPolicy: OrderedReady
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  serviceName: nginx
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        imagePullPolicy: Always
        name: nginx

[root@VM-4-3-centos ~]# kubectl delete pod web-1
pod "web-1" deleted
[root@VM-4-3-centos ~]# kubectl get pod 
NAME    READY   STATUS              RESTARTS   AGE
web-0   1/1     Running             0          6m
web-1   0/1     ContainerCreating   0          2s
web-2   1/1     Running             0          7m20s
[root@VM-4-3-centos ~]# kubectl describe pod web-1
Name:           web-1
Namespace:      default
.....................
Events:
  Type    Reason     Age   From                     Message
  ----    ------     ----  ----                     -------
  Normal  Scheduled  11s   default-scheduler        Successfully assigned default/web-1 to vm-4-11-centos
  Normal  Pulling    10s   kubelet, vm-4-11-centos  Pulling image "nginx:latest"
  Normal  Pulled     0s    kubelet, vm-4-11-centos  Successfully pulled image "nginx:latest"
  Normal  Created    0s    kubelet, vm-4-11-centos  Created container nginx
  Normal  Started    0s    kubelet, vm-4-11-centos  Started container nginx
```
可以发现我们修改yaml后，pod并没有更新，只有手动删除某个pod后，pod才会进行更新

## 分区更新
通过声明.spec.updateStrategy.rollingUpdate.partition的方式，RollingUpdate更新策略可以实现分区。如果声明了一个分区，当 StatefulSet 的.spec.template被更新时，所有序号大于等于该分区序号的 Pod 都会被更新。所有序号小于该分区序号的 Pod 都不会被更新，并且，即使他们被删除也会依据之前的版本进行重建。如果 StatefulSet 的.spec.updateStrategy.rollingUpdate.partition大于它的.spec.replicas，对它的.spec.template的更新将不会传递到它的 Pod。 在大多数情况下，您不需要使用分区，但如果您希望进行阶段更新、执行金丝雀或执行分阶段展开，则这些分区会非常有用

这边通常spec.updateStrategy.rollingUpdate.partition一般需要小于replicas的数值，这样才会生效，下面我们来测试一下分区更新
```
spec:
  podManagementPolicy: OrderedReady
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  serviceName: nginx
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
          name: web
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 10
  updateStrategy:
    rollingUpdate:
      partition: 2
    type: RollingUpdate
[root@VM-4-3-centos ~]# kubectl describe sts web
Name:               web
Namespace:          default
CreationTimestamp:  Sun, 25 Oct 2020 14:09:02 +0800
Selector:           app=nginx
Labels:             <none>
Annotations:        kubectl.kubernetes.io/last-applied-configuration:
                      {"apiVersion":"apps/v1","kind":"StatefulSet","metadata":{"annotations":{},"name":"web","namespace":"default"},"spec":{"podManagementPolicy...
Replicas:           3 desired | 3 total
Update Strategy:    RollingUpdate
  Partition:        824636860812
Pods Status:        3 Running / 0 Waiting / 0 Succeeded / 0 Failed
........
Events:
  Type    Reason            Age                  From                    Message
  ----    ------            ----                 ----                    -------
  Normal  SuccessfulCreate  5m8s                 statefulset-controller  create Pod web-0 in StatefulSet web successful
  Normal  SuccessfulCreate  4m32s                statefulset-controller  create Pod web-1 in StatefulSet web successful
  Normal  SuccessfulDelete  26s                  statefulset-controller  delete Pod web-2 in StatefulSet web successful
  Normal  SuccessfulCreate  19s (x2 over 4m12s)  statefulset-controller  create Pod web-2 in StatefulSet web successful
[root@VM-4-3-centos ~]# kubectl get pod 
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          5m12s
web-1   1/1     Running   0          4m36s
web-2   1/1     Running   0          23s
```
可以发现，只有大于等于分区需要才会被更新，这里也只有web-2被更新

## 强制回滚
在默认 Pod 管理策略(OrderedReady) 时使用 滚动更新 ，可能进入需要人工干预才能修复的损坏状态。

如果更新后 Pod 模板配置进入无法运行或就绪的状态（例如，由于错误的二进制文件或应用程序级配置错误），StatefulSet 将停止回滚并等待。

在这种状态下，仅将 Pod 模板还原为正确的配置是不够的。由于 已知问题，StatefulSet 将继续等待损坏状态的 Pod 准备就绪（永远不会发生），然后再尝试将其恢复为正常工作配置。

恢复模板后，还必须删除 StatefulSet 尝试使用错误的配置来运行的 Pod。这样， StatefulSet 才会开始使用被还原的模板来重新创建 Pod

我们日常在更新镜像的时候，发现服务启动失败了，然后将镜像回滚成之前的版本，这样仅仅是不够的，因为StatefulSet 还会一直等待新更新的pod状态ready，但是这个永远不会发生，所以为了恢复正常，我们需要删除更新启动失败的pod。

下面我们来测试下，我们将pod修改成k8s.gcr.io/nginx-slim:0.8，节点上无法拉取这个镜像的，所以web-2这个pod会一直启动失败。
```
[root@VM-4-3-centos ~]# kubectl get pod 
NAME    READY   STATUS             RESTARTS   AGE
web-0   1/1     Running            0          13m
web-1   1/1     Running            0          12m
web-2   0/1     ImagePullBackOff   0          44s
下面我们将镜像改成之前的nginx:1.17，看看会不会恢复

spec:
  podManagementPolicy: OrderedReady
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  serviceName: nginx
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.17
        imagePullPolicy: Always
[root@VM-4-3-centos ~]# kubectl get pod 
NAME    READY   STATUS         RESTARTS   AGE
web-0   1/1     Running        0          15m
web-1   1/1     Running        0          14m
web-2   0/1     ErrImagePull   0          2m52s
[root@VM-4-3-centos ~]# kubectl delete pod web-2 
pod "web-2" deleted
[root@VM-4-3-centos ~]# kubectl get pod 
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          14s
web-1   1/1     Running   0          33s
web-2   1/1     Running   0          45s
```
从上面的结果可以看出，我们不删除web-2这个更新异常的pod，所以的pod都不会更新的，只有删除了web-2这个更新失败的pod，sts才会进行正常更新。

# 参考文档
<https://kubernetes.io/zh/docs/concepts/workloads/controllers/statefulset/#deployment-and-scaling-guarantees>

