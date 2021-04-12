---
title: TKE上搭建企业级镜像仓库Harbor
author: VashonNie
date: 2020-12-20 14:10:00 +0800
updated: 2020-12-20 14:10:00 +0800
categories: [Harbor]
tags: [Harbor,TKE,Docker]
math: true
---

本次我们来讲解下如何在TKE上搭建企业级镜像仓库Harbor，这里我们采用的是helm方式部署到TKE集群上，helm部署的harbor会通过ingress暴露前端页面提供访问，一般我们需要通过域名的https方式来访问Harbor仓库，所以我们需要做如下准备：

* 腾讯云上申请一个TKE集群
* 安装helm
* 集群上安装nginx-ingress这个插件，可以参考<https://cloud.tencent.com/document/product/457/50503>
* 腾讯云上申请一个域名，在dnspod将域名解析到nginx-ingress的入口lb上，我这里将*.tke.niewx.cn解析到我的nginx-ingress入口lb上
* 腾讯云上申请免费的ssl证书，解析到你的harbor域名，我这里的域名是harbor.tke.niewx.cn

如上都准备好，我们就开始进行部署harbor到TKE集群中，本次搭建仅作为示例，不做实际的使用。

# helm下载harbor的chart包

因为我们需要修改chart包中一些参数，我们需要先下载chart包，然后修改value.yaml中的参数

```
# helm repo add harbor https://helm.goharbor.io
# helm fetch harbor/harbor 1.5.2
# tar -zxvf harbor-1.5.2.tgz
```

# 修改value.yaml

这里我们只指出value.yanl需要修改的地方，大家可以根据的注释说明进行修改，这里ingress我用的nginx-ingress插件，和原生的控制器有点差别，这里我们会先不修改，后续会删除helm创建的ingress，重新配置ingress。

```
expose:
  type: ingress
  tls:
    enabled: false  #如果没有证书，则设置为false
    certSource: auto
    auto:
      commonName: ""
    secret:
      secretName: ""
      notarySecretName: ""
  ingress:
    hosts:
      core: core.harbor.domain
      notary: notary.harbor.domain
    controller: default
    annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
  clusterIP:
    name: harbor
    ports:
      httpPort: 80
      httpsPort: 443
      notaryPort: 4443
  nodePort:
    name: harbor
    ports:
      http:
        port: 80
        nodePort: 30002
      https:
        port: 443
        nodePort: 30003
      notary:
        port: 4443
        nodePort: 30004
  loadBalancer:
    name: harbor
    IP: ""
    ports:
      httpPort: 80
      httpsPort: 443
      notaryPort: 4443
    annotations: {}
    sourceRanges: []

# If Harbor is deployed behind the proxy, set it as the URL of proxy
externalURL: https://harbor.tke.niewx.cn  # 配置上需要给harbor访问的域名

......

persistence:
  enabled: true
  # Setting it to "keep" to avoid removing PVCs during a helm delete
  # operation. Leaving it empty will delete PVCs after the chart deleted
  # (this does not apply for PVCs that are created for internal database
  # and redis components, i.e. they are never deleted automatically)
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      # Use the existing PVC which must be created manually before bound,
      # and specify the "subPath" if the PVC is shared with other components
      existingClaim: ""
      # Specify the "storageClass" used to provision the volume. Or the default
      # StorageClass will be used(the default).
      # Set it to "-" to disable dynamic provisioning
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
    chartmuseum:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi  # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
    jobservice:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi  # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
    # If external database is used, the following settings for database will
    # be ignored
    database:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi  # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
    # If external Redis is used, the following settings for Redis will
    # be ignored
    redis:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi  # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
    trivy:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 10Gi  # 根据需要修改磁盘大小，腾讯云上cbs盘最小要求10G
  
..........
```

# 创建harbor服务

这里我们创建一个harbor的命名空间用来部署harbor

```
# kubectl create ns harbor
# helm install ./harbor --generate-name --namespace harbor

[root@VM-0-13-centos harbor]# kubectl get pod -n harbor
NAME                                                      READY   STATUS    RESTARTS   AGE
harbor-1610108910-harbor-chartmuseum-5874b9c6f-drk8f      1/1     Running   0          16h
harbor-1610108910-harbor-clair-cb9fb7cd-t58l8             2/2     Running   3          16h
harbor-1610108910-harbor-core-69d8dd696b-wzdp8            1/1     Running   0          16h
harbor-1610108910-harbor-database-0                       1/1     Running   0          16h
harbor-1610108910-harbor-jobservice-754bfbfd65-qk9ps      1/1     Running   0          16h
harbor-1610108910-harbor-notary-server-7f4ccfd65c-kbc62   1/1     Running   1          16h
harbor-1610108910-harbor-notary-signer-676f5dfbb7-p8r6q   1/1     Running   1          16h
harbor-1610108910-harbor-portal-59b9d4f876-p44bm          1/1     Running   0          16h
harbor-1610108910-harbor-redis-0                          1/1     Running   0          16h
harbor-1610108910-harbor-registry-7c445d6cd8-qfvkc        2/2     Running   0          16h
harbor-1610108910-harbor-trivy-0                          1/1     Running   0          16h
```

