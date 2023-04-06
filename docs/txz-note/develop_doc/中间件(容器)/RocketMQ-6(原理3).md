### 消费组概念

在MQ的概念中，一个Topic会分为多个MessageQueue数据分片，分布式存储到多个主Broker中。

在消费Topic中的数据时，RocketMQ中存在一个消费组的概念，每个消费组可以包含多个消费者节点，消费组需要订阅一个Topic才能接受到MQ的信息，一个Topic可以被一个或多个消费组订阅，一个消费组也可以订阅一个或多个Topic。

```java
//消费者单参构造的参数为消费组名称
DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("meiwei-consumer-simple-sync-push");
```

两个消费组订阅同一个Topic示意图：

![image-20230323143302987](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303231433582.png)

在上图的基础上，如果生产者发送一条信息到MQ中，那么每个消费组都会收到这条信息，至于会被哪个消费节点具体接收到，得根据具体的路由策略来决定。

上述消费模式是属于集群消费模式。RocketMQ中还有广播模式、负载均衡模式两种常用的模式，其中，广播模式会让每个消费组的每个消费节点都能消费这条数据，次模式使用场景较少；而负载均衡模式是RocketMQ的默认消费模式，具体来说就是，同一条信息只会发给某个消费组的某个消费节点来消费。

### 消费者是如何消费一条MQ信息的

#### pull模式和push模式

先说一下消费者获取MQ消息的两种方式：pull模式和push模式。两种模式需要考虑具体的使用场景来具体选择；两种模式虽然一推一拉，但是本质上都是消费者主动发送请求从Broker中获取数据。

区别是Push模式，需要消费者主动和Broker构建长连接，Broker会有线程专门处理这个消费者请求，如果Broker中没有收到生产者发送来的数据，就会将这个消费者线程挂起，默认是15S，如果期间Broker检查到有消息发送过来，就会立即将这条信息从长连接通道发送给消费者。

所以，Push模式适合对延迟要求较高、需要快速响应的场景，但消费者需要保证机器的稳定性和可靠性，以免出现消费者挂掉的情况导致消息丢失。同时，还需要避免消费者的处理能力跟不上消息的推送速度，导致消息积压。

Push模式消费者代码如下：

```java
//在Push模式中，消费者需要注册一个消息监听器，当有新的消息到达时，RocketMQ会自动调用监听器的回调函数进行消息处理。
public class PushConsumer {
    public static void main(String[] args) throws Exception {
        // 实例化一个默认的Push消费者
        DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("push_consumer_group");
        // 指定NameServer地址
        consumer.setNamesrvAddr("localhost:9876");
        // 订阅需要消费的Topic和Tag
        consumer.subscribe("test_topic", "*");
        // 注册消息监听器
        consumer.registerMessageListener(new MessageListenerConcurrently() {
            @Override
            public ConsumeConcurrentlyResult consumeMessage(List<MessageExt> msgs,
                ConsumeConcurrentlyContext context) {
                for (MessageExt msg : msgs) {
                    // 处理消息
                    System.out.println(new String(msg.getBody()));
                }
                // 返回消息处理结果
                return ConsumeConcurrentlyResult.CONSUME_SUCCESS;
            }
        });
        // 启动消费者实例
        consumer.start();
        System.out.printf("Consumer Started.%n");
    }
}
```

而Pull模式中，消费者需要周期性地向Broker发起拉取消息的请求，主动获取可用的消息并进行处理。由于消息的拉取是由消费者自己控制的，因此可以更灵活地控制消息的消费速率和处理方式。但是，由于消费者需要周期性地主动去拉取消息，因此可能会出现一定程度的延迟。

