---
title: 使用eck快速在k8s部署es集群
author: VashonNie
date: 2021-06-12 14:10:00 +0800
updated: 2021-06-12 14:10:00 +0800
categories: [elasticsearch]
tags: [Elasticsearch]
math: true
---

# eck介绍

Elastic Cloud on Kubernetes(ECK)是一个 Elasticsearch Operator，但远不止于此。 ECK 使用 Kubernetes Operator 模式构建而成，需要安装在您的 Kubernetes 集群内，其功能绝不仅限于简化 Kubernetes 上 Elasticsearch 和 Kibana 的部署工作这一项任务。ECK 专注于简化所有后期运行工作，例如：

* 管理和监测多个集群
* 轻松升级至新的版本
* 扩大或缩小集群容量
* 更改集群配置
* 动态调整本地存储的规模（包括 Elastic Local Volume（一款本地存储驱动器））
* 备份

ECK 不仅能自动完成所有运行和集群管理任务，还专注于简化在 Kubernetes 上使用 Elasticsearch 的完整体验。ECK 的愿景是为 Kubernetes 上的 Elastic 产品和解决方案提供 SaaS 般的体验。在 ECK 上启动的所有 Elasticsearch 集群都默认受到保护，这意味着在最初创建的那一刻便已启用加密并受到默认强密码的保护。

从 6.8 和 7.1 版本开始，Elasticsearch 核心安全功能（TLS 加密、基于角色的访问控制，以及文件和原生身份验证）会免费提供。
通过 ECK 部署的所有集群都包括强大的基础（免费）级功能，例如可实现密集存储的冻结索引、Kibana Spaces、Canvas、Elastic Maps，等等。您甚至可以使用 Elastic Logs 和 Elastic Infrastructure 应用监测 Kubernetes 日志和基础设施。您可以获得在 Kubernetes 上使用 Elastic Stack 完整功能的体验。

ECK 内构建了 Elastic Local Volume，这是一个适用于 Kubernetes 的集成式存储驱动器。ECK 中还融入了很多最佳实践，例如在缩小规模之前对节点进行 drain 操作，在扩大规模的时候对分片进行再平衡，等等。从确保在配置变动过程中不会丢失数据，到确保在规模调整过程中实现零中断。

# 安装eck

直接执行下面命令部署elastic-operator到集群中

```
kubectl apply -f https://download.elastic.co/downloads/eck/1.6.0/all-in-one.yaml
```

可以用下面命令查看elastic-operator是否部署好

```
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

# 部署es集群

es会默认自带elastic用户和随机密码作为鉴权，这里我们也可以新增用户来鉴权

```
# 创建一个文件夹和两个文件，用户存储用户和角色
mkdir filerealm
touch filerealm/users filerealm/users_roles

# 创建用户'kubesphere'的角色为'superuser'
docker run \
    -v $(pwd)/filerealm:/usr/share/elasticsearch/config \
    docker.elastic.co/elasticsearch/elasticsearch:7.10.2 \
    bin/elasticsearch-users useradd kubesphere -p kubesphere -r superuser

# 创建Kubernetes secret
kubectl create secret generic kubesphere-elasticsearch-realm-secret --from-file filerealm -n kubesphere-logging-system
```


```
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: logging
  namespace: elastic-system
spec:
  version: 7.10.2
  image: docker.elastic.co/elasticsearch/elasticsearch:7.10.2 #指定镜像
  auth:
    fileRealm:
    - secretName: kubesphere-elasticsearch-realm-secret # 通过Kubernetes secret添加自定义用户和密码
  http:
    tls:
      selfSignedCertificate:
        disabled: true # 关闭tls
  nodeSets:
  - name: default 
    count: 3 # 部署集群节点数
    config:
      node.store.allow_mmap: false
    volumeClaimTemplates: # 存储配置
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
        storageClassName: cbs
