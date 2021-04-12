---
title: crictl调试Kubernetes节点
author: VashonNie
date: 2020-10-13 14:10:00 +0800
updated: 2020-10-13 14:10:00 +0800
categories: [Kubernetes,crictl]
tags: [Kubernetes]
math: true
---

本文介绍了TKE中使用containerd模式的集群常用的crictl命令

# 开始之前

crictl需要一个具有CRI运行时的Linux操作系统，直接在TKE中创建containerd模式的集群既可。

# 安装crictl

你可以从critools发布页面下载一个压缩的存档crictl，用于几种不同的体系构架。下载与Kubernetes版本对应的版本。解压并将其移动到系统路径上的一个位置，例如/usr/local/bin/。

# 一般用法
crictl命令有几个子命令和运行时选项。有关详细信息，请使用crictl help或crictl <subcommand> help。

crictl默认连接到 unix:///var/run/dockershim.sock。对于其它运行时，你可以通过多种方式设置端点:

* 设置 --runtime-endpoint 和--image-endpoint选项。
* 设置 CONTAINER_RUNTIME_ENDPOINT 和IMAGE_SERVICE_ENDPOINT环境变量。
* 在配置文件 --config=/etc/crictl.yaml设置端点。

还可以在连接到服务器时指定超时值，并启用或禁用调试，方法是在配置文件中指定 timeout 和debug 值，或者使用--timeout和--debug命令行选项。
要查看或编辑当前配置，请查看或编辑/etc/crictl.yaml的内容

```
cat /etc/crictl.yamlruntime-endpoint: unix:///var/run/dockershim.sockimage-endpoint: unix:///var/run/dockershim.socktimeout: 10debug: true
```

# crictl命令示例
下面的示例显示了crictl命令和示例输出。

**警告**：如果你使用crictl在运行的Kubernetes集群上创建pod沙箱或容器，Kubelet最终将删除它们。crictl不是一个通用的工作流工具，而是一个对调试有用的工具。

# 获取pod列表

获取所有pod列表：

```
# crictl pods
POD ID              CREATED              STATE               NAME                         NAMESPACE           ATTEMPT
926f1b5a1d33a       About a minute ago   Ready               sh-84d7dcf559-4r2gq          default             0
4dccb216c4adb       About a minute ago   Ready               nginx-65899c769f-wv2gp       default             0
a86316e96fa89       17 hours ago         Ready               kube-proxy-gblk4             kube-system         0
919630b8f81f1       17 hours ago         Ready               nvidia-device-plugin-zgbbv   kube-system         0
```

根据名称获取pod列表：

```
crictl pods --name nginx-65899c769f-wv2gp

POD ID              CREATED             STATE               NAME                     NAMESPACE           ATTEMPT
4dccb216c4adb       2 minutes ago       Ready               nginx-65899c769f-wv2gp   default             0

根据标签获取pod列表：
crictl pods --label run=nginx

POD ID              CREATED             STATE               NAME                     NAMESPACE           ATTEMPT
4dccb216c4adb       2 minutes ago       Ready               nginx-65899c769f-wv2gp   default             0
```

# 获取镜像列表

获取所有镜像列表：

```
crictl images

IMAGE                                     TAG                 IMAGE ID            SIZE
busybox                                   latest              8c811b4aec35f       1.15MB
k8s-gcrio.azureedge.net/hyperkube-amd64   v1.10.3             e179bbfe5d238       665MB
k8s-gcrio.azureedge.net/pause-amd64       3.1                 da86e6ba6ca19       742kB
nginx                                     latest              cd5239a0906a6       109MB
输出类似如下：
IMAGE                                     TAG                 IMAGE ID            SIZEbusybox                                   latest              8c811b4aec35f       1.15MBk8s-gcrio.azureedge.net/hyperkube-amd64   v1.10.3             e179bbfe5d238       665MBk8s-gcrio.azureedge.net/pause-amd64       3.1                 da86e6ba6ca19       742kBnginx                                     latest              cd5239a0906a6       109MB
```

根据仓库获取镜像列表：

```
crictl images nginx

IMAGE               TAG                 IMAGE ID            SIZE
nginx               latest              cd5239a0906a6       109MB
输出类似如下：
IMAGE               TAG                 IMAGE ID            SIZEnginx               latest              cd5239a0906a6       109MB
```

只列出镜像ID：

```
crictl images -q

sha256:8c811b4aec35f259572d0f79207bc0678df4c736eeec50bc9fec37ed936a472a
sha256:e179bbfe5d238de6069f3b03fccbecc3fb4f2019af741bfff1233c4d7b2970c5
sha256:da86e6ba6ca197bf6bc5e9d900febd906b133eaa4750e6bed647b0fbe50ed43e
sha256:cd5239a0906a6ccf0562354852fae04bc5b52d72a2aff9a871ddb6bd57553569
输出类似如下：
sha256:8c811b4aec35f259572d0f79207bc0678df4c736eeec50bc9fec37ed936a472asha256:e179bbfe5d238de6069f3b03fccbecc3fb4f2019af741bfff1233c4d7b2970c5sha256:da86e6ba6ca197bf6bc5e9d900febd906b133eaa4750e6bed647b0fbe50ed43esha256:cd5239a0906a6ccf0562354852fae04bc5b52d72a2aff9a871ddb6bd57553569
```

