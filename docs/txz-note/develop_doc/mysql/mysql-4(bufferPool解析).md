mysql-4(bufferPool解析)

### Buffer Pool简单解析

#### 一、buffer pool是什么

buffer pool是mysql存储引擎中的一块内存缓存池，也是执行增删改查sql操作的主要内存区域；当我们执行一个sql时，执行器会在buffer pool中寻找这个sql要操作的目标数据，如果没有找到，则会到磁盘中寻找对应的数据，并将之加载到buffer pool中，再对这些数据进行处理，处理后的数据就暂时变成了脏数据(磁盘中对应的数据还是修改前的数据)，最后会有后台线程将这些脏数据刷入到磁盘中，完成整个sql操作。

所以，buffer pool是mysql处理存储数据的地方，一块有着特别数据结构的内存区域。

#### 二、mysql中表数据的存在形式

在解析buffer pool之前我们需要搞清楚一个问题，那就是我们经常操作的数据表、表字段、表数据是以什么结构存储在内存和磁盘中的？

这里先直接给出答案，那就是数据页，一个数据表会有多个数据页组成，每个数据页可以存储多行表数据，一个数据页的大小固定为16K，在磁盘中和在内存中都是这个存储大小。

buffer pool中会存储多个从磁盘中查询的数据页，在buffer pool中的数据页可以称为缓存页，sql要操作的就是这些缓存页中的数据。这里要引入第二个结构：缓存页的元数据对象，或者说是缓存页的描述信息对象，这是buffer pool中存储的另外一种对象，大小一般是缓存页的5%(800B左右，所以一般buffer pool的大小会因为这些缓存页元数据会超出128M一些)，这个对象会存储一个缓存页的一些描述信息，如缓存页的地址、所属表空间的地址，缓存页的编号等等。

可以认为这个对象是buffer pool中数据页的索引，因为执行器根据sql在buffer pool寻找要操作缓存页时，不可能一个一个数据页的遍历，而是直接查找这个缓存页的元数据对象，进而获取对应的缓存页。

到这里buffer pool的结构可以描述为下图：

![image-20201226160615632](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201226160615.png)

需要注意的是mysql启动后，buffer pool获取到内存空间，就会创建好多个16K大小的缓存页和88B左右的元数据对象，不过此时的两种对象都是空的，需要用户查询sql后，会查询磁盘的数据页并将之写入到缓存页中

#### 三、buffer pool的组成结构

##### 判断数据页是否已经读取到缓存页

目前为止，我们知道buffer pool主要存储了缓存页和缓存页元数据两种对象，但是执行sql时我们要修改的缓存页是否已经存在在缓冲池中我们并不清楚。所以为了解决这个问题，会首先判断在缓存池中是否已经有了要操作表的缓存页。如果有，就直接操作缓存页；如果没有就要去磁盘读取数据页加载到一个空的缓存页中。所以最好能通过某个结构直接判断对应缓存页是否有数据，这里引入另外一个结构：一个由key:(表空间号+数据页号)，value:(缓存页地址)组成的hash表结构，这样在查询缓存页是否存在时，只需要判断表空间号+数据页号的key在这个hash表中是否存在就清楚目标缓存页是否存在了，查得到数据就是缓存页存在，查不到数据就去读取数据页：

![image-20201226170238634](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201226170238.png)

##### 判断哪些缓存页是空的

当没有哈希映射表查询到数据时，就要去磁盘查询对应的数据页了，但是这又有另外一个问题了，查询回来的数据页如何知道到buffer pool中哪些缓存页是空的，这里引入另外一个结构：缓存页元数据对象组成的free双链表结构。

具体而言就是，缓存页元数据之间会通过链表将缓存页为空的的元数据对象连接起来，组成的链表就是free链表，而且在buffer pool外还有一个链表总节点，它会存有free链表的头节点和尾节点地址，同时存储了free链表的长度，大概的结构如下：

![image-20201226164851251](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201226164851.png)

当有缓存页空闲时，就将其加入到free链中，当缓存页被写入数据页后，就会清除free链的前后节点链接关系。总结点是一个在buffer pool外的数据结构，他的大小约是40K左右。

有了free链后，我们在磁盘查询到数据页后，只需要从这个free链表中获取空白缓存页地址，并将数据页插入到缓存页中。

##### 判断哪些缓存页需要写入磁盘