# 通过nginx-ingress配置harbor访问域名

这边等pod启动后，我们通过nginx-ingress来配置下harbor的域名，因为harbor需要提供https服务，我们需要在ingress配置tls，因此需要先将我们之前申请的证书通过secret进行挂载。

```
# kubectl create secret tls harbor-ssl --key 2_harbor.tke.niewx.cn.key --cert 1_harbor.tke.niewx.cn_bundle.crt -n harbor
```

配置ingress转发harbor-portal的前端页面访问service

```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.cloud.tencent.com/direct-access: "false"
    kubernetes.io/ingress.class: nwx-ingress
    kubernetes.io/ingress.extensiveParameters: '{"AddressIPVersion":"IPV4"}'
    kubernetes.io/ingress.http-rules: '[{"host":"harbor.tke.niewx.cn","path":"/","backend":{"serviceName":"harbor-1610088954-harbor-portal","servicePort":"80"}}]'
    kubernetes.io/ingress.https-rules: "null"
    kubernetes.io/ingress.rule-mix: "false"
    nginx.ingress.kubernetes.io/proxy-body-size: 1000m
    nginx.ingress.kubernetes.io/use-regex: "true"
  name: harbor-ingress
  namespace: harbor
spec:
  rules:
  - host: harbor.tke.niewx.cn
    http:
      paths:
      - backend:
          serviceName: harbor-1610108910-harbor-portal
          servicePort: 80
        path: /
      - backend:
          serviceName: harbor-1610108910-harbor-core
          servicePort: 80
        path: /api
      - backend:
          serviceName: harbor-1610108910-harbor-core
          servicePort: 80
        path: /service
      - backend:
          serviceName: harbor-1610108910-harbor-core
          servicePort: 80
        path: /v2
      - backend:
          serviceName: harbor-1610108910-harbor-core
          servicePort: 80
        path: /chartrepo
      - backend:
          serviceName: harbor-1610108910-harbor-core
          servicePort: 80
        path: /c
  tls:
  - hosts:
    - harbor.tke.niewx.cn
    secretName: harbor-ssl
status:
  loadBalancer:
    ingress:
    - ip: 81.71.131.235
```

配置好之后，可以将helm创建的ingresss删除掉，然后直接浏览器输入 https://harbor.tke.niewx.cn 进行访问，默认初始账号密码是 admin/Harbor12345，建议后续修改admin的密码，输入后正常登录即说明部署成功。

![upload-image](/assets/images/blog/tke-harbor/1.png) 

![upload-image](/assets/images/blog/tke-harbor/2.png) 

# 往harbor上传下载镜像

我们在harbor上创建了一个tke的项目，用来测试上传下载镜像

## 上传镜像

```
[root@VM-0-13-centos harbor]# docker login harbor.tke.niewx.cn
Authenticating with existing credentials...
Stored credentials invalid or expired
Username (admin): admin
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@VM-0-13-centos harbor]# docker tag nginx:latest harbor.tke.niewx.cn/tke/nginx:latest
[root@VM-0-13-centos harbor]# docker push harbor.tke.niewx.cn/tke/nginx:latest
The push refers to repository [harbor.tke.niewx.cn/tke/nginx]
4eaf0ea085df: Layer already exists 
2c7498eef94a: Layer already exists 
7d2b207c2679: Layer already exists 
5c4e5adc71a8: Layer already exists 
87c8a1d8f54f: Layer already exists 
latest: digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71 size: 1362
```

![upload-image](/assets/images/blog/tke-harbor/3.png) 

**注意**: 这里我们在上传镜像的时候遇到了一个问题，一般镜像文件比较大，推送可能会报错413 Request Entity Too Large，原来是上传文件太大，导致上传失败，这里我们在ingress修改下上传body大小就可以了，在ingress注解中加入就可以正常推送了 nginx.ingress.kubernetes.io/proxy-body-size: 1000m

## 下载镜像

我们在其他机器上拉取镜像试试

```
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
latest: Pulling from tke/nginx
Digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71
Status: Downloaded newer image for harbor.tke.niewx.cn/tke/nginx:latest
```

因为我们的镜像仓库是公开的，不需要登录也可以拉取，这里我们配置成私有的，需要先登录才能拉取镜像

![upload-image](/assets/images/blog/tke-harbor/4.png) 

```
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
Error response from daemon: unauthorized: unauthorized to access repository: tke/nginx, action: pull: unauthorized to access repository: tke/nginx, action: pull
[root@VM-0-3-centos ~]# docker login harbor.tke.niewx.cn -u admin
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
latest: Pulling from tke/nginx
Digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71
Status: Downloaded newer image for harbor.tke.niewx.cn/tke/nginx:latest
```

这里我们将镜像仓库改成私有的就需要登录才能拉取镜像。

# 创建子用户访问镜像仓库

我们创建一个tke的子账号，但是没有加入到项目中，我们看看能否拉取镜像

