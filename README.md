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
Doris在Kubernetes中的部署方式为 hostNetwork，PodIP 即节点 IP，如此可避免BE节点重启BEIP发生变化需重新ADD BACKEND，保证了Doris服务的连续性。

目前存在一些限制因素：每个Kubernetes节点只能启动一个BE，且每个Kubernetes节点需要为doris预留监听端口，默认：doris-fe(8030、9010、9020、9030)、doris-be(8040、8060、9050、9060、9070)；

（当然，如果这些端口在k8s节点上已经被占用，你需要修改doris配置文件中的端口。）

如果您想自己编译Doris，可以参考这里 https://github.com/mfanoffice/k8s-doris.git

Doris在Kubernetes中的部署架构为 "1fe + 1be"，在此我们仍然建议您使用服务化方式部署Doris集群，这样可以更大程度的发挥Doris的性能。

如果您想禁用在Kubernetes上部署Doris，可以在values.yaml中修改：
```
doris_fe:
  enable: true 改为 false

doris_be:
  enable: true 改为 false
```
部署完DataEase后，在DataEase的web操作界面关联外部Doris集群即可。

### 2.2 Kettle
Kettle默认部署1个副本，如果您想修改它，可以在values.yaml中修改：
```
kettle:
  replicas: 1 改为其他数值
```
注意，一个同步任务只能由一个Kettle调度，所以增加Kettle的数量可以在同一时间内完成更多的同步任务。

### 2.3 DataEase
DataEase默认有两种外部访问方式：1. ingress， 2.NodePort 

您可以在values.yaml中

配置ingress的开关状态：
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
此环境使用StorageClass作为共享存储，默认为default，您可以根据自己的Kubernetes环境修改此名称：
```
common:
  storageClass: dataease 改为其他名称
```

## 3. 使用示例
### 3.1  下载helm chart包

访问 https://github.com/mfanoffice/dataease-helm.git

下载helm chart包 dataease-1.2.0，放置kuberneter环境；

或者git clone 然后自行打包：

```bash
git clone https://github.com/mfanoffice/dataease-helm.git
#可自行修改配置后再打包
helm package dataease-helm/
```

### 3.2 修改配置

解压helm chart包，修改values.yaml文件，对镜像版本和存储类按实际使用环境进项修改；

```bash
vi dataease-helm/values.yaml
```

### 3.3 安装


```bash
#创建一个命名空间
kubectl create ns de
#部署
helm install dataease dataease-1.2.x.tgz -f dataease-helm/values.yaml -n de
```

您可以时刻观察POD的状态,如果都为runing状态则POD启动完成
```bash
kubectl get pod
```

这里需要注意的是，dataease POD后台需要完成初始化操作，可以先观察日志等待完成后再继续操作。
```bash
kubectl logs -f dataease
```

### 3.4 配置Doris


Doris部署完后，没有将doris的be添加到fe中，接下来您需要手动执行添加动作：
```bash
#进入 mysql POD 10.168.1.11为doris-fe的IP地址，此IP也是Kubernetes环境中doris-fe POD所在的宿主机IP
kubectl exec -it mysql-0 -n de -- mysql -h10.168.1.11 -P9030 -uroot

#添加doris be，10.168.1.10为doris-be的IP地址，此IP也是Kubernetes环境中doris-be POD所在的宿主机IP，端口默认不修改。
ALTER SYSTEM ADD BACKEND "10.168.1.10:9050";

#创建DataEase需要的库
CREATE DATABASE dataease;

#为Doris添加root登录密码
SET PASSWORD FOR 'root' = PASSWORD('Password123@doris');

#查看添加状态 Alive: true 即为成功
SHOW PROC '/backends'\G;
```
### 3.5 配置DataEase


登录DataEase的web操作界面，完成最后的组件关联
```
浏览器访问http://10.168.1.10:30081
（这里使用NodePort方式访问，IP为Kubernetes节点IP，端口默认30081。）
用户名：admin
密码： dataease
```

#### 3.5.1 关联Doris服务：

系统管理--系统参数--引擎设置
```
Doris地址： 10.168.1.11
#10.168.1.11为doris-fe的IP地址，此IP也是Kubernetes环境中doris-fe POD所在的宿主机IP

数据库名称： dataease
#在上一步创建的库

用户名： root
密码： Password123@doris
#在上一步创建的root密码

Query Port： 9030
#默认端口，前提是您没有修改它

Http Port: 8030
#默认端口
```
填写完成点击“校验”成功，点击“保存”即可。

#### 3.5.2 关联Kettle服务：

系统管理--系统参数--Kettle设置--添加Kettle服务
```
Kettle地址： kettle
#"kettle" 是Kubernetes中kettle服务名，POD网络可以直接解析

端口： 18080
#默认端口，前提是您没有修改它

用户名： cluster
密码： cluster
#默认密码
```
填写完成点击“校验”成功，点击“保存”即可。


完成以上操作您已经在Kubernetes中配置完成了DataEase，接下来请尽情的使用它吧。

最后欢迎大家提issue!
