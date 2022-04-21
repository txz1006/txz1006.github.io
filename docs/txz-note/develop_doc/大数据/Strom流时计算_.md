Strom流时计算

storm实时计算框架

1.并行度：指task的数量，即storm的计算并发程度

2.流分组：指数据在task之间的流转关系

一、物理结构：
storm集群实际存在的节点容器关系：
nimbus节点：storm集群的主节点，负责资源调度，元数据维护，和计算拓扑入口管理等功能
supervisor节点： 我们要上传一个计算作业到nimbus节点后，nimbus节点会将将作业交给多个supervisor节点，每个supervisor节点是计算作业的主要管理节点

worker节点： 每个supervisor节点会将作业交给一个worker节点处理

executor： worker中业务的执行者

task：每个executor又可以分都多个task来执行java业务代码

二、运行拓扑结构：
具体而言就是一个个的计算作业代码jar包的结构

topology：拓扑整体结构，topology可以放在storm结构中进行实时计算

spout： 在拓扑中，spout是用来设置计算业务的数据源的，根据流转关系，会将每条数据封装成一个tuple，发送给blot

blot： 指拓扑中，一个业务计算单位，blot会接受从spout或其他blot发送过来的数据，并吧计算后的结果再发送出去

stream： 指拓扑计算中，一条条tuple形成的数据流

tuple：在storm中数据流转的单位

三、运行拓扑和物理结构的对应关系：

每个spout或blot作业对象，会放到某个supervisor节点的worker节点中，worker节点会根据配置来创建多个executor来执行业务代码，具体而言每个executor也会创建多个task来执行这些代码

task执行完成后，会根据spout或blot之间的流转关系，将结果发送到其他blot的task线程中接受执行

=================

strom：实时大数据计算，或数据预热

hive：可以做数仓，基于hadoop实现的类sql数据查询引擎层

spark：大数据批量离线处理

zookeeper：分布式协调系统，提供注册中心，宕机选举，分布式锁，负载均衡，集群容错等等功能

hBase： 可做noSQL数据库，基于hadoop实现的key/val型数据存储，有更好的伸缩性

Elasticsearch：大数据查询引擎