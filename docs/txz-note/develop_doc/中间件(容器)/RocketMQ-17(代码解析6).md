### Broker收到消息后是如何存储的

在前面的学习中，我们已经知道了在Broker中，会有一个CommitLog日志文件，记录所有Topic发送到当前Broker

分配的MessageQueue信息，同时每个MessageQueue会有一个CustomerQueue日志文件，记录当前分片接收的消息，联系上之前和Producer的交互流程，示意图如下所示：

![image-20230423155648283](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304231556330.png)

- customerQueue文件：记录该消费者已经消费的消息的偏移量。当消费者启动时，会从消费队列中读取最近已消费的消息的偏移量，并从该位置继续消费后续的消息，消费者返回ack后的偏移量就会记录在customerQueue文件中。
- indexFile文件：包含了消息的关键字信息以及在commitlog文件中的物理偏移量和消息大小，用于加速消息查询而创建的文件。消费者查询消息时可以通过关键字在索引文件中查找到对应的物理偏移量和消息大小，然后从commitlog文件中读取消息内容。
- CommitLog文件：一个顺序写入的日志文件，用于记录所有消息的数据和元数据。



那么下面我们开看看这些持久化流程是怎样的。

之前我们已经知道生产者组件中发送消息给Broker的请求码为SEND_MESSAGE，批量请求码为SEND_BATCH_MESSAGE，重试请求码为SEND_REPLY_MESSAGE。根据这些关键字我们可以找到Broker具体的处理请求代码位置。

![image-20230423170213432](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304231702481.png)

直接进行关键字搜索，在BrokerController#registerProcessor看到了处理请求的组件，和之前NameServer处理请求的方式一样。进入到SendMessageProcessor组件中，根据sendMessage方法名字直接持久化代码的位置：

![image-20230423170740559](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304231707593.png)

持久化存储是交给专门的组件来处理的，常规消息交给messageStore组件处理，事务消息交给transactionalMessageService处理。

我们在messageStore组件中看看常规消息是怎么持久化的，在messageStore组件的putMessage方法中，又调用了commitLog组件来持久化数据，

```java
PutMessageResult result = this.commitLog.putMessage(msg);
```

这个commitLog组件有两个实现类，如果开启了EnableDLegerCommitLog配置，则使用DLedgerCommitLog组件来进行持久化，这个逻辑和我们之前学习到的内容基本是一致的。

```java
if (messageStoreConfig.isEnableDLegerCommitLog()) {
    this.commitLog = new DLedgerCommitLog(this);
} else {
    this.commitLog = new CommitLog(this);
}
```

我们以常规消息为例看看CommitLog组件的putMessage方法都做了些什么：

首先是在写数据前进行了加锁，这样可以保证消息写入CommitLog时是串行写入的，不会有并发的问题。

```
putMessageLock.lock(); //spin or ReentrantLock ,depending on store config
```

其次putMessageLock是一个成员变量，有两种实现类，一种是基于ReentrantLock重入锁，另一种是基于AtomicBoolean的自旋锁，锁的选择基于配置参数而定。

加完锁后会使用MappedFile对象进行文件写入：

```
MappedFile mappedFile = this.mappedFileQueue.getLastMappedFile();
result = mappedFile.appendMessage(msg, this.appendMessageCallback);
```

具体来说是通过this.appendMessageCallback组件的doAppend方法进行的持久化写入，注意这里写入的只是MappedFile映射的内存空间，并没有直接把数据刷入磁盘。

后面还会涉及到批量消息的发送还是单条消息的发送，以及同步刷盘和异步刷盘的问题，大家可以先简单的看看，后面会详细说明。

![image-20230423173359323](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304231733373.png)

如果是异步刷盘这里会创建ByteBuffer.allocateDirect()零拷贝空间，消息会存入内存中，然后有线程定期将内存数据刷入CommitLog文件中。



### 一条消息写入CommitLog文件之后，如何实时更新索引文件？

目前我们只知道一条消息会在CommitLog组件进行持久化存储，但是之前我们说的customerQueue和indexFile呢？这两个文件又是什么时候持久化的？我们回到持久化消息组件DefaultMessageStore类中，在构造方法关注两个对象：一个是reputMessageService，另一个是dispatcherList。

