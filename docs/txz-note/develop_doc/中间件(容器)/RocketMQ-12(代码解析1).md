### 前提

从本章节开始，我们将要开始RocketMQ源码的学习，过程中需要跟随MQ消息的流转流程来剖析MQ各个功能的实现原理。

我们首先需要下载RocketMQ的源码，这里我用的版本是4.6.1，请根据自己的实际情况来选择具体的MQ版本学习。

https://github.com/apache/rocketmq/tree/rocketmq-all-4.6.1

### RocketMQ源码结构

RocketMQ的源码目录结构：

1. **broker**：顾名思义，这个里面存放的就是RocketMQ的Broker相关的代码，这里的代码可以用来启动Broker进程
2. **client**：顾名思义，这个里面就是RocketMQ的Producer、Consumer这些客户端的代码，生产消息、消费消息的代码都在里面
3. **common**：这里放的是一些公共的代码
4. **dev**：这里放的是开发相关的一些信息
5. **distribution**：这里放的就是用来部署RocketMQ的一些东西，比如bin目录 ，conf目录，等等
6. **example**：这里放的是RocketMQ的一些例子
7. **filter**：这里放的是RocketMQ的一些过滤器的东西
8. **logappender和logging**：这里放的是RocketMQ的日志打印相关的东西
9. **namesvr**：这里放的就是NameServer的源码
10. **openmessaging**：这是开放消息标准，这个可以先忽略
11. **remoting**：这个很重要，这里放的是RocketMQ的远程网络通信模块的代码，基于netty实现的
12. **srvutil**：这里放的是一些工具类
13. **store**：这个也很重要，这里放的是消息在Broker上进行存储相关的一些源码
14. **style、test、tools**：这里放的是checkstyle代码检查的东西，一些测试相关的类，还有就是tools里放的一些命令行监控工具类



### 启动Namesrv

首先在磁盘随意目录下创建一个rocketmq-file目录，目录下创建store、conf、logs，拷贝distribution/conf下的broker.conf、logback_broker.xml、logback_namesrv.xml到rocketmq-file/conf下，将里面的变量${user.home}改成rocketmq-file目录即可，文中提到的环境变量：ROCKET_HOME配置rocketmq-file目录即可，其他配置按照文中来，记得把相关目录都改成rocketmq-file目录。

logs文件夹用于MQ的日志输出，conf用于存入broker和namesrv配置文件，store用于存储MQ持久化的数据。

我们修改broker.conf配置文件问以下内容：

```
brokerClusterName = DefaultCluster
brokerName = broker-a
brokerId = 0
# 这是nameserver的地址
namesrvAddr=127.0.0.1:9876
deleteWhen = 04
fileReservedTime = 48
brokerRole = ASYNC_MASTER
flushDiskType = ASYNC_FLUSH

# 这是存储路径，你设置为你的rocketmq运行目录的store子目录
storePathRootDir=F:/rocketmq-file/store
# 这是commitLog的存储路径
storePathCommitLog=F:/rocketmq-file/store/commitlog
# consume queue文件的存储路径
storePathConsumeQueue=F:/rocketmq-file/store/consumequeue
# 消息索引文件的存储路径
storePathIndex=F:/rocketmq-file/store/index
# checkpoint文件的存储路径
storeCheckpoint=F:/rocketmq-file/store/checkpoint
# abort文件的存储路径
abortFile=你的rocketmq运行目录/abort
```

org.apache.rocketmq.namesrv.NamesrvStartup

![image-20230411114048416](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111140669.png)

在NamesrvStartup的启动配置中增加环境变量ROCKETMQ_HOME：

```
ROCKETMQ_HOME=F:\rocketmq-file
```

启动NamesrvStartup，观察到如下代码时说明Namesrv启动成功：

```
The Name Server boot success. serializeType=JSON
```

### 启动Broker

我们在MQ源码中找到broker模块，在模块中找到org.apache.rocketmq.broker.BrokerStartup类，这是Broker服务的启动入口。