```java
//Pull模式中，消费者调用pullBlockIfNotFound()方法来从指定的消息队列中拉取消息。这个方法会一直阻塞直到有新的消息可以被拉取。
public class PullConsumer {
    public static void main(String[] args) throws Exception {
        // 实例化一个默认的Push消费者
        DefaultMQPullConsumer consumer = new DefaultMQPullConsumer("pull_consumer_group");
        // 指定NameServer地址
        consumer.setNamesrvAddr("localhost:9876");
        // 启动消费者实例
        consumer.start();
        // 指定需要订阅的Topic和Tag
        String topic = "test_topic";
        String tag = "*";
        // 从指定的消息队列中拉取消息，并打印消息内容
        List<MessageExt> msgs = consumer.pullBlockIfNotFound(topic, tag,
            rocketmq.common.protocol.heartbeat.MessageModel.CLUSTERING, 0, 32);
        for (MessageExt msg : msgs) {
            System.out.println(new String(msg.getBody()));
        }
        // 关闭消费者实例
        consumer.shutdown();
    }
}
```

了解了MQ的推拉模式后，下面我们来认识下Topic的数据分片MessageQueue和消费者的对应关系。

#### 分片与消费组对象关系

一般而言，Broker会将一个Topic的数据切片均分给一个消费组的所有机器。

如果一个Topic有4个数据分片，两两被分在两个主Borker中，若一个有两个消费节点的消费组订阅了这个Topic，那么很有可能将其中的数据分片0,1中的数据交给消费者1来处理，将分片2,3中的数据交给消费者2来处理。

![image-20230323162751310](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303231627388.png)

当消费节点出现机器宕机或者新增服务器时，Broker会根据消费者数量进行一个ReBalance自平衡操作。

如果消费节点2宕机了，那么Broker在自平衡后会将分片0,1中的数据也交给消费者1来处理。

如果新增了两个消费节点，那么Broker在自平衡后会将每个数据分片单独分给一个消费者。

当然这个关系不是一定固定这样的，Broker可能会根据消费者的消费能力和负载情况来调整对应关系。

#### 消费者如何响应消费进度

我们已经知道每个数据分片都对应有CustomerQueueLog日志，每个分片会维护一个CustomerOffset标记，代表当前分片的数据消费位置。

比如一个消费者要从分片0拉取数据，分片0中的数据从来没有被消费过，那么CustomerOffset就会为0，Broker就会根据CustomerQueueLog日志的第一条地址引用，去CommitLog中查询完整的数据信息，然后将数据发送给消费者，消费者完成消费回应给Broker，那么CustomerOffset标记就会+1，下次再消费就会从第二条数据获取。

除了每个分片会有单独的CustomerOffset记录外，每个消费组也会维护一个CustomerOffset记录，本地维护一份ConsumerOffset，用于记录自己已经消费的消息在队列中的偏移量。消费者会定期将更新后的ConsumerOffset提交到RocketMQ集群中，这样就能够确保消费者的消费位置信息不会丢失。

消费组中的每个消费者共享这个CustomerOffset记录。





1. **一般我们获取到一批消息之后，什么时候才可以认为是处理完这批消息了？是刚拿到这批消息就算处理完吗？还是说要对这批消息执行完一大堆的数据库之类的操作，才算是处理完了？**

    根据数据重要性区分：  如果不能丢失，则必须这批数据处理完，并且提交消费进度之后，才能算处理完成；  如果允许丢失，则接收到数据之后，可以立即提交消费进度，后面慢慢处理数据 。

   

2. **如果获取到了一批消息，还没处理完呢，结果机器就宕机了，此时会怎么样？这些消息会丢失，再也无法处理了吗？**

   Consumer 重试，再次拉取数据，因为还没提交消费进度，拉取到的还是同一批数据，再处理一次即可。

   

3. **如果获取到了一批消息，已经处理完了，还没来得及提交消费进度，此时机器宕机了，会怎么样呢**

   Consumer 每次拉取到数据的时候，需要自行保证幂等性，避免重复对同一批数据执行操作。

   

4. **根据offset查询CommitLog中的完整数据时，需要磁盘IO吗？**

   当Broker收到消费者的请求时，它会首先确定消费者要消费的消息在CommitLog文件中的偏移量（即offset）。然后，Broker会根据这个偏移量计算出消息在文件中对应的物理地址，并使用内存映射技术将这部分数据读入内存。这样，消费者就可以直接从内存中获取消息，而无需进行磁盘IO操作。



