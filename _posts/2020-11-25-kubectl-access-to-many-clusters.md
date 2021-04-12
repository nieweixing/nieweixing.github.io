---
title: Kubernetes之多集群的访问
author: VashonNie
date: 2020-11-25 14:10:00 +0800
updated: 2020-11-25 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,kubeconfig]
math: true
---

日常使用k8s的过程中，我们可能存在多个集群需要管理，那么我们用kubectl来进行集群的切换个访问呢，下面简单说一下操作方式。

# 多集群kubeconfig合并

```
# cd /root/.kube/
# touch new-config1    #将一个集群kubeconfig内容写入new-config1文件中
# touch new-config2    #将另一个集群kubeconfig内容写入new-config2文件中
# KUBECONFIG=new-config1:new-config2  kubectl config view --flatten > $HOME/.kube/config
# kubectl config get-contexts   #获取集群信息
# kubectl config use-context xxxx-context-default   #切换集群
```

# 多集群kubeconfig中user信息相同如何合并

有的时候我们的不同集群的kubeconfig,会存在user和name信息都是admin，因为集群一般默认是用admin用户作为kubectl的kubeconfig,当你执行命令进行合并的时候发现新的config文件只会存在一个集群信息可以操作，这是因为user和name信息相同导致合并后只取一个集群的信息。这个需要怎么处理呢，我们这边讲解下，下面文件的token和证书都是测试的，防止泄露集群，信息已被更改。

集群A的config1
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01URXlOVEF5TURRek9Wb1hEVE13TVRFeU16QXlNRFF6T1Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTWYwCk5yWDFVYXU0d1ppdC9uKy9meWlydHNIUnlYMWJvRDE2bUU3elo3Y3kwSit2WjVTdkZHMW5xbksvMmNzTWF6clUKM0tVTUZpZTE1Z1hvOThwTFBiMnFYaWpnTlZYc1N4ZnhPVG9PajJVU09WV2FiSCswLytRbVdsQXhQa242MUsvZ
    server: https://cls-A.ccs.tencent-cloud.com
  name: local
contexts:
- context:
    cluster: local
    user: admin
  name: cls-A-context-default
current-context: cls-A-context-default
kind: Config
preferences: {}
users:
- name: admin
  user:
    token: 98Kvn5zx
```

集群B的config2
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01URXlOVEF5TURRek9Wb1hEVE13TVRFeU16QXlNRFF6T1Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTWYwCk5yWDFVYXU0d1ppdC9uKy9meWlydHNIUnlYMWJvRDE2bUU3elo3Y3kwSit2WjVTdkZHMW5xbksvMmNzTWF6clUKM0tVTUZpZTE1Z1hvOThwTFBiMnFYaWpnTlZYc1N4ZnhPVG9PajJVU09WV2FiSCswLytRbVdsQXhQa242MUsvZ
    server: https://cls-B.ccs.tencent-cloud.com
  name: local
contexts:
- context:
    cluster: local
    user: admin
  name: cls-B-context-default
current-context: cls-B-context-default
kind: Config
preferences: {}
users:
- name: admin
  user:
    token: FDSFKvn5zx
```

执行下面命令会出现合并后可以切换集群，但是切换集群后，获取集群节点等信息都是一个集群的。

```
KUBECONFIG=new-config1:new-config2  kubectl config view --flatten > $HOME/.kube/config
```

那么我们需要如何修改呢，可以按照下面方式修改下

修改后集群A的config1
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01URXlOVEF5TURRek9Wb1hEVE13TVRFeU16QXlNRFF6T1Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTWYwCk5yWDFVYXU0d1ppdC9uKy9meWlydHNIUnlYMWJvRDE2bUU3elo3Y3kwSit2WjVTdkZHMW5xbksvMmNzTWF6clUKM0tVTUZpZTE1Z1hvOThwTFBiMnFYaWpnTlZYc1N4ZnhPVG9PajJVU09WV2FiSCswLytRbVdsQXhQa242MUsvZ
    server: https://cls-A.ccs.tencent-cloud.com
  name: A
contexts:
- context:
    cluster: A
    user: A-admin
  name: cls-A-context-default
current-context: cls-A-context-default
kind: Config
preferences: {}
users:
- name: A-admin
  user:
    token: 98Kvn5zx
```

修改后集群B的config2
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJd01URXlOVEF5TURRek9Wb1hEVE13TVRFeU16QXlNRFF6T1Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTWYwCk5yWDFVYXU0d1ppdC9uKy9meWlydHNIUnlYMWJvRDE2bUU3elo3Y3kwSit2WjVTdkZHMW5xbksvMmNzTWF6clUKM0tVTUZpZTE1Z1hvOThwTFBiMnFYaWpnTlZYc1N4ZnhPVG9PajJVU09WV2FiSCswLytRbVdsQXhQa242MUsvZ
    server: https://cls-B.ccs.tencent-cloud.com
  name: B
contexts:
- context:
    cluster: B
    user: B-admin
  name: cls-B-context-default
current-context: cls-B-context-default
kind: Config
preferences: {}
users:
- name: B-admin
  user:
    token: FDSFKvn5zx
```

然后再执行合并config命令,执行kubectl切换集群获取集群信息正常

```
KUBECONFIG=new-config1:new-config2  kubectl config view --flatten > $HOME/.kube/config
```

# kubectx命令切换集群

我们也可以通过kubectx这个小工具进行集群的切换

```
# yum install git -y
# git clone https://github.com/ahmetb/kubectx /opt/kubectx
# ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
# export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config1:$HOME/.kube/config2
# kubectx
cls-hzywbn-context-default
cls-llbn4z-context-default
# kubectx cls-hzywbn88-context-default
Switched to context "cls-hzywbn-context-default".
```

# kubens工具快速切换命名空间

其实这个项目中还有一个小工具可以快速切换ns，这里我们简单讲解下如何使用

```
# ln -s /opt/kubectx/kubens /usr/local/bin/kubens
# kubens
default
gitlab
istio-system
kube-node-lease
kube-ops
kube-public
kube-system
log
monitor
tcr-assistant-system
test
treafik
```

