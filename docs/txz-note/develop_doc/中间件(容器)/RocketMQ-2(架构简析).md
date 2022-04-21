RocketMQ-2(架构简析)

### RocketMQ架构组成

#### 1.信息存储节点Broker

RocketMQ中间件中存储信息的主体进程是Borker对象，下面我们来了解这个Broker的架构

**Broker对象如何存储海量消息数据**

Broker可以进行集群部署，让每个Broker都承担存储一部分数据，并会将这些数据写入磁盘，这样整个Broker集群对外表现为一个整体，可以接受大量的数据写入，就如果有1亿数据要放入MQ中，MQ的broker分了10个节点，每个节点就会接受1千万数据并落盘。

![image-20210329144544873](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329150305.png)

**如何保证Broker的高可用性**

如果某个Broker宕机了，那么MQ不就丢失了一部分数据了吗？

所以，为了保证Broker的高可用性，Broker节点除了组成集群外，每个Broker还至少会有一个从Broker节点，当主节点获取到新数据后，主 broker会会将这些数据同步给从broker中，这样每个主broker至少有一个数据备份节点，当主broker宕机时，从broker节点还能对外提供服务。

![image-20210329150246169](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329150246.png)

**如何确定数据发送到哪个broker中**

这就需要一个新的对象了，就是NameServer路由进程节点，NameServer在RocketMQ中被单独分离出来了，可以独立部署，并和broker节点类似支持集群部署，和broker集群不同的是每个NameServer节点存储的路由信息都是相同的，这样每个broker节点会将自己的信息注册到所有的NameServer节点中。

  上游系统要给MQ发送信息时，就会通过信息标记在NameServer中寻找目标Broker。

![image-20210329152349930](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329152350.png)

**消费者如何获取Broker中的信息**

RocketMQ对于消息的获取是消费者主动取Broker中拉取发送给自己系统的数据，这个过程中同样需要经过NameServer的路由，才能找到目标Broker节点，所以，NameServer可以认为是RocketMQ的门面。

![image-20210329153308268](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329153308.png)

#### 2.节点路由管理NameServer

NameServer是RocketMQ中的路由管理中心，每个NameServer会记录下所有Broker的地址信息，这样无论是生产者系统还是消费者系统，还是每个Broker节点本身都可以通过NameServer感知当前MQ的整体状态。

**NameServer如何工作的？**

首先每个Broker会将自己节点的定时信息发送给NameServer，让每个NameServer都有一份完整的Broker信息

![image-20210329155613168](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329155613.png)

之后，每个生产者系统和消费者系统会定期向NameServer发送请求，主动拉取所有的Broker路由列表信息，并在本地缓存这些信息。

![image-20210329160422020](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210329160422.png)

**NameServer如何监控节点是否存活？**

Broker节点把信息注册到NameServer后，之后会有一个心跳检查机制，每隔30S所有Broker就会发送一次心跳信息给NameServer，NameServer收到信息后会更新这个节点的最新存活状态。而NameServer则会每隔10S遍历一次所有的Broker状态，如果有Broker节点有120S没有发送心跳信息，那么NameServer就会认为这个节点宕机了，将这个节点信息改为宕机状态。

**生产者如何避免发送信息给已经宕机了的Broker？**

一般来说有两者方式常用：

1.在生产者发送信息给MQ时，拉取NameServer最新的路由信息，这样生产者就获取不到宕机Broker节点的地址

2.使用宕机Broker的从节点来接受请求数据

#### 3.Broker节点主从架构解析

**主Broker如何同步信息给从Broker？**

Broker主从节点的信息同步主要通过从节点定时主动从主节点拉取数据

**消费者是是从主Broker还是从Broker拉取数据？**

这个要视具体情况而定，比如主Borker达到了性能极限，那么就会从从节点来拉取数据；或者从节点同步信息过慢，那么就会从主节点拉取数据

**从Broker挂了对整个MQ有影响吗？**

影响不大，但是Broker的压力会集中到主Broker节点上

**主Broker挂了会自动切换从节点为主节点吗？**

在RocketMQ4.5版本前不会自动故障转移，需要运维人员手动处理重启

在RocketMQ4.5版本后，MQ引入了Dledger模块后，可以实现主节点挂后，会选择一个从节点升级为主Broker。