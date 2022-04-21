### ElasticSearch面试问题

#### 1.ES是东西？主要用来做什么？

ES是基于Lucene项目实现的一个全文检索分布式搜索引擎，可以实现类似百度、谷歌那样的分词搜索功能，也可以作为一个分布式的数据库。现在很多公司会使用ES来作为公司级项目的数据搜索引擎，或者和logstash + kibana作为日志的可视化监控统计而使用(logstash搜集日志传输到ES中，而后由kibana统计渲染成可视化图形)。

Lucene是 apache基金会开源的一个全文检索程序集，开发者可以用它的API来开发搜索引擎功能，比如ES、slor等搜索引擎项目都是基于Lucene包装开发出来的优秀项目。

Lucene项目主要依赖于对数据文件创建倒排索引(根据分词器的规则对全文进行检索分词，常见的中文分词器有IK、smartcn等)，这样我们在根据关键字查询时会去倒排索引中查询具体的索引id，再通过索引id定位到具体的数据文件。



#### 2.ES的分布式设计架构是怎样的？

先了解下ES的主体数据结构。在ES中我们会将数据记录成一个个的index，每个index可以认为是mysql中的一个大表，存储这某类相关的数据；index中会根据业务区分出很多type来，type之间的格式类似，每个type可以认为是某一个分组规则(比如weather index下可以根据城市分组、也可以根据天气状况分组)；type下会有一个mapping结构，mapping可以认为是某个分组下的表结构；之后会有一条条的数据作为document存储在其中，而document里又有多个field来存储数据。

index-->type -->mapping -->document -->field

在架构上。ES可以进行分布式高可用部署，每个ES进程可以作为一个node，多个ES node组成一个cluster集群。每个node在存储index数据时，会将index拆分为多个shard分片，这些分片会分开存储到多个node进程中，而且每个shard分片至少会有一个replica从分片，在写入数据时，会通过ES客户端将数据写入某个主shard分片中，然后数据会同步给其他从shard分片，在读取时可以从从shard分片中获取数据。

在ES集群中，会选出一个node作为主节点，用来维护一些元数据，切换主/从 shard分片等功能，如果主node得宕机了，会从存活node中选举出一个新的主node出来，并将宕机node中的主shard对应存活在其他node节点中的从shard分片升级为主shard分片。当这个宕机的node重启后，会被作为一个普通node挂到新主node上去，而且其中的主shard分片会被降级为从shard分片。



#### 3.ES的读写原理什么？

先说数据写入的大概逻辑：客户端新建一条数据对ES集群发起请求后，会随机路由到某个ES node节点上，此时这个节点被称为协调节点，根据请求数据进行hash计算得到应该将这条数据写入到某个主shard中，如果这个shard不在协调节点中，那么就会路由到主shard分片存在的那个node节点，然后shard分片会对数据进行存储记录，并将结果返回给协调node，再有协调节点返回给客户端。

至于shard是具体如何处理请求的么？

其实是这样的。首先shard拿到请求后，经过处理会将数据写入到一个buffer内存区域，同时，会将这条数据写入translog日志中，如果buffer对象中存在数据，那每1秒会将buffer中的数据写入到 os cache中准备落盘(写入os cache后才能被查询到)，os cache会将buffer中的数据写成一个segment file到磁盘中，之后buffer会进行清空开始处理下一轮的请求。而translog会每5秒钟同样会通过os cache进行落盘持久化(也就是es最多会有5秒钟的数据丢失的可能)。

当translog文件大到一定程度或者每隔30分钟，会触发一次commit命令，具体而言就行将translog文件中记录的segment file合并成一个大的segment file，之后会清空translog日志文件。

如果是删除数据命令，那么shard会将要删除数据的doc_id(ES中的唯一id)记录在一个.del文件中，那么之后的查询会将删除文件中的数据过滤掉，不会被查询出来，当机械能commit命令合并segment file时，新生成的segment file会将这些删除数据从中去除掉。

#### 4.ES时如何查询和搜索的？

查询是直到数据的具体doc_id,进行精确查询，搜索是会所以数据进行遍历。

和读写类似，首先客户端新建一条数据对ES集群发起请求后，会随机路由到某个ES node节点上，此时这个节点被称为协调节点，根据doc_id确定数据所在shard分片位置，再更具轮询或某个规则，路由到某个shard分片中(可以实主分片，也可以是从分片)，之后在shard中进行查询，得到结果后将数据返回给协调节点再返回给客户端。

而搜索和查询的区别是，需要根据搜索条件对所有的shard分片进行一次遍历，再将结果汇总发给协调节点。

5.ES线上部署实例？

![image-20210731180049961](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210731180058.png)





