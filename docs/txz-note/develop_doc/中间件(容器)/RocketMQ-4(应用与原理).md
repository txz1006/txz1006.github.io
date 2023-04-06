### MQ的主要两种消费模式

- 集群消费：单个生产者，多个消费者，如果生产者发送10条信息到MQ，那么会由多个消费者均分这10条信息
- 广播模式消费：单个生产者，多个消费者，如果生产者发送10条信息到MQ，那么这多个消费者，每个服务都会收到10条信息

消费过程中的推拉问题：

- 使用DefaultMQPushConsumer创建消费者对象，那么Broker会主动将信息推送给消费者
- 使用DefaultMQPullConsumer创建消费者对象，那么消费者会主动的拉取信息

至于推拉的选择需要看具体的业务场景了

参考:https://www.cnblogs.com/wzh2010/p/16631097.html

### MQ的主要几种发送模式

- **同步发送：** 整个过程业务是阻塞等待的，消息发送之后等待 Broker 响应，得到响应结果之后再传递给业务线程。
- **异步发送：** 调用RocketMQ 的 Async API，消息生产者只要把消息发送任务放进线程池就返回给业务线程。所有的逻辑处理、IO操作、网络请求 都由线程池处理，处理完成之后，调用业务程序定义好的回调函数来告知业务最终的结果。
- **OneWay（单向）发送：** 只负责触发对消息的发送，发送出即完成任务，不需要对发送的状态、结果负责。
- **延迟发送：** 指定延迟的时间，在延迟时间到达之后再进行消息的发送。
- **批量发送：** 对于同类型、同特征的消息，可以聚合进行批量发送，减少MQ的连接发送次数，能够显著提升性能。
  参考：https://www.cnblogs.com/wzh2010/p/16629876.html

### MQ是如何存储消息的

我们已经知道broker是存储消息的主体容器了，但是发生一条信息到MQ，这条信息是怎么存储的？不同Topic之间的信息是如何隔离的？这些信息又是怎么做冗余备份的呢？下面我们就来了解下。

首先我们在MQ中创建Topic时，需要指定一个MessageQueue参数，这个参数的作用是这个Topic要创建几个MessageQueue，而MessageQueue的意义就是数据分片，也就是我们往MQ的Topic发送信息时，这条数据会存储到Broker中的Topic的一个分片中；也就是说broker中存储信息的数据结构是数据分片，而一个Topic的多个数据分片会分布式存储在不同的Broker中。

一般而言，MQ会自动计算分配一个Topic的分片数量，将他们分散在各个Broker节点中，当然也可以手动设置这个分配数量，但是要谨慎操作。

![image-20230317113040924](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303171130164.png)

**如果现在有一个生产者，发送了20条数据到MQ，那么这个数据会如何存储呢？**

以上图4个分片为例，生产者有可能会将这20条信息分别发送到分片1到4，每个分片5条数据。

但实际数据分配可能不会这么均匀，而是会根据不同的路由策略来发送，可能一些分片会多一些，另一些会少一些。

**生产者如何知道一个Topic的所有分片信息呢？**

答案是MessageQueue分片信息会随Topic信息一起注册到NameServer中，所以生产者确定发送的Topic之后，就可以获取到这个Topic的全部分片信息了。

**如果某个Broker出现故障了呢？还会继续往故障Broker上的分片发送数据吗？**

在RocketMQ中，Producer对象有一个开关：sendLatencyFaultEnable，如果将这个参数设置为true，那么在发送信息到MQ时，就会有一个自动容错机制，如果发送到的Broker出现了高延时、故障错误，那么在之后的一段时间内，再发送同样的信息时，则会自动回避这台Broker的访问。

### Broker是如何持久化数据的

**MQ日常存储形式是什么？**

Broker中的Topic数据切片在数据持久化时，会将收到的数据写入磁盘一个叫CommitLog的日志文件中，具体来说会将收到的数据依次按照时间顺序顺序写入到CommitLog文件中。

