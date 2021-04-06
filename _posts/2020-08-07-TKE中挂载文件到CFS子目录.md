---
title: TKE中挂载文件到CFS子目录
author: VashonNie
date: 2020-08-07 14:10:00 +0800
updated: 2020-08-07 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE,NFS]
math: true
---

本次我们来讲如何在TKE容器中多个pod挂载文件到文件服务器CFS不同的子目录


# 首先创建好CFS文件服务器

登录CFS控制台，创建一个文件系统

![upload-image](/assets/images/blog/cfs/1.png) 

# 创建CFS子目录

如何创建CFS的子目录呢，这里我们找一个可以访问cfs内网ip的服务器，先将cfs的根目录下挂载到/root/cfs，然后在/root/nfs下创建2个子目录tke和tke-1，注意创建完目录后记得解挂/root/nfs这个目录，对应的子目录在文件系统中已经创建好了。

```
[root@VM-1-5-centos ~]# mkdir nfs
[root@VM-1-5-centos nfs]# sudo mount -t nfs -o vers=4.0 1.1.1.1:/ /root/nfs
[root@VM-1-5-centos nfs]# mkdir tke
[root@VM-1-5-centos nfs]# mkdir tke-1
[root@VM-1-5-centos nfs]# cd
[root@VM-1-5-centos ~]# umount /root/nfs
```

corresponding condition of pod readiness gate "platform.tkex/InPlace-Update-Ready" does not exist., the status of pod readiness gate "cloud.tencent.com/load-balancer-backendgroup-ready" is not "True", but False

# TKE中创建StorageClass

登录tke，在集群中新建sc

![upload-image](/assets/images/blog/cfs/2.png) 

# 创建PV

这里我们分别为tke和tke-1创建一个pv

![upload-image](/assets/images/blog/cfs/3.png) 

![upload-image](/assets/images/blog/cfs/4.png) 

# 创建PVC

我们创建2个pvc关联上一步创建的pv

![upload-image](/assets/images/blog/cfs/5.png) 

![upload-image](/assets/images/blog/cfs/6.png) 

# 挂载PVC

我们创建2个测试的nginx镜像pod来挂载2个pvc

![upload-image](/assets/images/blog/cfs/7.png) 

![upload-image](/assets/images/blog/cfs/8.png) 

# 验证

查看pod启动成功，挂载成功，在CFS中查看也能看到对应的2条挂载信息

![upload-image](/assets/images/blog/cfs/9.png) 

![upload-image](/assets/images/blog/cfs/10.png) 