# 获取容器列表

获取所有容器列表：

```
crictl ps -a

CONTAINER ID        IMAGE                                                                                                             CREATED             STATE               NAME                       ATTEMPT
1f73f2d81bf98       busybox@sha256:141c253bc4c3fd0a201d32dc1f493bcf3fff003b6df416dea4f41046e0f37d47                                   7 minutes ago       Running             sh                         1
9c5951df22c78       busybox@sha256:141c253bc4c3fd0a201d32dc1f493bcf3fff003b6df416dea4f41046e0f37d47                                   8 minutes ago       Exited              sh                         0
87d3992f84f74       nginx@sha256:d0a8828cccb73397acb0073bf34f4d7d8aa315263f1e7806bf8c55d8ac139d5f                                     8 minutes ago       Running             nginx                      0
1941fb4da154f       k8s-gcrio.azureedge.net/hyperkube-amd64@sha256:00d814b1f7763f4ab5be80c58e98140dfc69df107f253d7fdd714b30a714260a   18 hours ago        Running   
```

在运行的容器中执行命令

```
crictl exec -i -t 1f73f2d81bf98 ls

bin   dev   etc   home  proc  root  sys   tmp   usr   var
输出类似如下：
bin   dev   etc   home  proc  root  sys   tmp   usr   var
```

# 输出容器日志

获取所有容器日志：

```
crictl logs 87d3992f84f74
输出类似如下：
10.240.0.96 - - [06/Jun/2018:02:45:49 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.47.0" "-"10.240.0.96 - - [06/Jun/2018:02:45:50 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.47.0" "-"10.240.0.96 - - [06/Jun/2018:02:45:51 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.47.0" "-"
```

只获取最近的N行日志：

```
crictl logs --tail=1 87d3992f84f74
输出类似如下：
10.240.0.96 - - [06/Jun/2018:02:45:51 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.47.0" "-"
```

# 运行pod沙箱

使用crictl运行pod沙箱对于调试容器运行时非常有用。在运行的Kubernetes集群上，沙箱最终将被Kubelet停止和删除。

创建一个如下内容的JSON文件：

```
  {      "metadata": {          "name": "nginx-sandbox",          "namespace": "default",          "attempt": 1,          "uid": "hdishd83djaidwnduwk28bcsb"      },      "logDirectory": "/tmp",      "linux": {      }  }
```

使用crictl runp命令应用JSON并运行沙箱。

```
 crictl runp pod-config.json
```

返回了沙箱ID。

# 创建容器

使用crictl创建容器对于调试容器运行时非常有用。在运行的Kubernetes集群上，沙箱最终将被Kubelet停止和删除。

拉取沙箱镜像：

```
  crictl pull busybox  Image is up to date for busybox@sha256:141c253bc4c3fd0a201d32dc1f493bcf3fff003b6df416dea4f41046e0f37d47
```

为pod和容器创建配置:

pod配置:

```
  {      "metadata": {          "name": "nginx-sandbox",          "namespace": "default",          "attempt": 1,          "uid": "hdishd83djaidwnduwk28bcsb"      },      "log_directory": "/tmp",      "linux": {      }  }
容器配置：
  {    "metadata": {        "name": "busybox"    },    "image":{        "image": "busybox"    },    "command": [        "top"    ],    "log_path":"busybox/0.log",    "linux": {    }  }
```

传递前面创建的pod、容器配置文件和pod配置文件的ID来创建容器。随即返回了容器的ID。

```
 crictl create f84dd361f8dc51518ed291fbadd6db537b0496536c1d2d6c05ff943ce8c9a54f container-config.json pod-config.json
```

列出所有容器，并验证新创建的容器是否将其状态设置为Created。

```
 crictl ps -a
输出类似如下：
  CONTAINER ID        IMAGE               CREATED             STATE               NAME                ATTEMPT  3e025dd50a72d       busybox             32 seconds ago      Created             busybox             0
```

启动容器

要启动容器，请将其ID传递给 crictl start：

```
crictl start 3e025dd50a72d956c4f14881fbb5b1080c9275674e95fb67f965f6478a957d60
输出类似如下：
3e025dd50a72d956c4f14881fbb5b1080c9275674e95fb67f965f6478a957d60
```

检查容器是否将其状态设置为Running。

```
crictl ps

CONTAINER ID        IMAGE               CREATED              STATE               NAME                ATTEMPT
3e025dd50a72d       busybox             About a minute ago   Running             busybox             0
```

