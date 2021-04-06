---
title: istio入门系列之ServiceEntry
author: VashonNie
date: 2020-11-30 10:10:00 +0800
updated: 2020-11-30 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes,ServiceEntry]
math: true
---

ServiceEntry是用来将网络外部的服务纳入到网格内部进行管理，这个和ingress刚好相反，通过ServiceEntry我们可以通过网格来管理外部服务请求，管理外部服务的流量控制以及扩展我们得mesh网格。

![upload-image](/assets/images/blog/ServiceEntry/1.png) 

下面我们来做学习一下ServiceEntry的配置。

首先我们配置一个sleep服务

```
$ kubectl apply -f samples/sleep/sleep.yaml
```

我们通过httpbin这个服务来模拟外部服务，我们先来访问一下httpbin的外部服务

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep curl http://httpbin.org/headers
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.org", 
    "User-Agent": "curl/7.69.1", 
    "X-Amzn-Trace-Id": "Root=1-5fc87774-4f54154c2980a5b025f89352", 
    "X-B3-Parentspanid": "6af159684e0aa32b", 
    "X-B3-Sampled": "1", 
    "X-B3-Spanid": "db66efff3f1277d7", 
    "X-B3-Traceid": "fad0512b316618c66af159684e0aa32b", 
    "X-Envoy-Decorator-Operation": "httpbin.org:80/*", 
    "X-Envoy-Internal": "true", 
    "X-Envoy-Peer-Metadata": "ChwKDElOU1RBTkNFX0lQUxIMGgoxMC4wLjIuMTE2CpACCgZMQUJFTFMShQIqggIKHAoDYXBwEhUaE2lzdGlvLWVncmVzc2dhdGV3YXkKEwoFY2hhcnQSChoIZ2F0ZXdheXMKFAoIaGVyaXRhZ2USCBoGVGlsbGVyChgKBWlzdGlvEg8aDWVncmVzc2dhdGV3YXkKIQoRcG9kLXRlbXBsYXRlLWhhc2gSDBoKNjY2OTU2Yjc0NwoSCgdyZWxlYXNlEgcaBWlzdGlvCjgKH3NlcnZpY2UuaXN0aW8uaW8vY2Fub25pY2FsLW5hbWUSFRoTaXN0aW8tZWdyZXNzZ2F0ZXdheQosCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIFGgMxLjUKGgoHTUVTSF9JRBIPGg1jbHVzdGVyLmxvY2FsCi4KBE5BTUUSJhokaXN0aW8tZWdyZXNzZ2F0ZXdheS02NjY5NTZiNzQ3LXpwNHZoChsKCU5BTUVTUEFDRRIOGgxpc3Rpby1zeXN0ZW0KXAoFT1dORVISUxpRa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2lzdGlvLXN5c3RlbS9kZXBsb3ltZW50cy9pc3Rpby1lZ3Jlc3NnYXRld2F5CjgKD1NFUlZJQ0VfQUNDT1VOVBIlGiNpc3Rpby1lZ3Jlc3NnYXRld2F5LXNlcnZpY2UtYWNjb3VudAomCg1XT1JLTE9BRF9OQU1FEhUaE2lzdGlvLWVncmVzc2dhdGV3YXk=", 
    "X-Envoy-Peer-Metadata-Id": "router~10.0.2.116~istio-egressgateway-666956b747-zp4vh.istio-system~istio-system.svc.cluster.local"
  }
}
```

这里我们可以直接访问到httpbin服务，这是因为istio默认是访问所有的外部服务的，为了测试服务入口，我们修改下istio的configmap，配置成REGISTRY_ONLY才能访问。

```
[root@VM-0-13-centos istio-1.5.1]# kubectl get configmap istio -n istio-system -o yaml | sed 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/g' | kubectl replace -n istio-system -f -
configmap/istio replaced
```

配置生效后，sleep无法访问到httpbin服务，下面我们来定义一个服务入口让sleep可以访问外部的httpbin服务

```
$ kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
EOF
```

我们在ServiceEntry配置了host为httpbin.org，对应的端口为80，下面我们再测试下

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep curl http://httpbin.org/headers
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.org", 
    "User-Agent": "curl/7.69.1", 
    "X-Amzn-Trace-Id": "Root=1-5fc87bc5-60893e2d0634966b7c765ba9", 
    "X-B3-Parentspanid": "9d40fcfc23d415b3", 
    "X-B3-Sampled": "1", 
    "X-B3-Spanid": "d06c579a9b828d76", 
    "X-B3-Traceid": "97183bca9a86ba7b9d40fcfc23d415b3", 
    "X-Envoy-Decorator-Operation": "httpbin.org:80/*", 
    "X-Envoy-Internal": "true", 
    "X-Envoy-Peer-Metadata": "ChwKDElOU1RBTkNFX0lQUxIMGgoxMC4wLjIuMTE2CpACCgZMQUJFTFMShQIqggIKHAoDYXBwEhUaE2lzdGlvLWVncmVzc2dhdGV3YXkKEwoFY2hhcnQSChoIZ2F0ZXdheXMKFAoIaGVyaXRhZ2USCBoGVGlsbGVyChgKBWlzdGlvEg8aDWVncmVzc2dhdGV3YXkKIQoRcG9kLXRlbXBsYXRlLWhhc2gSDBoKNjY2OTU2Yjc0NwoSCgdyZWxlYXNlEgcaBWlzdGlvCjgKH3NlcnZpY2UuaXN0aW8uaW8vY2Fub25pY2FsLW5hbWUSFRoTaXN0aW8tZWdyZXNzZ2F0ZXdheQosCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIFGgMxLjUKGgoHTUVTSF9JRBIPGg1jbHVzdGVyLmxvY2FsCi4KBE5BTUUSJhokaXN0aW8tZWdyZXNzZ2F0ZXdheS02NjY5NTZiNzQ3LXpwNHZoChsKCU5BTUVTUEFDRRIOGgxpc3Rpby1zeXN0ZW0KXAoFT1dORVISUxpRa3ViZXJuZXRlczovL2FwaXMvYXBwcy92MS9uYW1lc3BhY2VzL2lzdGlvLXN5c3RlbS9kZXBsb3ltZW50cy9pc3Rpby1lZ3Jlc3NnYXRld2F5CjgKD1NFUlZJQ0VfQUNDT1VOVBIlGiNpc3Rpby1lZ3Jlc3NnYXRld2F5LXNlcnZpY2UtYWNjb3VudAomCg1XT1JLTE9BRF9OQU1FEhUaE2lzdGlvLWVncmVzc2dhdGV3YXk=", 
    "X-Envoy-Peer-Metadata-Id": "router~10.0.2.116~istio-egressgateway-666956b747-zp4vh.istio-system~istio-system.svc.cluster.local"
  }
}
```

