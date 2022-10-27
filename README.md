# Helm Chart 部署 DataEase
## 1. 部署方式
此安装包支持选择部署模式：“精简模式” 和 “集群模式”；

精简模式下仅部署 dataease 和 MySQL，集群模式下将部署 dataease、doris-fe、doris-be、kettle、mysql。

默认为 simple 模式。

在 values.yaml 中修改：
```
DataEase:
  enabled: true
  engine_mode: cluster或simple
```

## 2. 组件说明
### 2.1 Doris
Doris 在 Kubernetes 中的部署方式为 hostNetwork，PodIP 即节点 IP，如此可避免BE节点重启BEIP发生变化需重新 ADD BACKEND，保证了 Doris 服务的连续性。

目前存在一些限制因素：每个 Kubernetes 节点只能启动一个BE，且每个 Kubernetes 节点需要为 Doris 预留监听端口，默认：doris-fe(8030、9010、9020、9030)、doris-be(8040、8060、9050、9060、9070)；

（当然，如果这些端口在 Kubernetes 节点上已经被占用，你需要修改 Doris 配置文件中的端口。）

如果您想自己编译 Doris，可以参考这里 https://github.com/mfanoffice/k8s-doris.git

Doris 在 Kubernetes 中的部署架构为 "1fe + 1be"，在此我们仍然建议您使用服务化方式部署 Doris 集群，这样可以更大程度的发挥 Doris 的性能。

如果你想禁用在 Kubernetes 上部署 Doris，可以在 values.yaml 中修改：
```
doris_fe:
  enable: true 改为 false

doris_be:
  enable: true 改为 false
```
部署完 DataEase 后，在 DataEase 的 web 操作界面关联外部 Doris 集群即可。

### 2.2 Kettle
Kettle 默认部署1个副本，如果您想修改它，可以在 values.yaml 中修改：
```
kettle:
  replicas: 1 改为其他数值
```
注意，一个同步任务只能由一个 Kettle 调度，所以增加 Kettle 的数量可以在同一时间内完成更多的同步任务。

### 2.3 DataEase
DataEase 默认有两种外部访问方式：1. ingress， 2.NodePort 

你可以在 values.yaml 中配置 ingress 的开关状态：
```
ingress:
  enabled: true或false
```
也可以配置NodePort的端口：
```
common:
  dataease:
    nodeport_port: 30081 改为其他端口
```
### 2.4 存储
此环境使用 StorageClass 作为共享存储，默认为 default，您可以根据自己的 Kubernetes 环境修改此名称：
```
common:
  storageClass: dataease-sc 改为其他名称
```

## 3. 部署步骤
### 3.1  下载 helm chart 包

访问 https://github.com/mfanoffice/dataease-helm.git

下载 helm chart 包 dataease-1.x.x，放置 Kubernetes 环境的服务器中；

或者git clone 然后自行打包：

```bash
git clone https://github.com/mfanoffice/dataease-helm.git
#可自行修改配置后再打包
helm package dataease-helm/
```

### 3.2 修改配置

解压 helm chart 包，修改 values.yaml 文件，对存储类按实际使用环境进行修改；

```bash
vi dataease-helm/values.yaml

engine_mode: cluster或simple
storageClass: dataease-sc 改为其他名称
```

### 3.3 安装


```bash
#创建一个命名空间
kubectl create ns de
#部署
helm install dataease dataease-1.x.x.tgz -f dataease-helm/values.yaml -n de
```

您可以时刻观察 Pod 的状态,如果都为 running 状态则 Pod 启动完成
```bash
kubectl get pod
```

这里需要注意的是，dataease 的 Pod 后台需要完成初始化操作，可以先观察日志等待完成后再继续操作。
```bash
kubectl logs -f dataease
```

### 3.4 配置Doris


Doris 部署完后，没有将 Doris 的 be 添加到 fe 中，接下来您需要手动执行添加动作：
```bash
#进入 MySQL Pod 10.168.1.11 为 doris-fe 的 IP 地址，此 IP 也是 Kubernetes 环境中 doris-fe Pod 所在的宿主机 IP
kubectl exec -it mysql-0 -n de -- mysql -h10.168.1.11 -P9030 -uroot

#添加 doris-be，10.168.1.10 为 doris-be 的 IP 地址，此 IP 也是 Kubernetes 环境中 doris-be Pod 所在的宿主机 IP，端口默认不修改。
ALTER SYSTEM ADD BACKEND "10.168.1.10:9050";

#创建 DataEase 需要的库
CREATE DATABASE dataease;

#为 Doris 添加 root 登录密码
SET PASSWORD FOR 'root' = PASSWORD('Password123@doris');

#查看添加状态 Alive: true 即为成功
SHOW PROC '/backends'\G;
```
### 3.5 配置 DataEase


登录 DataEase 的 web 操作界面，完成最后的组件关联
```
# NodePort 方式访问
浏览器访问 http://10.168.1.10:30081
（IP 为 Kubernetes 节点 IP，端口默认 30081）

# Ingress 方式访问
浏览器访问 http://demo.apps.dataease.com
(需要手动做域名映射，默认域名：demo.apps.dataease.com)

用户名：admin
密码： dataease
```

#### 3.5.1 关联 Doris 服务：

系统管理--系统参数--引擎设置
```
Doris地址： 10.168.1.11
#10.168.1.11 为 doris-fe 的 IP 地址，此 IP 也是 Kubernetes 环境中 doris-fe Pod 所在的宿主机 IP

数据库名称： dataease
#在上一步创建的库

用户名： root
密码： Password123@doris
#在上一步创建的 root 密码

Query Port： 9030
#默认端口，前提是您没有修改它

Http Port: 8030
#默认端口
```
填写完成点击 “校验” 成功，点击 “保存” 即可。

#### 3.5.2 关联 Kettle 服务：

系统管理--系统参数--Kettle 设置--添加 Kettle 服务
```
Kettle地址： kettle
#"kettle" 是 Kubernetes 中 kettle 服务名，Pod 网络可以直接解析

端口： 18080
#默认端口，前提是您没有修改它

用户名： cluster
密码： cluster
#默认密码
```
填写完成点击“校验”成功，点击“保存”即可。


完成以上操作您已经在 Kubernetes 中配置完成了 DataEase，接下来请尽情的使用它吧。

最后欢迎大家提 issue!
