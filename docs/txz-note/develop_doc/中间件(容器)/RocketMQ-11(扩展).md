### MQ如何使用消息轨迹追踪

MQ有一个轨迹追踪的功能，可以记录一条消息何时进入的MQ，何时被消费的，耗时多少，生产机器和消费机器的信息等等。

如何使用：

首先在Broker节点中开启配置：**traceTopicEnable=true**和**traceTopicName=RMQ_SYS_TRACE_TOPIC**，指定Topic的轨迹信息都发送到RMQ_SYS_TRACE_TOPIC这个Topic中。

然后在生产者发送消息时开启记录参数：

```
//方式1，构造第二个参数为enableMsgTrace
DefaultMQProducer producer = new DefaultMQProducer("test_topic", true);

//方式2
// 设置 trace 上下文信息
message.putUserProperty("_TRACE_ID", "123456");
message.putUserProperty("_TRACE_SYS_FLAG", String.valueOf(1));
```

如果我们想要查询消息轨迹，也很简单，在RocketMQ控制台里，在导航栏里就有一个消息轨迹，在里面可以创建查询任务，你可以根据messageId、message key或者Topic来查询，查询任务执行完毕之后，就可以看到消息轨迹的界面了，

### 消费者数据库宕机导致MQ数据积压怎么办

**情况一**：如果MQ数据数据不重要，可以紧急修改消费者代码，只从MQ中获取数据，不做任何业务处理，把MQ的数据丢弃掉。

**情况二**：根据Topic的MessageQueue数据分片数量来扩展消费者数量，比如某个Topic的MessageQueue有20个，默认消费者数量有4个，那么每个消费者会对应5个MessageQueue的数据消费。这种情况下可以将消费者数量增加到20台，和MessageQueue数量保持一比一关系，但是需要考虑到消费者的数据库等依赖组件是否可以抗的住20台机器的同时写入流量。

这里补充一下**MessageQueue好消费者数量对应关系**

一个消费者可以对应多个MessageQueue ，但是一个MessageQueue 只能对应一个消费者。

Consumer 在拉取消息之前，需要对 MessageQueue 进行负载操作。RocketMQ 使用一个定时器来完成负载操作，默认每间隔 20s 重新负载一次。

**平均负载策略**：

把消费者进行排序；

- 计算每个消费者可以平均分配的 MessageQueue 数量；
- 如果消费者数量大于 MessageQueue 数量，多出的消费者就分不到；
- 如果不可以平分，就使用 MessageQueue 总 数量对消费者数量求余数 mod；
- 对前 mod 数量消费者，每个消费者加一个，这样就获取到了每个消费者分配的 MessageQueue 数量。

**循环分配策略:**

这个很容易理解，遍 历 消费者，把 MessageQueue 分一个给遍历到的消费者，如果 MessageQueue 数量比消费者多，需要进行多次遍历，遍历次数等于 （MessageQueue 数量/消费者数量）

**自定义分配策略：**

这种策略在消费者启动的时候可以指定消费哪些 MessageQueue。可以参考下面代码：

```
AllocateMessageQueueByConfig allocateMessageQueueByConfig = new AllocateMessageQueueByConfig();
//绑定消费 messageQueue1
allocateMessageQueueByConfig.setMessageQueueList(Arrays.asList(new MessageQueue("messageQueue1","broker1",0)));
consumer.setAllocateMessageQueueStrategy(allocateMessageQueueByConfig);
consumer.start();
```

**按照机房分配策略：**

这种方式 Consumer 只消费指定机房的 MessageQueue，如下图：Consumer0、Consumer1、Consumer2 绑定 room1 和 room2 这两个机房，而 room3 这个机房没有消费者，这种方式也需要消费者手动绑定机房信息：

```
AllocateMessageQueueByMachineRoom allocateMessageQueueByMachineRoom = new AllocateMessageQueueByMachineRoom();
//绑定消费 room1 和 room2 这两个机房
allocateMessageQueueByMachineRoom.setConsumeridcs(new HashSet<>(Arrays.asList("room1","room2")));
consumer.setAllocateMessageQueueStrategy(allocateMessageQueueByMachineRoom);
consumer.start();
```

**按照机房就近分配：**

跟按照机房分配原则相比，就近分配的好处是可以对没有消费者的机房进行分配。如下图，机房 3 的 MessageQueue 也分配到了消费者。源码所在类：AllocateMachineRoomNearby。

**一致性 Hash 算法策略：**

把所有的消费者经过 Hash 计算分布到 Hash 环上，对所有的 MessageQueue 进行 Hash 计算，找到顺时针方向最近的消费者节点进行绑定

**情况三**：如果业务Topic的MessageQueue 数量很少（比如4个），那么可以临时修改消费者代码，将MQ积累的数据临时写入到一个新的Topic中，这个新Topic的MessageQueue 数量很多，比如20个，那么再增加20台消费者去消费这个新Topic 的数据。

### MQ集群挂了怎么办

如果整个MQ集群挂掉了，生产者业务会直接不可用吗，可不可以增加容错性，保证生产者在MQ集群挂掉的情况下也可以正常工作。

对于这种情况，可以给生产者做一个对于MQ的降级熔断功能，如果连续多个订单发送MQ失败后，就直接触发熔断，之后的一段时间内直接降级不再发送MQ消息，将原本发送MQ的消息持久化，可以存到数据库中，或者写到本地文件中；然后需要有线程要不停尝试发送消息到MQ，一旦MQ集群恢复了，那么就可以把持久化的数据查出来再写入到MQ中。

