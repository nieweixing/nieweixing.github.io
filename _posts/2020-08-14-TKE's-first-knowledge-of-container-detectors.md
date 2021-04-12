---
title: Kubernetes之初识容器探测器
author: VashonNie
date: 2020-08-14 14:10:00 +0800
updated: 2020-08-14 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [TKE,Kubernetes,Probe]
math: true
---

kubelet 使用存活探测器来知道什么时候要重启容器。例如，存活探测器可以捕捉到死锁（应用程序在运行，但是无法继续执行后面的步骤）。这样的情况下重启容器有助于让应用程序在有问题的情况下更可用。

kubelet 使用就绪探测器可以知道容器什么时候准备好了并可以开始接受请求流量， 当一个 Pod 内的所有容器都准备好了，才能把这个 Pod 看作就绪了。这种信号的一个用途就是控制哪个 Pod 作为 Service 的后端。在 Pod 还没有准备好的时候，会从 Service 的负载均衡器中被剔除的。

kubelet 使用启动探测器可以知道应用程序容器什么时候启动了。如果配置了这类探测器，就可以控制容器在启动成功后再进行存活性和就绪检查，确保这些存活、就绪探测器不会影响应用程序的启动。这可以用于对慢启动容器进行存活性检测，避免它们在启动运行之前就被杀掉。

# 就绪探针readinessProbe

用于判断容器是否启动完成，即容器的Ready是否为True，可以接收请求，如果ReadinessProbe探测失败，则容器的Ready将为False，控制器将此Pod的Endpoint从对应的service的Endpoint列表中移除，从此不再将任何请求调度此Pod上，直到下次探测成功。通过使用Readiness探针，Kubernetes能够等待应用程序完全启动，然后才允许服务将流量发送到新副本。

比如使用tomcat的应用程序来说，并不是简单地说tomcat启动成功就可以对外提供服务的，还需要等待spring容器初始化，数据库连接没连上等等。对于spring boot应用，默认的actuator带有/health接口，可以用来进行启动成功的判断

## 探测方式

* exec：通过执行命令来检查服务是否正常，针对复杂检测或无HTTP接口的服务，命令返回值为0则表示容器健康。
* httpGet：通过发送http请求检查服务是否正常，返回200-399状态码则表明容器健康。
* tcpSocket：通过容器的IP和Port执行TCP检查，如果能够建立TCP连接，则表明容器健康。

## 探测参数

* initialDelaySeconds：容器启动后要等待多少秒后存活和就绪探测器才被初始化，默认是 0 秒，最小值是 0。
* periodSeconds：执行探测的时间间隔（单位是秒）。默认是 10 秒。最小值是 1。
* timeoutSeconds：探测的超时后等待多少秒。默认值是 1 秒。最小值是 1。
* successThreshold：探测器在失败后，被视为成功的最小连续成功数。默认值是 1。存活探测的这个值必须是 1。最小值是 1。
* failureThreshold：当探测失败时，Kubernetes 的重试次数。存活探测情况下的放弃就意味着重新启动容器。就绪探测情况下的放弃 Pod 会被打上未就绪的标签。默认值是 3。最小值是 1。

HTTP 探测器可以在 httpGet 上配置额外的字段：
* host：连接使用的主机名，默认是 Pod 的 IP。也可以在 HTTP 头中设置 “Host” 来代替。
* scheme ：用于设置连接主机的方式（HTTP 还是 HTTPS）。默认是 HTTP。
* path：访问 HTTP 服务的路径。
* httpHeaders：请求中自定义的 HTTP 头。HTTP 头字段允许重复。
* port：访问容器的端口号或者端口名。如果数字必须在 1 ～ 65535 之间。

## TKE中实践

一般我们在TKE中单独配置readinessProbe，如果这边连续探测多少次都失败，pod是不会重启的，只是不会接受请求的。我们创建一个只设置就绪探针的pod，并探测81端口，看pod会怎么样。

![upload-image](/assets/images/blog/probe/1.png) 

![upload-image](/assets/images/blog/probe/2.png) 

我们查看事件发现探测了13次失败了，pod是不会重启的，这边会一直探测直到服务启动成功。

![upload-image](/assets/images/blog/probe/3.png) 

![upload-image](/assets/images/blog/probe/4.png) 

# 存活探针livenessProbe

用于判断容器是否存活，即Pod是否为running状态，如果LivenessProbe探针探测到容器不健康，则kubelet将kill掉容器，并根据容器的重启策略是否重启。如果一个容器不包含LivenessProbe探针，则Kubelet认为容器的LivenessProbe探针的返回值永远成功。

有时应用程序可能因为某些原因（后端服务故障等）导致暂时无法对外提供服务，但应用软件没有终止，导致K8S无法隔离有故障的pod，调用者可能会访问到有故障的pod，导致业务不稳定。K8S提供livenessProbe来检测应用程序是否正常运行，并且对相应状况进行相应的补救措施。

重启策略：指示容器是否正在运行。如果存活探测失败，则 kubelet 会杀死容器，并且容器将受到其 重启策略 的影响。如果容器不提供存活探针，则默认状态为 Success

