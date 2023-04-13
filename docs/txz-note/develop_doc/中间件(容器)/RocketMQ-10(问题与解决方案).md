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

如何消费出现问题，则返回com.aliyun.openservices.shade.com.alibaba.rocketmq.client.consumer.listener.ConsumeOrderlyStatus#SUSPEND_CURRENT_QUEUE_A_MOMENT状态，稍后会再次消费这批数据。

### MQ如何设置数据过滤规则？

RocketMQ在发送消息的时候可以设置Tag和属性，消费者在订阅Topic时可以设置数据过滤规则，这个过滤规则会上传到Broker中，当Broker收到生产者发送的消息时，会根据这些过滤规则进行数据过滤，将符合条件的数据交给消费者进行消费。

首先，一条消息的设置的Tag和属性都可以当做过滤条件

![image-20230406173356086](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304061733130.png)

接着我们可以在消费的时候根据tag和属性进行过滤，比如我们可以通过下面的代码去指定，我们只要tag=TableA和tag=TableB的数据。

![image-20230406173418770](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304061734801.png)

或者我们也可以通过下面的语法去指定，我们要根据每条消息的属性的值进行过滤，此时可以支持一些语法，比如：

![image-20230406173436329](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304061734367.png)

RocketMQ还是支持比较丰富的数据过滤语法的，如下所示：

（1）数值比较，比如：>，>=，<，<=，BETWEEN，=；

（2）字符比较，比如：=，<>，IN；

（3）IS NULL 或者 IS NOT NULL；

（4）逻辑符号 AND，OR，NOT；

（5）数值，比如：123，3.1415；

（6）字符，比如：'abc'，必须用单引号包裹起来；

（7）NULL，特殊的常量

（8）布尔值，TRUE 或 FALSE

由于数据过滤是在Broker完成的，所以使用数据过滤会增加Broker的压力，但是会减少MQ和消费者之间的流量带宽，以及消费者集群的压力。

### MQ如何设置消息延时消费？

如果现在有一个使用场景，在我们正常的下单流程中如果用户看中的某件商品，那么就会开始下单，当用户点击下单后就会生成一个订单信息，此时订单状态为待支付，会有一个等待用户支付的倒计时周期，这个时间一般是15分钟，或者是30分钟；

如果用户直接完成支付了，那么就会更新订单状态为已支付，走后续的发货物流流程；但是如果用户在支付前犹豫了，不想要这个商品了，那么有两种情况，第一种是用户自己关闭当前订单，第二种是等待支付计时周期到期后，系统自动关闭订单。

![image-20230410104833269](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304101048629.png)

如果不使用延时消息的话，订单服务需要使用线程来定时扫描未关闭的待支付订单，如果发现支付计时到期了，就将这条订单状态更新为关闭，然后释放库存。

但是这样做的弊端也很明显，需要有线程一直不停的查询、判断，是十分消耗资源的，而且当订单数量达到一个数量级后，这个查询数据的耗时也会不断增加，所以这是一个不太好的解决方案。

如果这里我们引入RocketMQ，使用MQ的延时消息就能很好的处理这个问题。

我们可以在用户下单后，给MQ发送一条30分钟后执行的延时订单消息，这条订单消息只有在延时结束后才会被订单扫描系统消费，订单扫描系统根据这条订单编号查询订单的状态，如果订单已经是支付过，或者已关闭状态，就不需要处理了，如果订单还处于待支付状态，则需要更新订单状态即可。

![image-20230410105715925](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304101057976.png)

如何操作：
在生产者发送消息时，将消息设置为延时等级即可，MQ会自动完成消息的延时消费。

![image-20230410110924378](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304101109433.png)

在MQ中有一个延时等级配置，和消息重试等级配置类似，默认有18个等级，最大等级延时为2H，底层用ScheduledExecutorService实现，延时配置数据如下：

```
messageDelayLevel =1s 5s 10s 30s 1m 2m 3m 4m 5m 6m 7m 8m 9m 10m 20m 30m 1h 2h
```

上面示例代码将延时等级设置为3，代表这条消息会在10S后才可以消费。

我们在消费端也可以查看当前消息进入MQ的时间来判断是否延时消费。

![image-20230410111338716](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304101113765.png)



### MQ信息补充

**消息零丢失方案的补充**

之前我们给大家分析过消息零丢失方案，其实在消息零丢失方案中还有一个问题，那就是MQ集群彻底故障了，此时就是不可用了，那么怎么办呢？

其实对于一些金融级的系统，或者跟钱相关的支付系统，或者是广告系统，类似这样的系统，都必须有超高级别的高可用保障机制。

一般假设MQ集群彻底崩溃了，你生产者就应该把消息写入到本地磁盘文件里去进行持久化，或者是写入数据库里去暂存起来，等待MQ恢复之后，然后再把持久化的消息继续投递到MQ里去。

**提高消费者的吞吐量**

如果消费的时候发现消费的比较慢，那么可以**提高消费者的并行度**，常见的就是部署更多的consumer机器

但是这里要注意，你的Topic的MessageQueue得是有对应的增加，因为如果你的consumer机器有5台，然后MessageQueue只有4个，那么意味着有一个consumer机器是获取不到消息的。

然后就是可以增加consumer的线程数量，可以设置consumer端的参数：consumeThreadMin、consumeThreadMax，这样一台consumer机器上的消费线程越多，消费的速度就越快。

此外，还可以**开启消费者的批量消费功能**，就是设置consumeMessageBatchMaxSize参数，他默认是1，但是你可以设置的多一些，那么一次就会交给你的回调函数一批消息给你来处理了，此时你可以通过SQL语句一次性批量处理一些数据，比如：update xxx set xxx where id in (xx,xx,xx)。

通过批量处理消息的方式，也可以大幅度提升消息消费的速度。