当我们修改过缓存页中的数据后，这个缓存页就变成脏缓存页，需要等待刷入磁盘，那么如何知道哪些缓存页是脏缓存页呢？这里会再次使用一次双链表将这些脏缓存页穿成一个flush链。结构和free链基本相同，而且还是通过缓存页的元数据对象组织的，有一个buffer pool外的总节点，会存有flush链表的头节点和尾节点地址，同时存储了flush链表的长度：

![image-20201226172044344](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201226172044.png)

这样，后台线程就能知道哪些缓存页需要刷回磁盘了。

##### 判断哪些缓存页需要释放

由于buffer ppo的空间是有限的，所以空间中的缓存页很可能被用完，这时，如果再从磁盘中查询数据页写入到缓存中时，就需要考虑将一部分缓存页释放掉或是刷入磁盘中，最好这些缓存页还是使用频率较少的那种；于是，这里就引入了一个新的链表对象：LRU链表(LRU是least recently used最少使用的意思)，每个数据页首次加入到缓存页时都会一直处理这个LRU链中。

这个链表和之前的free链表和flush链表基本相同，基于缓存页的元数据对象组成的双链表结构，当执行器从磁盘中加载数据到缓存页时，就会将当前缓存页的元数据对象放置到LRU链表的队首位置，之后的数据页在插入缓存页时，就会取代上一个缓存页队首的位置，而原来的队首元素则会依次往后排列；这样就形成了一个频度排序链表：频繁访问的缓存页一定在LRU链表的靠前的位置，访问频次低的的缓存页一定排在LRU链表的最后，大概逻辑视图如下所示：

![image-20201227145330401](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201227145339.png)

最后总结一下当前几种链表的使用：

![image-20201227151051973](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201227151052.png)

##### mysql预读机制

为例减少IO查询次数，提高查询效率，mysql有一种预读机制，那就是达到某个条件时，查询数据页不仅会返回目标数据页本身，还会将当前所在区或相邻区的数据页全部写到缓存中。

这个预读机制默认是关闭的的，可以通过参数innodb_random_read_ahead来控制(默认为off)，而开启鱼洞功能后执行预读的条件有两种触发情况：

1. 有个innodb_read_ahead_threshold参数(默认值为56)，意思是如果顺序访问某个表的数据区中的数据页数的数量达到了这个参数的设定值，则会触发预读机制，将相邻区的数据页都加载到缓存中
2. 如果buffer pool中存了一个数据区的连续13个数据页，也会触发预读机制，将当前区的数据页都加载到缓存中

但是这个预读功能是有问题存在的，那就是这些被连带写入缓存的数据页并不是都会被访问到的，但是一定都会被写入LRU链的链首部分，那么原来LRU链的链首部分就被挤到了靠后的位置，这就很可能会被处理掉。除了预读会导致访问频次高的数据页会被淘汰掉外，还有一种情况也会导致这种问题，那就是全表扫描，全表数据页全插入到了LRU链的链首部分，其余的缓存页就很可能会被淘汰了。

为了解决这个问题，mysql对LRU链表进行了分段处理，靠近LRU头部的元素是经常被查询的热数据区，不经常用的数据则靠近链表尾部，两者以innodb_old_blocks_pct(默认值为37)配置属性为百分比分界点，也就是LRU前63%的缓存页是热数据区，后37%的缓存页为冷数据区；当磁盘数据页首次加载到缓存时，直接插入到冷数据区的开头，这样就不会将热数据区的缓存页淘汰了，示意图如下：

![image-20201228162157667](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201228162209.png)

同时，当数据页插入到冷数据区队首后，再次访问这个队首缓存页时，不能直接将其提到热数据区的队首，因为你可能只会访问了一次这个缓存页，之后就不在访问了；所以mysql设置了一个将冷数据区元素提到热数据区队首的阈值参数：innodb_old_blocks_time(默认为1000ms)，也就是加载到冷数据区队首的缓存页在1s内被访问时不会被提到热数据区队首，当时间超过了这个阈值，再访问这个缓存页时，才可以将这个缓存页提到热数据区队首。

![image-20201228162619494](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201228162619.png)