![image-20230320142327039](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303201423951.png)

每个CommitLog文件默认大小为1G，如果写满了会新建另一个CommitLog文件，继续记录存储数据。

CommitLog文件除了记录存储数据外，还会记录每条数据的行数（偏移量），方便后续数据查找使用。

**MessageQueue切片数据的存储形式是怎样的？**

之前我们知道Topic会分成多个MessageQueue切片分布式存在在不同Broker中，那么每个MessageQueue切片的数据是如何持久化记录的呢？

在broker中，每个MessageQueue切片会创建一个专门存储当前分片数据的日志文件，例如：MessageQueue0。

这个日志的位置格式如下所示：

```
$HOME/store/consumequeue/{topic}/{queueId}/{fileName}

其中{topic}对应topic的名称
{queueId}对应MessageQueue切片的id
{fileName}对应MessageQueue切片的日志名称
```

如果有个topic名字叫做：OrderMessageInfo，在一个broker上分了两个切片，那么这两个切片的日志路径可能是：

```
$HOME/store/consumequeue/OrderMessageInfo/MessageQueue0/ConsumeQueue0磁盘文件

$HOME/store/consumequeue/OrderMessageInfo/MessageQueue1/ConsumeQueue1磁盘文件
```

也就是说MessageQueue切片和ConsumeQueue日志文件是1对多的关系，一个切片可以产生多个日志文件。

每个ConsumeQueue日志文件会按照顺序记录每条数据信息在CommitLog文件中的位置序号，也就是偏移量，方便快速在CommitLog文件中定位到这条数据的位置。

![image-20230320174703385](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303201747513.png)

实际上在ConsumeQueue中存储的每条数据不只是消息在CommitLog中的offset偏移量，还包含了消息的长度，以及tag hashcode，一条数据是20个字节，每个ConsumeQueue文件保存30万条数据，大概每个文件是5.72MB。



**CommitLog如何让性能接近内存的？**

如果MQ写入一条数据到CommitLog文件中的耗时是10ms，此状况下，一个线程每秒能存储100条数据存储，100个线程能存储1万条数据。但是如果每条数据的写入时间减少为1ms，那么100个线程每秒能存储10万条数据。所以RocketMQ中，进行CommitLog日志持久化的方式是怎么样的呢？

答案是，通过OS的Page Cache机制（虚拟内存MMAP技术）和磁盘文件顺序写来提示CommitLog日志持久化性能的。

具体来说，一条数据要写入到CommitLog文件中，并不是直接同步线程写入，而是将数据信息写入到OS的Page Cache内存当中，之后会有另外一个线程异步将Page Cache内存中的数据按照顺序写入到磁盘CommitLog文件中。

而顺序写是IO中性能最高的。

但是这种异步刷盘方式，在数据写入到Page Cache内存后就会给生产者返回写入成功的ack了，如果这个时刻服务器故障了，那么Page Cache内存中的数据就会丢失。所以这种方式是给追求吞吐量的场景使用的，容忍数据一定量的丢失。

如果想要全部数据安全不丢失，就可以使用另外一种同步刷盘方式，broker存储一条数据会等到这条数据实际写入CommitLog文件后才会给生产者返回写入成功的ack了，但是这种方式的会导致性能下降很多。

两种持久化模式可以根据实际的应用场景来进行选择。

```
同步复制和异步复制是通过Broker配置文件里的flushDiskType参数进行设置的，这个参数可以被设置成 ASYNC_MASTER、SYNC_MASTER、SLAVE三个值中的一个。 实际应用中要结合业务场景，合理设置刷盘方式和主从复制方式，尤其是SYNC_FLUSH方式，由于频繁 的触发写磁盘动作，会明显降低性能。 通常情况下，应该把Master和Slave设置成ASYNC_FLUSH的刷盘方式， 主从之间配置成SYNC_MASTER的复制方式，这样即使有一台机器出故障，仍然可以保证数据不丢。
```