## 探测方式

* exec：通过执行命令来检查服务是否正常，针对复杂检测或无HTTP接口的服务，命令返回值为0则表示容器健康。
* httpGet：通过发送http请求检查服务是否正常，返回200-399状态码则表明容器健康。
* tcpSocket：通过容器的IP和Port执行TCP检查，如果能够建立TCP连接，则表明容器健康。

## 探测参数

* initialDelaySeconds：容器启动后要等待多少秒后存活和就绪探测器才被初始化，默认是 0 秒，最小值是 0。
* periodSeconds：执行探测的时间间隔（单位是秒）。默认是 10 秒。最小值是 1。
* timeoutSeconds：探测的超时后等待多少秒。默认值是 1 秒。最小值是 1。
* successThreshold：探测器在失败后，被视为成功的最小连续成功数。默认值是 1。存活探测的这个值必须是 1。最小值是 1。
* failureThreshold：当探测失败时，Kubernetes 的重试次数。存活探测情况下的放弃就意味着重新启动容器。就绪探测情况下的放弃 Pod 会被打上未就绪的标签。默认值是 3。最小值是 1。

HTTP 探测器可以在 httpGet 上配置额外的字段：

* host：连接使用的主机名，默认是 Pod 的 IP。也可以在 HTTP 头中设置 “Host” 来代替。
* scheme ：用于设置连接主机的方式（HTTP 还是 HTTPS）。默认是 HTTP。
* path：访问 HTTP 服务的路径。
* httpHeaders：请求中自定义的 HTTP 头。HTTP 头字段允许重复。
* port：访问容器的端口号或者端口名。如果数字必须在 1 ～ 65535 之间。

## TKE中实践

这里存活探针不一样，加入连续探测多次失败会根据你设置的重启策略来看是否让pod重启，这里我们配置一个单独的存活探针的pod。也是nignx服务，并探测81端口。配置的重启策略是always，下面我们看看pod会怎么样。

![upload-image](/assets/images/blog/probe/5.png) 

![upload-image](/assets/images/blog/probe/6.png) 

这边我们从事件看出，如果联系探测3次失败就会重启pod。

![upload-image](/assets/images/blog/probe/7.png)

# 启动探针startupProbe

startupProbe是在k8s v1.16加入了alpha版，有时候，会有一些现有的应用程序在启动时需要较多的初始化时间。要不影响对引起探测死锁的快速响应，这种情况下，设置存活探测参数是要技巧的。技巧就是使用一个命令来设置启动探测，针对HTTP 或者 TCP 检测，可以通过设置 failureThreshold * periodSeconds参数来保证有足够长的时间应对糟糕情况下的启动时间。

```
ports:
- name: liveness-port
  containerPort: 8080
  hostPort: 8080

livenessProbe:
  httpGet:
    path: /healthz
    port: liveness-port
  failureThreshold: 1
  periodSeconds: 10

startupProbe:
  httpGet:
    path: /healthz
    port: liveness-port
  failureThreshold: 30
  periodSeconds: 10
```

有了启动探测，应用程序将会有最多 5 分钟(30 * 10 = 300s) 的时间来完成它的启动。 一旦启动探测成功一次，存活探测任务就会接管对容器的探测，对容器死锁可以快速响应。 如果启动探测一直没有成功，容器会在 300 秒后被杀死，并且根据restartPolicy来设置 Pod 状态。

## 探测方式

* exec：通过执行命令来检查服务是否正常，针对复杂检测或无HTTP接口的服务，命令返回值为0则表示容器健康。
* httpGet：通过发送http请求检查服务是否正常，返回200-399状态码则表明容器健康。
* tcpSocket：通过容器的IP和Port执行TCP检查，如果能够建立TCP连接，则表明容器健康。

## 探测参数

* initialDelaySeconds：容器启动后要等待多少秒后存活和就绪探测器才被初始化，默认是 0 秒，最小值是 0。
* periodSeconds：执行探测的时间间隔（单位是秒）。默认是 10 秒。最小值是 1。
* timeoutSeconds：探测的超时后等待多少秒。默认值是 1 秒。最小值是 1。
* successThreshold：探测器在失败后，被视为成功的最小连续成功数。默认值是 1。存活探测的这个值必须是 1。最小值是 1。
* failureThreshold：当探测失败时，Kubernetes 的重试次数。存活探测情况下的放弃就意味着重新启动容器。就绪探测情况下的放弃 Pod 会被打上未就绪的标签。默认值是 3。最小值是 1。

HTTP 探测器可以在 httpGet 上配置额外的字段：

* host：连接使用的主机名，默认是 Pod 的 IP。也可以在 HTTP 头中设置 “Host” 来代替。
* scheme ：用于设置连接主机的方式（HTTP 还是 HTTPS）。默认是 HTTP。
* path：访问 HTTP 服务的路径。
* httpHeaders：请求中自定义的 HTTP 头。HTTP 头字段允许重复。
* port：访问容器的端口号或者端口名。如果数字必须在 1 ～ 65535 之间。

# 参考文档
<https://kubernetes.io/zh/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/>