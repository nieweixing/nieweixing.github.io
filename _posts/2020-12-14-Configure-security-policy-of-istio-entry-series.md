---
title: istio入门系列之配置安全策略
author: VashonNie
date: 2020-12-14 14:10:00 +0800
updated: 2020-12-14 14:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

本章我们来讲讲如何通过istio来给业务pod进行安全的配置。istio的安全配置对于业务是透明的，istio的安全架构如下，主要是在istiod里进行认证和授权。

![upload-image](/assets/images/blog/istio-anquancelue/1.png) 

首先我们给demo下的httpbin这个服务配置一个安全策略，这里默认访问策略是拒绝所有访问

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: demo
spec:
  selector:
    matchLabels:
      app: httpbin
EOF
```

下面我们通过sleep服务来测试下是否可以访问到httpbin

```
[root@VM-0-13-centos istio-1.5.1]# kubectl get pod -n demo
NAME                          READY   STATUS    RESTARTS   AGE
httpbin-5f48f6c76b-q5rvv      2/2     Running   0          6d2h
httpbin-v2-5bd46f68f9-fjp84   2/2     Running   0          47h
sleep-5b7bf56c54-bhsk8        2/2     Running   0          6d2h
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/get
RBAC: access denied[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin-v2.demo:8000/get
{
  "args": {}, 
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin-v2.demo:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "8fda928356944839", 
    "X-B3-Traceid": "724aa8178d074e838fda928356944839", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Envoy-Decorator-Operation": "httpbin-v2.demo.svc.cluster.local:8000/*", 
    "X-Envoy-Peer-Metadata": "ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwobCgxJTlNUQU5DRV9JUFMSCxoJMTAuMC4xLjMyCt0BCgZMQUJFTFMS0gEqzwEKDgoDYXBwEgcaBXNsZWVwChcKDGlzdGlvLmlvL3JldhIHGgUxLTYtOQohChFwb2QtdGVtcGxhdGUtaGFzaBIMGgo1YjdiZjU2YzU0CiQKGXNlY3VyaXR5LmlzdGlvLmlvL3Rsc01vZGUSBxoFaXN0aW8KKgofc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtbmFtZRIHGgVzbGVlcAovCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIIGgZsYXRlc3QKGgoHTUVTSF9JRBIPGg1jbHVzdGVyLmxvY2FsCiAKBE5BTUUSGBoWc2xlZXAtNWI3YmY1NmM1NC1iaHNrOAoTCglOQU1FU1BBQ0USBhoEZGVtbwpGCgVPV05FUhI9GjtrdWJlcm5ldGVzOi8vYXBpcy9hcHBzL3YxL25hbWVzcGFjZXMvZGVtby9kZXBsb3ltZW50cy9zbGVlcAoaCg9TRVJWSUNFX0FDQ09VTlQSBxoFc2xlZXAKGAoNV09SS0xPQURfTkFNRRIHGgVzbGVlcA==", 
    "X-Envoy-Peer-Metadata-Id": "sidecar~10.0.1.32~sleep-5b7bf56c54-bhsk8.demo~demo.svc.cluster.local"
  }, 
  "origin": "127.0.0.1", 
  "url": "http://httpbin-v2.demo:8000/get"
}
```

我们部署了v1和v2这2个版本的httpbin，发现只有httpbin-v2可以访问到

下面我们制定下只允许在demo这个namespace下和demo这个命名空间下拥有sleep这个sa身份的才能访问

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: demo
spec:
 action: ALLOW
 rules:
 - from:
   - source:
       principals: ["cluster.local/ns/demo/sa/sleep"]
   - source:
       namespaces: ["demo"]
EOF
```

下面我们测试下，分别通过demo和nwxdemo中这2个命名空间下的sleep服务来访问下demo下的httpbin服务

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/get
{
  "args": {}, 
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.demo:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Parentspanid": "408e7d7f4363a9bf", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "89c42647d4f04419", 
    "X-B3-Traceid": "7f9fb7b5cffbb30b408e7d7f4363a9bf", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/demo/sa/httpbin;Hash=8047b0dc92219d97bf966222da87d61ac7c857f8a562f487f7a44e936da499e0;Subject=\"\";URI=spiffe://cluster.local/ns/demo/sa/sleep"
  }, 
  "origin": "127.0.0.1", 
  "url": "http://httpbin.demo:8000/get"
}
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-fh29m -n nwxdemo -c sleep -- curl http://httpbin.demo:8000/get
RBAC: access denied
```

可以发下只有demo下的pod才有访问权限。

接下来我们放通下nwxdemo下的sleep服务访问权限

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: demo
spec:
 action: ALLOW
 rules:
 - from:
   - source:
       principals: ["cluster.local/ns/nwxdemo/sa/sleep"]
   - source:
       namespaces: ["demo"]
EOF
```

我们放通nwxdemo下拥有sleep这个sa的服务允许访问就行。

下面我们配置下限制只能访问httpbin特定的接口

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: demo
spec:
 action: ALLOW
 rules:
 - from:
   - source:
       principals: ["cluster.local/ns/demo/sa/sleep"]
   - source:
       namespaces: ["demo"]
   to:
   - operation:
       methods: ["GET"]
       paths: ["/get"]
EOF
```

测试可以发现，sleep只能访问到httpbin的get接口，无法访问ip

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/get
{
  "args": {}, 
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.demo:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Parentspanid": "22a55f5bbea49ab5", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "33800e033e1cb882", 
    "X-B3-Traceid": "cc3a5b206a1a57be22a55f5bbea49ab5", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/demo/sa/httpbin;Hash=8047b0dc92219d97bf966222da87d61ac7c857f8a562f487f7a44e936da499e0;Subject=\"\";URI=spiffe://cluster.local/ns/demo/sa/sleep"
  }, 
  "origin": "127.0.0.1", 
  "url": "http://httpbin.demo:8000/get"
}
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/ip
RBAC: access denied
```

下面我们给安全规则的条件再加一个限制，加上请求的header

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: demo
spec:
 action: ALLOW
 rules:
 - from:
   - source:
       principals: ["cluster.local/ns/demo/sa/sleep"]
   - source:
       namespaces: ["demo"]
   to:
   - operation:
       methods: ["GET"]
       paths: ["/get"]
   when:
   - key: request.headers[x-rfma-token]
     values: ["test*"]
EOF
```

从下面的测试访问看，我们只有加上请求头x-rfma-token:test*才能访问到httpbin，否则是访问不通的。

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/get
RBAC: access denied[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-bhsk8 -n demo -c sleep -- curl http://httpbin.demo:8000/get -H x-rfma-token:test1
{
  "args": {}, 
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.demo:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Parentspanid": "4f565c230a76c4c8", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "d4d8fed86d2ea3f5", 
    "X-B3-Traceid": "c7cd5c2f28b112664f565c230a76c4c8", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/demo/sa/httpbin;Hash=8047b0dc92219d97bf966222da87d61ac7c857f8a562f487f7a44e936da499e0;Subject=\"\";URI=spiffe://cluster.local/ns/demo/sa/sleep", 
    "X-Rfma-Token": "test1"
  }, 
  "origin": "127.0.0.1", 
  "url": "http://httpbin.demo:8000/get"
}
```

安全策略里面主要存在以下几个字段，我们可以通过下面字段配置更丰富的安全访问策略


来源（source）：

* principal/namespace/ipBlock

操作（to）：

* host/method/path

条件（when）：

* request
* source/destination