EOF
```

运行上的yaml，会创建一个elasticsearch资源，elasticsearch会部署一个StatefulSet，起3个pod到集群中，如果pod都是running，则说明集群运行成功

```
[root@VM-0-13-centos filerealm]# k get elasticsearch -n elastic-system
NAME      HEALTH   NODES   VERSION   PHASE   AGE
logging   green    3       7.10.2    Ready   40m

[root@VM-0-13-centos filerealm]# kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=logging' -n elastic-system
NAME                   READY   STATUS    RESTARTS   AGE
logging-es-default-0   1/1     Running   0          41m
logging-es-default-1   1/1     Running   0          41m
logging-es-default-2   1/1     Running   0          41m
```

这里我们只编写了部分功能到elasticsearch集群中，更多elasticsearch配置可以参考官方文档<https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-elasticsearch-specification.html>

# 部署ingress通过域名访问es

这里我们通过域名来访问我们的es集群，部署一个ingress

```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: ingress
  name: es-ingress
  namespace: elastic-system
spec:
  rules:
  - host: es.tke.niewx.cn
    http:
      paths:
      - backend:
          serviceName: logging-es-http
          servicePort: 9200
        path: /
```

# 访问es集群

这里可以用我们自己新增的用户kubesphere或者默认自带的elastic访问集群都可以，这里获取下elastic用户的密码

```
# kubectl get secret logging-es-elastic-user -o=jsonpath='{.data.elastic}' -n elastic-system | base64 -d
Je2495pW2SOa
```

这里我们分别用elastic和kubesphere这2个用户都能访问成功

```
[root@VM-0-13-centos ~]# curl -u 'elastic:Je2pW2SOa' es.tke.niewx.cn
{
  "name" : "logging-es-default-0",
  "cluster_name" : "logging",
  "cluster_uuid" : "JirzQVaATcWvpptIyNWoUw",
  "version" : {
    "number" : "7.10.2",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "747e1cc71def077253878a59143c1f785afa92b9",
    "build_date" : "2021-01-13T00:42:12.435326Z",
    "build_snapshot" : false,
    "lucene_version" : "8.7.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
[root@VM-0-13-centos ~]# curl -u 'kubesphere:kubesphere' es.tke.niewx.cn
{
  "name" : "logging-es-default-1",
  "cluster_name" : "logging",
  "cluster_uuid" : "JirzQVaATcWvpptIyNWoUw",
  "version" : {
    "number" : "7.10.2",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "747e1cc71def077253878a59143c1f785afa92b9",
    "build_date" : "2021-01-13T00:42:12.435326Z",
    "build_snapshot" : false,
    "lucene_version" : "8.7.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

# 部署kibana

我们也可以用eck快速部署一个kibana到集群中，将上面部署的es直接对接我们要部署的kibana

```
kubectl create secret generic kibana-elasticsearch-credentials --from-literal=elasticsearch.password=Je2K3pW2SOa -n elastic-system
```

创建好访问秘钥后，创建kibana对象

```
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: elastic-system
spec:
  version: 7.10.2
  count: 1
  config:
    elasticsearch.hosts:
      - http://es.tke.niewx.cn
    elasticsearch.username: elastic
  secureSettings:
    - secretName: kibana-elasticsearch-credentials
EOF
```

查看下kibana是否部署成功，kibana是green，pod也是正常running，则说明部署成功

```
[root@VM-0-13-centos ~]# k get kibana -n elastic-system
NAME     HEALTH   NODES   VERSION   AGE
kibana   green    1       7.10.2    6m27s
[root@VM-0-13-centos ~]# k get pod  -n elastic-system | grep kibana
kibana-kb-5fb584f664-bdt68   1/1     Running   0          3m15s
```

这里我们只讲了es和kibana的部署，其实eck还可以部署filebeat、EnterpriseSearch等组件到集群，具体参考文档<https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-orchestrating-elastic-stack-applications.html>