```java
this.reputMessageService = new ReputMessageService();

this.dispatcherList = new LinkedList<>();
this.dispatcherList.addLast(new CommitLogDispatcherBuildConsumeQueue());
this.dispatcherList.addLast(new CommitLogDispatcherBuildIndex());
```

为什么关注着两个对象呢？因为这个reputMessageService组件的主要功能就是异步转发消息持久化到customerQueue和indexFile文件用的，而下面的dispatcherList列表存放的两个元素对象，一个就是持久化ConsumeQueue用的，另一个是持久化indexFile用的，从其名称就可以知道两个对象的作用。

代码的启动入口在DefaultMessageStore#start方法中，由BrokerController#start触发，具体执行代码如下所示：

```java
this.reputMessageService.setReputFromOffset(maxPhysicalPosInLogicQueue);
this.reputMessageService.start();
```

reputMessageService组件执行start方法后会开启一个线程，线程每隔一毫秒就会执行一个方法。

![image-20230424131116634](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241311674.png)

这个doReput()会扫描CommitLog对象中消息信息，将其转发到customerQueue和indexFile中。在doReput()方法中，主要关注代码如下：

![image-20230424132734682](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241327721.png)

checkMessageAndReturnSize方法的主要作用是检查返回正常的消息数据，如果数据条数大于0则执行doDispatch方法，这个方法就会执行我们之前提到的CommitLogDispatcherBuildConsumeQueue和CommitLogDispatcherBuildIndex组件的dispatch转发方法，doDispatch方法代码如下图所示：

![image-20230424133022918](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241330450.png)

接着我们来看一看CommitLogDispatcherBuildConsumeQueue组件的实现，其实逻辑非常简单，就是根据消息在MessageQueue的id和Topic信息查到完整的消息映射对象ConsumeQueue，这里的ConsumeQueue对象可以理解为和磁盘中当前Topic的某个ConsumeQueue文件一一对应，然后通过putMessagePositionInfoWrapper方法将消息数据持久化到磁盘中。

![image-20230424133624557](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241336590.png)

而CommitLogDispatcherBuildIndex的持久化主要在indexService组件中完成：

![image-20230424142512472](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241425518.png)

到目前为止的持久化流程图如下：

![image-20230424142117328](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241421377.png)



### RocketMQ的同步刷盘和异步刷盘是怎么实现的？

在CommitLog#putMessage方法中，我们之前说了消息还只是存入了内存中，并没有存入磁盘文件中，所里这里我们详细的学习一下RocketMQ是怎么持久化的。

我们直接查看CommitLog#putMessage方法的最后两行，这里有一条消息同步和刷盘的两个方法。

```java
//将内存中的消息持久化到磁盘中
handleDiskFlush(result, putMessageResult, msg);
//将消息同步给从broker
handleHA(result, putMessageResult, msg);
```

关于消息同步给Slave broker的handleHA方法，这里就不详细看了，因为涉及到高可用的相关内容，如果感兴趣的话可以自行研究一下。我们这里主要看看同步刷盘和异步刷盘是怎么实现的。

![image-20230424152242496](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304241522550.png)

在handleDiskFlush中方法，根据持久化配置的FlushDiskType类型来判断是走同步刷盘还是异步刷盘，其中同步刷盘主要使用GroupCommitService组件的putRequest方法来完成，入参是构建的一个GroupCommitRequest对象，然后通过调用GroupCommitRequest的waitForFlush方法等待消息的持久化完成。

上面GroupCommitService组件实际上有两种实现，在CommitLog的构造方法中，这里同步刷盘使用的是GroupCommitService组件。

```java
if (FlushDiskType.SYNC_FLUSH == defaultMessageStore.getMessageStoreConfig().getFlushDiskType()) {
    this.flushCommitLogService = new GroupCommitService();
} else {
    this.flushCommitLogService = new FlushRealTimeService();
}
```

GroupCommitService组件是一个线程对象，putRequest方法只是将消息请求放入到列表中存储，然后线程对象每隔10毫秒会循环执行一次doCommit()方法，这个方法才是最终处理同步刷盘的逻辑。方法的核心代码如下：

