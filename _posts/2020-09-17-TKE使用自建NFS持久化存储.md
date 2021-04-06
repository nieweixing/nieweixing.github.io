---
title: TKE使用自建NFS持久化存储
author: VashonNie
date: 2020-09-17 14:10:00 +0800
updated: 2020-09-17 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE,NFS]
math: true
---

使用TKE的过程中，我们需要把pod一些文件持久化存储到外部，这边我们会用到nfs存储，其实在腾讯云上有CFS服务，可以用CFS作为文件存储服务器，TKE也支持将文件挂载到CFS上存储。但是如果你想自己管理nfs服务器，这边也可以通过自建nfs服务器来作为tke集群中pod存储。下面我们来说一下如何将pod的文件挂载到自建的nfs服务器来进行存储。


# 创建nfs服务器

首先我们先在腾讯云上申请一台cvm服务器，这边建议将对应的磁盘空间配置大点，并且cvm服务器的网络需要和tke集群处于一个vpc内，这样TKE集群可以通过内网直接访问nfs服务器进行挂载

## centos部署nfs服务端

```
# yum -y install nfs-utils rpcbind
# systemctl start rpcbind
# systemctl enable rpcbind
```

## ubuntu部署nfs服务端

```
# sudo apt-get install nfs-kernel-server
# sudo service nfs-kernel-server restart
# sudo systemctl enable nfs-kernel-server.service
```

# 配置nfs的挂载目录

下面我们以centos系统为例进行操作实例，我们在nfs服务器上创建好pod需要挂载的目录，并给对应的目录编辑共享配置文件设置好权限，然后重启nfs服务器。

```
# mkdir -p /data/volums
# vi /etc/exports
/data/volums *(async,insecure,no_root_squash,no_subtree_check,rw)
# systemctl restart rpcbind
```

/etc/exports配置文件参数及作用说明

* ro：只读
* rw：读写
* root_squash：当NFS客户端以root管理员访问时，映射为NFS服务器的匿名用户
* no_root_squash：当NFS客户端以root管理员访问时，映射为NFS服务器的root管理员
* all_squash：无论NFS客户端使用什么账户访问，均映射为NFS服务器的匿名用户
* sync：同时将数据写入到内存与硬盘中，保证不丢失数据
* async：优先将数据保存到内存，然后再写入硬盘；这样效率更高，但可能会丢失数据
* insecure：允许客户端从大于1024的tcp/ip端口连接服务器

```
[root@VM-1-2-centos volums]# showmount -e 10.168.1.2
Export list for 10.168.1.2:
/data/volums *
```

查看nfs服务器上的共享状态，出现上述的内容输出，这边说明/data/volums可以进行挂载了

# 节点安装nfs客户端工具

因为k8s的调度机制，这边如果不指定调度，会随机指定节点调度，所以这边建议所有节点都按照nfs的客户端，保证pod调度到节点上可以执行挂载操作。

## centos部署nfs客户端工具

```
yum -y install nfs-utils
```

## ubuntu部署nfs客户端工具

```
sudo apt install nfs-common
```

# 集群中部署nfs客户端nfs-client-provisioner

这边我们在TKE集群中通过部署nfs-client-provisioner客户端工具。

## 通过rbac给nfs-client-provisioner分配权限

```
kind: ServiceAccount
apiVersion: v1
metadata:
  name: nfs-client-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
```

## 创建nfs-client-provisioner

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: quay.io/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs
            - name: NFS_SERVER
              value: 10.168.1.2
            - name: NFS_PATH
              value: /data/volums
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.168.1.2
            path: /data/volums
```

## 创建nfs对应的StorageClass

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: fuseim.pri/ifs # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
4.4 创建nfs类型的pvc
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
  annotations:
    volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

# 创建pod挂载到自建nfs服务器

## 直接挂载到nfs盘的目录下

![upload-image](/assets/images/blog/nfs/1.png) 

```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2020-09-17T12:01:00Z"
  generation: 1
  labels:
    k8s-app: nginx-cfs-server
    qcloud-app: nginx-cfs-server
  name: nginx-cfs-server
  namespace: default
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: nginx-cfs-server
      qcloud-app: nginx-cfs-server
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: nginx-cfs-server
        qcloud-app: nginx-cfs-server
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx-cfs-server
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
        volumeMounts:
        - mountPath: /etc/nginx/conf.d
          name: vol
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: qcloudregistrykey
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - name: vol
        nfs:
          path: /data/volums/nginx
          server: 10.168.1.2