![upload-image](/assets/images/blog/tke-harbor/5.png) 

![upload-image](/assets/images/blog/tke-harbor/6.png) 

```
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
latest: Pulling from tke/nginx
Digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71
Status: Downloaded newer image for harbor.tke.niewx.cn/tke/nginx:latest
[root@VM-0-3-centos ~]# docker login harbor.tke.niewx.cn -u tke
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
Error response from daemon: unauthorized: unauthorized to access repository: tke/nginx, action: pull: unauthorized to access repository: tke/nginx, action: pull
```

从测试结果看是无法拉取镜像的，我们将tke用户加入到tke这个项目中再测试下，这里我们可以给tke分配不同的角色来分配不同的权限

![upload-image](/assets/images/blog/tke-harbor/7.png)

* 受限访客:受限访客对项目没有完全的读取权限。他们可以拉镜像，但不能推送，并且看不到日志或项目的其他成员。例如，可以为共享项目访问权限的不同组织的用户创建有限的来宾。
* 访客:访客具有指定项目的只读权限。他们可以提取和重新标记镜像，但不能推送。
* 开发者:开发者具有项目的读写权限。
* 维护人员: 维护人员的权限超出了"开发者"的权限，包括扫描镜像、查看复制作业以及删除镜像和掌舵图表的能力。
* 项目管理员:在创建新项目时，您将被分配到项目中的"项目管理人"角色。除了读写权限外，"ProjectAdmin"还具有一些管理权限，例如添加和删除成员、启动漏洞扫描。

除了上述角色之外，还有两个系统级角色：

* harbor系统管理员:"港口系统管理员"拥有最多的权限。除了上述权限外，"Harbor 系统管理员"还可以列出所有项目、将普通用户设置为管理员、删除用户以及设置所有镜像的漏洞扫描策略。公共项目"库"也归管理员所有。
* 匿名:当用户未登录时，该用户将被视为"匿名"用户。匿名用户无法访问私有项目，并且对公共项目具有只读访问权限。

## 分配访客权限给tke账号

![upload-image](/assets/images/blog/tke-harbor/8.png)

```
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
latest: Pulling from tke/nginx
Digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71
Status: Image is up to date for harbor.tke.niewx.cn/tke/nginx:latest
[root@VM-0-3-centos ~]# docker push harbor.tke.niewx.cn/tke/nginx:latest
The push refers to repository [harbor.tke.niewx.cn/tke/nginx]
4eaf0ea085df: Layer already exists 
2c7498eef94a: Layer already exists 
7d2b207c2679: Layer already exists 
5c4e5adc71a8: Layer already exists 
87c8a1d8f54f: Layer already exists 
unauthorized: unauthorized to access repository: tke/nginx, action: push: unauthorized to access repository: tke/nginx, action: push
```

可以发现，我们分配了访客权限给tke，我们只能拉取镜像，不能push镜像

## 分配开发者权限给tke账号

![upload-image](/assets/images/blog/tke-harbor/9.png)

```
[root@VM-0-3-centos ~]# docker pull harbor.tke.niewx.cn/tke/nginx:latest
latest: Pulling from tke/nginx
Digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71
Status: Image is up to date for harbor.tke.niewx.cn/tke/nginx:latest
[root@VM-0-3-centos ~]# docker push harbor.tke.niewx.cn/tke/nginx:latest
The push refers to repository [harbor.tke.niewx.cn/tke/nginx]
4eaf0ea085df: Layer already exists 
2c7498eef94a: Layer already exists 
7d2b207c2679: Layer already exists 
5c4e5adc71a8: Layer already exists 
87c8a1d8f54f: Layer already exists 
latest: digest: sha256:13e4551010728646aa7e1b1ac5313e04cf75d051fa441396832fcd6d600b5e71 size: 1362
```

分配了开发者后就可以推送镜像了，因为开发者有读写项目的权限，其他角色大家可以进行测试实践下，我们可以灵活的通过角色控制子用户的权限。

# Harbor镜像同步到TCR

我们测试下如何将harbor的镜像仓库同步到腾讯云上的TCR上，首先我们在Harobor上添加我们的TCR实例

![upload-image](/assets/images/blog/tke-harbor/10.png)

然后创建复制规则

![upload-image](/assets/images/blog/tke-harbor/11.png)

![upload-image](/assets/images/blog/tke-harbor/12.png)

配置好之后点击运行发现复制失败

![upload-image](/assets/images/blog/tke-harbor/13.png)

规则中我们没有填写命名空间，复制不会自动创建TCR的命名空间，所以需要先在tcr上创建一个tke的命名空间，创建后再执行复制操作即可

![upload-image](/assets/images/blog/tke-harbor/14.png)

这里我们发现复制成功了，我们去tcr控制台查看镜像也是存在的

![upload-image](/assets/images/blog/tke-harbor/15.png)

![upload-image](/assets/images/blog/tke-harbor/16.png)

# 参考文档

<https://github.com/goharbor/harbor-helm>