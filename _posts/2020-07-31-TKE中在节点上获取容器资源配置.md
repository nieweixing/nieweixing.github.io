---
title: TKE中在节点上获取容器资源配置
author: VashonNie
date: 2020-07-31 14:10:00 +0800
updated: 2020-07-31 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE]
math: true
---

本章讲述了如何获取容器的资源配置

# 容器的实现原理

从本质上，容器其实就是一种沙盒技术。就好像把应用隔离在一个盒子内，使其运行。因为有了盒子边界的存在，应用于应用之间不会相互干扰。并且像集装箱一样，拿来就走，随处运行。其实这就是 PaaS 的理想状态。

实现容器的核心，就是要生成限制应用运行时的边界。我们知道，编译后的可执行代码加上数据，叫做程序。而把程序运行起来后，就变成了进程，也就是所谓的应用。如果能在应用启动时，给其加上一个边界，这样不就能实现期待的沙盒吗？

在 Linux 中，实现容器的边界，主要有两种技术 Cgroups 和 Namespace. Cgroups 用于对运行的容器进行资源的限制，Namespace 则会将容器隔离起来，实现边界。

容器的限制：Cgroups

通过 Namespace 技术，我们实现了容器和容器间，容器与宿主机之间的隔离。但这还不够，想象这样一种场景，宿主机上运行着两个容器。虽然在容器间相互隔离，但以宿主机的视角来看的话，其实两个容器就是两个特殊的进程，而进程之间自然存在着竞争关系，自然就可以将系统的资源吃光。当然，我们不能允许这么做的。

这里可以查看cpu，内存，我们拿查看内存举例，/proc/meminfo是了解Linux系统内存使用状况的主要接口，那么我们如何查看容器的这个接口文件获取容器的内存数据来进行统计。

首先获取容器的pid

```
# docker inspect -f {{.State.Pid}} b930cd9c4ba9
6298
```

找到容器的cgroup文件，并获取cgroup文件

```
# cd /proc/6298
[root@VM_1_4_centos 6298]# cat cgroup
12:blkio:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
11:cpuset:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
10:cpu,cpuacct:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
9:devices:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
8:hugetlb:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
7:freezer:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
6:net_cls:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
5:rdma:/
4:perf_event:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
3:memory:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
2:pids:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
1:name=systemd:/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0/b930cd9c4ba969a1366da5c79fbce8a0a6690649d0238d9f5fc34f8269fc43b5
```

去sys目录下获取/proc/meminfo

```
cd /sys/fs/cgroup/memory/kubepods/burstable/pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd
```

查看对应的文件获取容器的内存信息

```
[root@VM_1_4_centos pod17b4aaff-dd14-4ba1-a735-5e6a7725fbd0]# cat memory.meminfo
MemTotal:         102400 kB
MemFree:           78776 kB
Buffers:               0 kB
Cached:                0 kB
SwapCached:            0 kB
Active:                0 kB
Inactive:              0 kB
Active(anon):          0 kB
Inactive(anon):        0 kB
Active(file):          0 kB
Inactive(file):        0 kB
Unevictable:           0 kB
Mlocked:               0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
Dirty:                 0 kB
Writeback:             0 kB
AnonPages:             0 kB
Mapped:                0 kB
Shmem:                 0 kB
Slab:                  0 kB
SReclaimable:          0 kB
SUnreclaim:            0 kB
KernelStack:           0 kB
PageTables:            0 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:           0 kB
Committed_AS:          0 kB
VmallocTotal:          0 kB
VmallocUsed:           0 kB
VmallocChunk:          0 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
```