所以LRU链通过一个冷热数据分区，解决了热数据区被新查询的缓存页顶替淘汰的问题。例如，预读加载数据页和全表扫描时的数据页全部加载到冷数据区了，这个时间多半会在1s内，这些数据基本不会被提前到热数据区中；而且在进行缓存页淘汰时，也是优先淘汰冷数据区尾部的缓存页，这些数据一般没怎么被使用，可以正常淘汰。

其他疑惑解析：

1.热数据区的缓存页提前到队首是过于频繁的，所以在热数据区中靠近队首的前1/4缓存页被访问是不会被提到队首的，只有热数据区后3/4的缓存页被访问时才会被提到队首。

2.并不是一定要等到缓存页都被用完时，才会进行LRU链尾元素的淘汰，而是mysql会开启一个定时任务，会时不时的将LRU链尾的冷缓存页释放或刷入磁盘，之后把这些空缓存页加入到free链中；此外，还有Flush链也会有一个定时任务，会在mysql空闲时，将脏数据页刷入磁盘，之后把这些空缓存页加入到free链中；所以，缓存页的查询修改，以及冷缓存页和脏缓存页的处理，这整个过程是动态执行的。

##### buffer pool的大小配置

之前我们解析的一个buffer pool中主要有缓存页元数据和缓存页两部分组成，如果要对这个buffer pool进行扩容，那只能是再申请一块要扩容后大小的内存，然后将之前的buffer pool中的数据复制过去，但是这样的效率是非常慢的，所以就有了chunk结构：

chunk块是之前说的缓存页元数据和缓存页的容器，如果buffer pool足够大，一个buffer pool中可以存放一个到多个chunk块，每个chunk块可存放若干缓存页元数据和缓存页，chunk块之间共享buffer pool容器的free链基础节点、flush链基础节点、lru链基础节点，大概结构如下：

![image-20201229190208616](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201229190756.png)

这样如果要对buffer pool进行扩容，只需要增加buffer pool中的chunk结构数量即可。

在mysql中我们可以通过innodb_buffer_pool_size属性来配置buffer pool的大小，buffer pool的默认大小是128M，但是在实际的数据库服务器中，一般可以将buffer pool的大小设置为总内存大小的50%~60%左右，最高在70%左右。

```sql
-- 查询buffer pool大小
show variables like 'innodb_buffer_pool_size'
-- 设置buffer pool大小
set global innodb_buffer_pool_size = 67108864;
```

或者通过配置文件(my.ini 或者my.cnf)设置buffer pool大小：

```ini
[mysqld]
innodb_buffer_pool_size = 2147483648
```

如果你的服务器内存较大，则可以开启多个buffer pool来处理数据：

一般innodb_buffer_pool_chunk_size = innodb_buffer_pool_size  / innodb_buffer_pool_instances

```sql
--chunk大小(128M)
set global innodb_buffer_pool_chunk_size = 134217728
-- buffer pool的数量
show variables like '%innodb_buffer_pool_instances%'
set global innodb_buffer_pool_instances = 1
-- buffer pool的大小
show variables like '%innodb_buffer_pool_size%'
--128M的大小
set global innodb_buffer_pool_size = 134217728

--注意：如果设置的缓冲池大小小于1G时，则innodb_buffer_pool_instances参数时不生效的，只会有一个缓冲池
此外，一般chunk的大小和buffer pool总大小有个关是N*(chunk大小 * buffer pool数量) = buffer pool总大小。比如默认的chunk大小是128MB，那么此时如果你的机器的内存是32GB，你打算给buffer pool总大小在20GB左右，假设你的buffer pool的数量是16个，这是没问题的，那么此时chunk大小 * buffer pool的数量 = 16 * 128MB =2048MB，然后buffer pool总大小如果是20GB，此时buffer pool总大小就是2048MB的10倍，这就符合规则了
```

通过show engine innodb status命令查看mysql的总体状态和参数，将内容复制出来如下显示：

