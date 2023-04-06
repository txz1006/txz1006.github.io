### 如何MQ消费端数据库挂了需要如何处理？

现在有这样一个场景，就是订单系统通过MQ给下游系统发送了一条订单消息，比如这个下游系统是物流系统，但是物流系统的数据库出了问题，导致消费订单消息无法成功完成。

无法正常消费订单数据，也就无法给MQ返回正常消费消息的ACK，所以MQ会进行重试发送这条订单消息给物流系统；触发MQ的重试机制：当消费者没有正常消费消息时，需要给MQ返回一个消息重试的ACK。

```java
//重试消费ACK
com.aliyun.openservices.ons.api.Action#ReconsumeLater
//正常消费ACK
com.aliyun.openservices.ons.api.Action#CommitMessage

```

当MQ收到Action#ReconsumeLater的回应后，就会按照MQ的重试规则进行消费重试。

默认情况下MQ的重试规则最多有16次，但是每次重试的间隔时长不同：

```
//第一次重试是1s后，下一次是5s后，再下一次是10s后，依次向后排列
messageDelayLevel=1s 5s 10s 30s 1m 2m 3m 4m 5m 6m 7m 8m 9m 10m 20m 30m 1h 2h
```

这个重试规则我们也可以根据自己实际的业务自行更改配置。

### RocketMQ是如何实现重试机制的？

当MQ收到Action#ReconsumeLater的回应后，是如何重新消费这条消息呢？

在MQ内部，会给每个消费组创建一个重试队列，如果消息的状态被返回ReconsumeLater状态，那么这条消息就会被放入重试队列中。

如果消费组名称为VoucherConsumerGroup，则对应重试队列为%RETRY%VoucherConsumerGroup。

MQ会记录每条消息的重试次数，以此来判断每条消息下一次的重试时间。

### 如果重试16次了还没有正常消费消息怎么办？

如果16次重试中的某一次消费成功了，那自然就可以处理下一条数据了，但是如果重试了16次，消费者服务还未恢复正常呢？

这就需要MQ提供一个存储重试失败的地址，这就是死信队列。

每个Topic的消费组都有一个死信队列，如果消费组名称为VoucherConsumerGroup，则对应死信队列为%DLQ%VoucherConsumerGroup，重试16次后还未成功消费的消费就会放到这里。

我们通常可以新开一个线程，订阅这个死信队列，可以再尝试消费其中的数据，又或者将其中的数据落库，按照积累数量定时通知人工进行补偿处理。

### 如果MQ消息有先后顺序，出现消费乱序怎么办？

比如，使用canal订阅mysql的binlog，然后写入到MQ，再由消费端同步主库数据信息。

由于是一条条的SQL解析执行，所以SQL的消费顺序就很重要。

那么出现SQL消费乱序的原因是什么呢？我们知道对于各Topic，MQ会将其分为多个MessageQueue分片分布式存储到多个Broker节点中，如果相邻的两条SQL被分到不同的MessageQueue分片，那么这两条SQL很可能会被不同的消费节点同时执行，这种情况下哪条SQL会先写入到数据库中是不一定的。类似于并发线程处理有前后依赖的数据，这样就容易出现消费数据顺序混乱的情况。

解决方案：

方式一：使用单分区模式，即Topic只有一个数据分片，那么数据写入MQ，和消费者消息消息，都是从同一个分片队列中读写数据；这样可以保证数据的顺序性。
```java
DefaultMQProducer producer = new DefaultMQProducer("producer_group_name");
producer.setNamesrvAddr("localhost:9876");
producer.setCreateTopicKey("AUTO_CREATE_TOPIC_KEY");

// 设置Topic的队列数为1，即单分区模式
MessageQueueSelector selector = new MessageQueueSelector() {
    @Override
    public MessageQueue select(List<MessageQueue> mqs, Message msg, Object arg) {
        return mqs.get(0);
    }
};
producer.send(msg, selector, null, 1);
```

方式二：根据数据表名，或者同一订单编号进行hash计算，保证同一类型数据进入同一数据分片中，这样可以让同一类型的数据只会被同一个消费者顺序消费。

```
producer.send(msg, new MessageQueueSelector() {
    @Override
    public MessageQueue select(List<MessageQueue> mqs, Message msg, Object arg) {
        Long orderId = (Long)arg;   //获取订单id
        long index = id % mqs.size();  //对订单id取余，选择分片序号
        return mqs.get(index);   //返回指定分片对象
    }
}, orderId);
```

消费者单线程顺序消费：

![image-20230406170423696](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304061704155.png)

使用的是MessageListenerOrderly这个东西，他里面有Orderly这个名称。

也就是说，Consumer会对每一个ConsumeQueue，都仅仅用一个线程来处理其中的消息。

比如对ConsumeQueue01中的订单id=1100的多个binlog，会交给一个线程来按照binlog顺序来依次处理。否则如果ConsumeQueue01中的订单id=1100的多个binlog交给Consumer中的多个线程来处理的话，那还是会有消息乱序的问题。