```java
CommitLog.this.mappedFileQueue.flush(0);
```

通过查看该方法的一层层的实现，可以知道最终刷盘使用的是MappedByteBuffer的force方法：

```java
this.mappedByteBuffer.force();
```

这个MappedByteBuffer是java.nio包下的API，调用force()方法会将MappedByteBuffer中的内存数据强制写入到磁盘文件中，写入成功就算是同步刷盘成功了。

如果是异步刷盘呢？通过上述代码可以知道执行了**flushCommitLogService.wakeup()**，wakeup是唤醒的意思，也就是说flushCommitLogService对象也是一个线程对象，在上面的代码中我们知道异步刷盘实际的实现类为FlushRealTimeService。

在FlushRealTimeService的run方法中，是直接使用**CommitLog.this.mappedFileQueue.flush(0)**方法进行刷盘的，而且不会等待刷盘是否成功或者失败，其中有几个关键的参数可以注意下：

- flushIntervalCommitLog commitlog 刷盘频率，默认为 500ms
- flushCommitLogLeastPages 一次刷盘至少需要脏页的数量，默认 4 页，针对 CommitLog 文件
- flushCommitLogThoroughInterval commitlog 两次刷盘的最大间隔，如果超过该间隔，将忽略 flushCommitLogLeastPages 要求直接执行刷盘操作，默认为 10s



最后总结一下，无论是同步刷盘还是异步刷盘都是使用的子线程进行的持久化，但是同步刷盘需要等待子线程持久化完成后才会返回结果，而异步刷盘则不需要返回结果，最大刷盘的时间间隔是10秒，默认间隔为500毫秒。



### 当Broker上的数据存储超过一定时间之后，磁盘数据是如何清理的？

Broker作为一个可以存储数据的中间件，如果不停的接收数据存储到磁盘文件上，那么磁盘始终会有用完的一天，所以MQ一定会有一个清理磁盘文件的功能，将不用的数据文件给删除掉；下面我们来看看MQ是如果实现这个功能的。

前面我们已经知道MQ的持久化CommitLog日志是存储在${ROCKETMQ_HOME}/store/commitlog下的，每个文件的默认大小是1个G，一个文件写满了之后就会创建的新的文件，而文件名是文件中的第一个偏移量的，如果文件名不足20位，会通过左位补0来处理，示例如下图所示：

![image-20230425100938040](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304251009136.png)

这里可以先给大家说一下，Broker默认启动后会有一个后台线程，线程会定期检查CommitLog、ConsumeQueue、indexFile日志文件的数量，因为这些日志文件会随着写入数据不断增加，而创建越来越多的日志文件。

比如超过72小时之后的旧日志文件，就会被这个定时线程任务给清理掉，也就是说broker默认会保留3天的日志文件数据，当然这个保留天数我们可以通过配置参数fileReservedTime来调整，这个参数默认值为72。

在DefaultMessageStore组件中，我们可以找到这里定时线程任务组件执行的代码：

```java
public void start() throws Exception {
	this.addScheduleTask();
}

private void addScheduleTask() {

    this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {
        @Override
        public void run() {
            //定期删除文件
            DefaultMessageStore.this.cleanFilesPeriodically();
        }
    }, 1000 * 60, this.messageStoreConfig.getCleanResourceInterval(), TimeUnit.MILLISECONDS);
    
    
}
```

在cleanFilesPeriodically方法中又分别执行了cleanCommitLogService和cleanConsumeQueueService的run方法。

```java
private void cleanFilesPeriodically() {
    this.cleanCommitLogService.run();
    this.cleanConsumeQueueService.run();
}
```

注意，这里是直接执行的run方法，不是启动的线程任务。

其中cleanCommitLogService删除日志时有两个个条件，满足其中一条即可触发CommitLog日志删除。

条件1：删除时间固定为晚上4点钟

条件2：磁盘占用超过75%

满足一个条件就会将保存时间超过72小时的日志给删除掉。

而cleanConsumeQueueService组件会根据最小偏移量来删除ConsumeQueue日志和index日志。

整体交互图如下所示：

![image-20230425112938892](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304251129956.png)