![image-20230411133231516](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111332555.png)

我们在BrokerStartup类的启动配置中加入两个配置，一个是环境变量ROCKETMQ_HOME，和NameSrv服务一样

```
ROCKETMQ_HOME=F:\rocketmq-file
```

另一个应用参数（Program arguments）是给broker指定broker.conf配置文件的路径：

```
-c F://rocketmq-file//conf//broker.conf
```

![image-20230411133401399](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111334442.png)

然后，我们启动BrokerStartup，当看到如下日志后，就说明broker节点服务已经启动成功了。

```
The broker[broker-a, 172.18.160.1:10911] boot success. serializeType=JSON and name server is 127.0.0.1:9876
```

### 启动MQ控制台

下载RocketMQ控制台代码：

https://github.com/apache/rocketmq-externals/tree/release-rocketmq-console-1.0.0

下载后需要使用maven工具进行打包，得到rocketmq-console-ng-1.0.0.jar。

之后使用如下命令启动RocketMQ控制台：

```
java -jar rocketmq-console-ng-1.0.0.jar  --rocketmq.config.namesrvAddr=127.0.0.1:9876
```

启动后，我们访问127.0.0.1:8080地址，在集群中看到我们启动的MQ集群信息：

![image-20230411154842386](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111548599.png)

到这里我们已经成功的启动了NameSrv和broker服务，并且在MQ控制台看到了MQ集群信息。

下面我们新建一个名为TopicTest的topic主题，用来测试消息的发送消费是否正常。

![image-20230411155604207](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111556252.png)

首先，我们找到测试用例代码，这里我们直接用的RocketMQ的excample模块下的两个测试类：

```
org.apache.rocketmq.example.quickstart.Producer
org.apache.rocketmq.example.quickstart.Consumer
```

![image-20230411161003629](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111610669.png)

首先我们在Producer类中，简单修改一下代码，将生产者对象的NamesrvAddr地址改为本地的ip端口：

```
producer.setNamesrvAddr("127.0.0.1:9876");
```

然后启动Producer类的main方法，注意这个类的使用for循环向MQ发送了1000条数据，我们可以减少这个循环次数来加快流程验证。

这里我将循环次数改为了1，得到的发送打印结果如下：

```
SendResult [sendStatus=SEND_OK, msgId=C0A879ED000018B4AAC236FDB13F0000, offsetMsgId=AC12A00100002A9F0000000000000000, messageQueue=MessageQueue [topic=TopicTest, brokerName=broker-a, queueId=3], queueOffset=0]
```

然后我们回到RocketMQ控制台中，查看TopicTest的详情状态信息，可以看到我们的这条信息发送到了Topic的第三个数据分片队列中。

![image-20230411162509809](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111625858.png)

-------------

同理，我们在Consumer类中，将NamesrvAddr地址改为和生产者对象一样的本地ip端口。

然后我们启动Consumer类的main方法，就能看到刚才在生产者发送的MQ消息打印在日志中：

```
ConsumeMessageThread_1 Receive New Messages: [MessageExt [queueId=3, storeSize=201, queueOffset=0, sysFlag=0, bornTimestamp=1681200995660, bornHost=/172.18.160.1:51864, storeTimestamp=1681200995698, storeHost=/172.18.160.1:10911, msgId=AC12A00100002A9F0000000000000000, commitLogOffset=0, bodyCRC=613185359, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message{topic='TopicTest', flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=1, CONSUME_START_TIME=1681201806590, UNIQ_KEY=C0A879ED000018B4AAC236FDB13F0000, CLUSTER=DefaultCluster, WAIT=true, TAGS=TagA}, body=[72, 101, 108, 108, 111, 32, 82, 111, 99, 107, 101, 116, 77, 81, 32, 48], transactionId='null'}]] 
```

到这里，我们在本地就把MQ跑起来了，下一步我们从NameSrv开始，来逐步分析源码的逻辑。
