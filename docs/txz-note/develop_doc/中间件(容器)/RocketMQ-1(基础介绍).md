RocketMQ-1(基础介绍)

### RocketMQ详细中间件

#### 1.消息队列引入场景

- **削峰填谷**：削减服务器在瞬间接受过多请求的压力
- **系统解耦**：系统间的信息交互通过MQ来完成，双方系统只需要对MQ的传输负责
- **异步处理**：MQ可以独立存在，队列中的任务可以在请求完成后慢慢消化处理
- **数据最终一致性**：当MQ推送的请求执行失败时，可以重新进行推送，上游系统没必要再次发送请求

#### 2.名词介绍

- **broker**：消息存储实例(进程)，一个可以包含多个topic
- **broker server**：消息存储服务器，用于接受存储生产者产生的消息数据
- **name server**：路由存储服务器，用于存储topic存储于某个broker server的对应关系
- **producer**：消息生产对象
- **producer group**：同一类生产者的集合
- **consumer**：消息消费对象
- **consumer group**：同一类消费者的集合
- **topic**：逻辑上业务划分单位，一个topic可以包含多个message queue，可以发送给不同的broker
- **pull consumer**：拉取式消费，消费者主动从broker中获取消息进行消费
- **push consumer**：推送消费，broker主动将消息推送给消费者
- **clustering**：集群消费，相同consumer group下的消费者均分队列中的消息
- **broadcasting**：广播消费，相同consumer group下的消费者均获取到全量的消息
- **message**：消息传输最小单位，message必属于某个topic，且有唯一消息id和业务key值
- **tag**：标签，可以标注在message上，可用于消息分类或消息过滤查询

### 3.消息有关特性

- **发布与订阅**：发布是生产者发布消息到某topic中，订阅是某消费者关注了某个topic中带有某些tag的信息，进而进行消费
- **消息顺序**：全局消息顺序即保证一个topic下的信息进行顺序消费，先进先出；分区顺序即按照shared key对消息进行分区，每个分区保证消息顺序消费。
- **消息过滤**：在broker中按照某些tag属性对消息进行区分过滤，避免无用消息被消费者消费
- **至少一次**：每条消息需要pull到本地进行消费后才会给服务器返回ack，若消费者没有消费消息则不会返回ack信息
- **回溯消费**：某些消息被消费者消费过后，由于业务需求或consumer系统异常，需要重新消费前多长时间的消息
- **事务消息**：消息的发送和消费在一个全局事务中，要么成功，要么失败
- **定时消息(延迟队列)**：消息发送到broker中后不会立即被消费，而是等到设定的事件后推送到指定的topic中
- **消息重试**：由于消息本身内容错误，或consumer下游系统故障，导致消息消费失败，可设置多个重试队列重新推送消息
- **消息重投**：生产者发送消息时，同步消息失败会进行消息重投，可能产生消息重复的问题
- **流量控制**：由于broker达到性能上限，限制生产者的消息推送(不会重投)；由于消费者达到性能上限，限制消费信息的拉取
- **死信队列**：当消息消费失败达到重试上限时，会被推送到死信队列中，可由维护人员手动处理

#### 4.RocketMQ安装配置

①到RocketMQ官网下载安装包，地址：[http://rocketmq.apache.org/release_notes](https://link.jianshu.com/?t=http%3A%2F%2Frocketmq.apache.org%2Frelease_notes%2Frelease-notes-4.2.0%2F)

②下载完成后解压到某个英文路径下(不含空格)

③配置环境变量：

新增系统变量：名称(K)：ROCKETMQ_HOME     路径(V)：D:\ProgramData\rocketmq-all-4.7.1-bin-release

在path中加入%ROCKETMQ_HOME%\bin

④win+r输入cmd打开系统命令行，输入`mqnamesrv.cmd`开启NameServer服务

```shell
C:\Users\Alex>mqnamesrv.cmd
Java HotSpot(TM) Server VM warning: Using the DefNew young collector with the CMS collector is deprecated and will likely be removed in a future release
Java HotSpot(TM) Server VM warning: UseCMSCompactAtFullCollection is deprecated and will likely be removed in a future release.
Java HotSpot(TM) Server VM warning: MaxNewSize (512000k) is equal to or greater than the entire heap (512000k).  A new max generation size of 511936k will be used.
The Name Server boot success. serializeType=JSON
```

出现`The Name Server boot success`字样时，说明NameServer服务已开启。若出现VM error等字样则需要打开runserver.cmd，修改其中的内容占用空间大小

⑤新开一个命令行，输入`mqbroker.cmd -n localhost:9876`，开启broker服务

```sh
C:\Users\Alex>mqbroker.cmd -n localhost:9876
The broker[LAPTOP-328HCP3K, 10.0.20.11:10911] boot success. serializeType=JSON and name server is localhost:9876
```

1.同样出现`The broker[XXXXXX] boot success`字样时，说明broker开启成功。若是出现‘找不到或无法加载主类...’错误，则到runbroker.cmd中使用双引号括住`%CLASSPATH%`即可启动成功。

2.启动rocket mq broker时无法启动，且没有任何日志，在这做个记录。
把c:/user/你的用户名/里面的store里面的所有文件全部删除，再启动，成功