```java
=====================================
2020-12-29 17:05:50 0x532c INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 5 seconds
-----------------
BACKGROUND THREAD
-----------------
srv_master_thread loops: 63 srv_active, 0 srv_shutdown, 29175 srv_idle
srv_master_thread log flush and writes: 0
----------
SEMAPHORES
----------
OS WAIT ARRAY INFO: reservation count 42229
OS WAIT ARRAY INFO: signal count 51515
RW-shared spins 351999, rounds 390104, OS waits 38812
RW-excl spins 68469, rounds 69194, OS waits 134
RW-sx spins 0, rounds 0, OS waits 0
Spin rounds per wait: 1.11 RW-shared, 1.01 RW-excl, 0.00 RW-sx
------------
TRANSACTIONS
------------
Trx id counter 671843
Purge done for trx's n:o < 671843 undo n:o < 0 state: running but idle
History list length 22
LIST OF TRANSACTIONS FOR EACH SESSION:
---TRANSACTION 284074018260800, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018267840, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018261680, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018262560, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018265200, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018263440, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018266960, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 284074018266080, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
--------
FILE I/O
--------
I/O thread 0 state: wait Windows aio (insert buffer thread)
I/O thread 1 state: wait Windows aio (log thread)
I/O thread 2 state: wait Windows aio (read thread)
I/O thread 3 state: wait Windows aio (read thread)
I/O thread 4 state: wait Windows aio (read thread)
I/O thread 5 state: wait Windows aio (read thread)
I/O thread 6 state: wait Windows aio (write thread)
I/O thread 7 state: wait Windows aio (write thread)
I/O thread 8 state: wait Windows aio (write thread)
I/O thread 9 state: wait Windows aio (write thread)
Pending normal aio reads: [0, 0, 0, 0] , aio writes: [0, 0, 0, 0] ,
 ibuf aio reads:, log i/o's:, sync i/o's:
Pending flushes (fsync) log: 0; buffer pool: 0
4265865 OS file reads, 4157 OS file writes, 2088 OS fsyncs
0.00 reads/s, 0 avg bytes/read, 0.00 writes/s, 0.00 fsyncs/s
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 2435, seg size 2437, 49 merges
merged operations:
 insert 38, delete mark 11, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
Hash table size 34679, node heap has 0 buffer(s)
Hash table size 34679, node heap has 15 buffer(s)
Hash table size 34679, node heap has 11 buffer(s)
Hash table size 34679, node heap has 16 buffer(s)
Hash table size 34679, node heap has 2 buffer(s)
Hash table size 34679, node heap has 2 buffer(s)
Hash table size 34679, node heap has 1 buffer(s)
Hash table size 34679, node heap has 1 buffer(s)
0.00 hash searches/s, 0.00 non-hash searches/s
---
LOG
---
Log sequence number          27255053598
Log buffer assigned up to    27255053598
Log buffer completed up to   27255053598
Log written up to            27255053598
Log flushed up to            27255053598
Added dirty pages up to      27255053598
Pages flushed up to          27255053598
Last checkpoint at           27255053598
1796 log i/o's done, 0.00 log i/o's/second
----------------------
BUFFER POOL AND MEMORY
----------------------
//下面是buffer pool的总大小
Total large memory allocated 137363456
Dictionary memory allocated 929672
//下面是buffer pool中能容纳的总缓存页数
Buffer pool size   8192
//下面是free链中的空闲缓存页数
Free buffers       1
//下面是lru链的总缓存页数
Database pages     8143
//下面是lru链中的冷缓存页数
Old database pages 2985
//下面是flush链中的缓存页数
Modified db pages  0
//等待加载进缓存页的数据页数量
Pending reads      0
//等待被刷入磁盘的LRU链缓存页数、flush链缓存页数和单个数据页
Pending writes: LRU 0, flush list 0, single page 0
//Pages made young是lru链中冷数据区的缓存页转移到热数据区的数量
//not young是lru链中冷数据区中1秒内被访问的缓存页，但是没有转移到热数据区的数量
Pages made young 68542, not young 75075206
0.00 youngs/s, 0.00 non-youngs/s
Pages read 4265771, created 159, written 1927
0.00 reads/s, 0.00 creates/s, 0.00 writes/s
No buffer pool page gets since the last printout
//各种读取写入速率
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 8143, unzip_LRU len: 0
//sum[0]是50秒内读取磁盘数据页的数量
//cur[0]是正在读取磁盘数据页的数量
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
--------------
ROW OPERATIONS
--------------
0 queries inside InnoDB, 0 queries in queue
0 read views open inside InnoDB
Process ID=5200, Main thread ID=000000000000235C , state=sleeping
Number of rows inserted 49, updated 754, deleted 7, read 134380678
0.00 inserts/s, 0.00 updates/s, 0.00 deletes/s, 0.00 reads/s
----------------------------
END OF INNODB MONITOR OUTPUT
============================
```

