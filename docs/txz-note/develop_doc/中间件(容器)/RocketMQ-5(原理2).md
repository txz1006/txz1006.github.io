### **基于DLedger技术的Broker主从同步原理**

之前，我们讲了Broker是基于CommitLog日志来进行持久化的，那在一个分布式的Broker集群中，持久化规则大概是这样的。

![image-20230321165343190](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303211653243.png)

**基于DLedger技术替换Broker的CommitLog**

基于DLedger技术，Broker集群可以实现高可用架构，当主Broker宕机后可以自动的从Slave节点当中选举一个节点成为新的主节点。基于这种模式，DLedger技术本身就有一个CommitLog机制，所以完全可以使用DLedgerCommitLog日志来代替CommitLog日志进行持久化。

![image-20230321170849672](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303211708725.png)

**DLedger是如何基于Raft协议选举Leader Broker的**

如果我们使用DLedger技术，那么DLedger是如何基于Raft协议选举Leader Broker的呢？

我们以上面三个节点为例，Broker1为主节点，Broker2和Broker3是从节点，当MQ三个Broker启动时就会开选举主Broker，选举是基于Raft协议实现的。

大概的逻辑是，Broker1、2、3会同时进入一个等待时间，每个节点的等待时间是随机不同的。如果Broker1率先结束休眠，就会给自己节点投票，让Broker1变为候选者节点（任期设置为1），然后给其他节点发起投票 RPC 信息请求，请它们选举自己为领导。

Broker2和Broker3在等待中收到Broker1的请求后，由于在Broker1的任期中还未投过票，所以就会把选票投给节点 A，并增加自己的任期编号。

Broker1收到Broker2和Broker3的两个投票，得到了大多数节点的投票(一般是机器数/2+1的量)，从候选者成为本届任期内的**新的领导者**，也就是主Broker节点。

之后主Broker节点会定期向所有从节点发送心跳请求，从节点会回应心跳请求告诉主节点自己是正常的。

主从关系构建起来后，Broker1就负责接收数据，Broker2和Broker3负责从Broker1节点同步数据。



在RocketMQ中DLedger技术被封装为DLedgerServer对象，负责主从同步和故障转移。

Raft协议可以参考：https://mp.weixin.qq.com/s/nkWPwvHZxfhr-4B3K34akQ



**DLedger是如何基于Raft协议进行多副本同步的**

Broker1主节点接收到生产者发送的数据后，开启数据同步两阶段走，一个是uncommitted阶段，另一个是committed阶段。

当主节点收到生产者发送的数据后，会将数据标记为uncommitted状态，之后通过DLedgerServer对象将数据同步给从节点。

从节点收到同步的数据后会给主节点回应一个ack信息，当**主节点收到数量过半的从节点返回的ack信息**后，就可以将该条数据标记位committed状态，进而进行持久化。

![image-20230322173443560](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303221734627.png)

**如果Leader Broker崩溃了怎么办**

如果Broker1节点故障了，那么DLedgerServer对象就会使用Raft协议选举出新的主节点。流程如下：

当Broker2和3没有收到主节点Broker1的心跳信息时，达到一定条件时，就会重新选举新的主节点。

首先，Broker2和3会再次进入随机休眠时长，休眠时间短的节点会率先苏醒，将自己设置为候选者，这里我们可以假定是Broker2先苏醒。然后Broker2向集群中发送投票RPC请求，Broker1故障没有回应，Broker3还处于随机休眠时长中，当收到Broker2的投票信息后就会投票给Broker2，这样Broker2会收到2票，成为新的主节点接收生产者发送的数据。

![image-20230322175602182](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303221756252.png)

思考题：如果主Broker节点与从节点之间的网络被隔断为两个分区，出现脑裂问题如何处理？