我们发现配置后是可以访问外部的服务的。下面我们来看看如何通过ServiceEntry来访问外部的https服务

创建一个ServiceEntry，允许对外部https服务的访问。

```
# kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: baidu
spec:
  hosts:
  - www.baidu.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
EOF
```

执行测试命令

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- curl -I https://www.baidu.com | grep "HTTP/"
HTTP/1.1 200 OK
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- curl -I https://www.baidu.com | grep "HTTP/"
HTTP/1.1 200 OK
```

查看sleep pod的sidecar日志
```
[root@VM-0-13-centos istio-1.5.1]# kubectl logs sleep-5b7bf56c54-krj9n -c istio-proxy | tail | grep baidu
[2020-12-03T04:15:57.157Z] "- - -" 0 - "-" "-" 781 4652 23 - "-" "-" "-" "-" "14.215.177.39:443" PassthroughCluster 10.0.1.38:59692 14.215.177.39:443 10.0.1.38:59690 www.baidu.com -
[2020-12-03T04:17:20.514Z] "- - -" 0 - "-" "-" 781 4652 20 - "-" "-" "-" "-" "14.215.177.38:443" outbound|443||www.baidu.com 10.0.1.38:41854 14.215.177.38:443 10.0.1.38:41852 www.baidu.com -
[2020-12-03T04:18:48.342Z] "- - -" 0 - "-" "-" 781 4652 24 - "-" "-" "-" "-" "14.215.177.39:443" outbound|443||www.baidu.com 10.0.1.38:36252 14.215.177.39:443 10.0.1.38:36250 www.baidu.com -
```