```

下面我们在容器内创建几个文件，看下在nfs服务器下/data/volums/nginx的目录是否也有，我们在容器内创建test1和test2

```
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# ls
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# echo "test1" > test1
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# echo "test2" > test2
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# ls
test1  test2
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# cat test1
test1
root@nginx-cfs-server-69fb8cb9f6-2hzc6:/etc/nginx/conf.d# cat test2
test2
```

去nfs的/data/volums/nginx目录验证下

```
[root@VM-1-2-centos nginx]# ll
total 8
-rw-r--r-- 1 root root 6 Sep 17 20:04 test1
-rw-r--r-- 1 root root 6 Sep 17 20:04 test2
[root@VM-1-2-centos nginx]# pwd
/data/volums/nginx
[root@VM-1-2-centos nginx]# cat test1
test1
[root@VM-1-2-centos nginx]# cat test2
test2
[root@VM-1-2-centos nginx]# pwd
/data/volums/nginx
```

对应的文件已成功挂载到nfs服务中

## 通过pvc挂载某个目录到nfs服务器

这边我们将上面创建的test-claim这个pvc挂载到容器内

![upload-image](/assets/images/blog/nfs/2.png) 

```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2020-09-17T11:53:11Z"
  generation: 1
  labels:
    k8s-app: nginx-nfs
    qcloud-app: nginx-nfs
  name: nginx-nfs
  namespace: default
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: nginx-nfs
      qcloud-app: nginx-nfs
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: nginx-nfs
        qcloud-app: nginx-nfs
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx-nfs
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
        volumeMounts:
        - mountPath: /etc/nginx/conf.d
          name: vol
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: qcloudregistrykey
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - name: vol
        persistentVolumeClaim:
          claimName: test-claim
```

下面我们做个简单的验证，在容器内创建文件，看下对应的pvc下会不会有文件生成

![upload-image](/assets/images/blog/nfs/3.png)

```
[root@VM-1-2-centos volums]# ll
total 8
-rw-r--r-- 1 root root    0 Sep  6 17:58 aa
-rw-r--r-- 1 root root    0 Sep  6 17:58 aab
drwxrwxrwx 2 root root 4096 Sep 17 20:47 default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92
drwxr-xr-x 2 root root 4096 Sep 17 20:04 nginx
[root@VM-1-2-centos volums]# cd default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92/
[root@VM-1-2-centos default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92]# ll
total 4
-rw-r--r-- 1 root root 11 Sep 17 20:47 hello
[root@VM-1-2-centos default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92]# cat hello 
hello word
[root@VM-1-2-centos default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92]# ls
hello
[root@VM-1-2-centos default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92]# cat hello 
hello word
```

容器内的test文件成功挂载到pvc卷的目录。

## 动态创建pvc挂载到nfs上

k8s中只有StatefulSet需要动态创建pvc来挂载每一个pod内生成的文件，下面我们创建一个StatefulSet来动态创建pvc挂载到容器上。

```
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: web
spec:
  replicas: 2
  volumeClaimTemplates:
  - metadata:
      name: test
      annotations:
        volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"
    spec:
      accessModes: [ "ReadWriteMany" ]
      resources:
        requests:
          storage: 1Gi
  template:
    metadata:
      labels:
        app: nginx1
    spec:
      serviceAccount: nfs-provisioner
      containers:
      - name: nginx1
        image: nginx
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - mountPath: "/etc/nginx/conf.d"
          name: test
```

执行上面的yaml创建2个pod，然后登录pod创建文件，这边我们验证下是否挂载成功

```
root@web-0:/# cd /etc/nginx/conf.d/
root@web-0:/etc/nginx/conf.d# echo "web0" > a.txt
root@web-0:/etc/nginx/conf.d# ls
a.txt
root@web-0:/etc/nginx/conf.d# cat a.txt 
web0


root@web-1:/# cd /etc/nginx/conf.d/
root@web-1:/etc/nginx/conf.d# ls 
root@web-1:/etc/nginx/conf.d# echo "web1" > 2.txt
root@web-1:/etc/nginx/conf.d# ls
2.txt
root@web-1:/etc/nginx/conf.d# cat 2.txt 
web1
root
```

我们登录到nfs服务器上查看下pod对应的pvc所在目录是否有文件生成

```
[root@VM-1-2-centos volums]# ll
total 16
-rw-r--r-- 1 root root    0 Sep  6 17:58 aa
-rw-r--r-- 1 root root    0 Sep  6 17:58 aab
drwxrwxrwx 2 root root 4096 Sep 17 20:47 default-test-claim-pvc-6927bda4-1e81-4187-af6f-611e07e45a92
drwxrwxrwx 2 root root 4096 Sep 17 20:59 default-test-web-0-pvc-e8e6637c-76a5-4256-b589-c29d31f19afe
drwxrwxrwx 2 root root 4096 Sep 17 21:01 default-test-web-1-pvc-3298add1-0626-4973-ae47-4cae5885f024
drwxr-xr-x 2 root root 4096 Sep 17 20:04 nginx
[root@VM-1-2-centos volums]# cd default-test-web-0-pvc-e8e6637c-76a5-4256-b589-c29d31f19afe
[root@VM-1-2-centos default-test-web-0-pvc-e8e6637c-76a5-4256-b589-c29d31f19afe]# ls
a.txt
[root@VM-1-2-centos default-test-web-0-pvc-e8e6637c-76a5-4256-b589-c29d31f19afe]# cat a.txt 
web0
[root@VM-1-2-centos default-test-web-0-pvc-e8e6637c-76a5-4256-b589-c29d31f19afe]# cd ..
[root@VM-1-2-centos volums]# cd default-test-web-1-pvc-3298add1-0626-4973-ae47-4cae5885f024
[root@VM-1-2-centos default-test-web-1-pvc-3298add1-0626-4973-ae47-4cae5885f024]# ls
2.txt
[root@VM-1-2-centos default-test-web-1-pvc-3298add1-0626-4973-ae47-4cae5885f024]# cat 2.txt 
web1
```

从上面查看，对应的文件已在服务器上挂载成功。


