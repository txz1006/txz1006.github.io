redis-5(基础类型应用)

## redis基础类型应用

以下内容均属于基础数据类型应用学习，真实场景不一定这样来

### String类型应用

#### setnx分布式锁

setnx()是原子操作命令，一次只能写入一个线程数据，写入失败返回null，写入成功返回正整数

加分布式锁的写入：setnx(key,val)  ===>set key val ex 10 nx（Redis命令,设置一个加锁的set命令，key过期10s）

解锁只能等key过期，或是del删掉这个可以，才能重新写如这个key

此外，还可以通过setnx的value值来进行身份验证的的分布式锁释放，即value可以设置为加锁用户的id等信息，这样在解锁时，通过验证value值，只有当前用户本身才可以进行解锁，其中会涉及到pipline操作。

redis的pipline操作可以认为时一个批量发送命令给redis进程的对象，他可以一次请求批量发送命令/取回结果，性能高于单条命令的执行，但是由于过程不是原子性的，常和mulit(开启事务)、exec(执行关闭事务)命令连用。

其他事务命令：

discard(事务停止)，即事务中的操作命令不生效

当事务中执行命令报错时，之后提交事务会不生效

watch(key监控)，watch可以监控某个key，如果之后提交事务时，这个key的val没有变化(从watch开始)，那么可以正常提交事务，如果被改变了，那么该事务不生效

参考:https://www.jianshu.com/p/f66e9584154f

**之后的命令使用jedis缓存连接池操作**

#### mset 、mget、 msetnx批量读写redis命令

批量写：

```lua
mset (key1, val1, key2,val2,key3,val3...)
```

批量读：

```lua
mget(key1,key2,key3...)
```

若想写入数据不冲突，加入nx分布式锁 

```lua
msetnx(key1, val1, key2,val2,key3,val3...)
```

**应用场景**：

文章的缓存写入/更新： mset('title', '标题1'， ‘content’, '内存1', '创建时间'，‘2021’)或msetnx(..)

文章的缓存获取：

```lua
mget('title',‘content’)
```

#### strlen、getrange、setrange统计和截取

获取文章字符数量(编码规则不同，计算结果有异)：

```lua
strlen('title')
```

获取文章前一段字符(截取前10个字符)：

```lua
getrange('title',0,10)
```

文章内容替换(重 第10个字符开始内容替换)：

```lua
setrange('title',10, '新内容')
```



#### append日志审计

append命令和往一个key中追加内容，可以用来做日志审计工作：

```lua
append('redis:log:20210101', '第N条数据操作')
```



#### 唯一id生成/编号递增

使用incr或incrBy等递增原子命令，每次+1或+N，可用于唯一id或点赞等场景

```lua
id = incr("uuid")
```

redis会创建一个uuid第一次返回1，之后每次递增1

#### 编号递减

适用场景：取消用户的操作，编号-1

```lua
decr("like:num:123")
```



### Map类型应用

#### 短链接访问量监控

通过id = incr("uuid")每次产生一个不同的数(seed)，然后根据这个数按一定规则计算出一个几位数的随机字符串(如D78FLJ12Q)，可以作为短链接的尾缀(https://t.cn/D78FLJ12Q)。

通过redis 的hashmap对象存储这个短链接的访问数和映射真实url

```lua
-- 设置短链接访问量
hset("shortUrlMap", 'D78FLJ12Q:ACCESS_NUM', "0")
-- 设置短链接映射关系
hset("shortUrlMap", 'D78FLJ12Q:MAPPER_URL', "https://xxxx.com/content?123123$34646")
```

这样就可以通过redis来计算短链接的访问量了

```lua
-- 让map中的统计对象每次递增1
hincrby("shortUrlMap", 'D78FLJ12Q:ACCESS_NUM', 1)
```

查询短链接的访问次数

```lua
hget("shortUrlMap", 'D78FLJ12Q:ACCESS_NUM')
```

#### map对象存储(补充)

上面简单讲解过redis中存储map对象的基本操作了，即hset、hget命令，这适合让我们来存储一个对象具有多个属性的场景，当然，也可以将这个对象在代码中序列化成字符串后，用简单的set /get 存储。下面我们来补充一些redis中map对象的的其他操作。

判断map对象中的元素是否存在：

```lua
boolean check = hexists("shortUrlMap", 'D78FLJ12Q:ACCESS_NUM')
```

批量存储map属性:

```lua
hmset("shortUrlMap", Map对象)
```

获取map对象全部属性：

```lua
hmgetall("shortUrlMap")
```

获取map对象的属性数量：

```
hlen("shortUrlMap")
```

#### session管理

我们可以适用 map对象作为session的token存储对象：

```lua
-- 用户登陆获取token
String token = UUID()
hset("SESSIONS", token, userId)
hset("SESSION_EXPAIRE", token, 当前时间+一个时间段)
return token

-- 验证token
token = 用户请求携带参数中获取
if(token == null) return false
if(!hexists(token)) return false
--token存在
String exprie_time = hget("SESSION_EXPAIRE", token)
--当前时间超过过期时间
if(current_time >= exprie_time) return false
return true
    
```

### List类型应用

#### 秒杀场景公平队列

redis中的list对象是一个有序队列，可以被当作一个栈dioxin或队列来使用，例如在秒杀场景中可以使用队列来进行用户请求的先后排序：

```lua
-- 入队(lpush意为从左入队，rpush意为从右入队)
lpush("user:requset", 用户请求)
--出队(rpop意为从右出队，lpop意为从左入队)
rpop("user:requset")

--出栈(先进后出)
lpop("user:requset")
```

#### 待办列表

新增待办：

```lua
lpush("todo:requset:userId", "todoEvent")
```

分页查询

```lua
lrange("todo:requset:userId", (pageNo-1)*pageSize-1, pageNo*pageSize-1)
```

插入紧急任务(插队)

```lua
-- 将todoEve插入到targetTodoEve的前面或后面(根据position而定(before/after))
linsert("todo:requset:userId", position, targetTodoEve, todoEve)
```

代办完成

```lua
-- 移除队列中所有和todoEve名称相同的元素
-- 第二个参数count大于0时，移除count数量的和todoEve名称相同的元素，从队列中从头往尾遍历
-- 第二个参数count小于0时，移除count数量的和todoEve名称相同的元素，从队列中从尾往头遍历
lrem("todo:requset:userId", 0, todoEve)

lpush("todo:finish:requset:userId", "todoEvent")
```

查询所有已办任务

```lua
--列出已办列表，从第一个元素到最后一个元素
lrange("todo:finish:requset:userId", 0, -1)
```

批量完成待办

```lua
--裁剪，仅保留index从5到最后一个元素
ltrim("todo:requset:userId", 5, -1)

lpush("todo:finish:requset:userId", "0、1、2、3、4todoEvent")
```

修改待办

```lua
-- 将首个元素改为newTodoEve
lset("todo:requset:userId", 0, "newTodoEve")
```

查询指定位置的待办

```lua
-- 获取索引位置为10的待办
lindex("todo:requset:userId", 10)
```

#### 邮箱验证

列表出队的扩展：brpop从队列尾部出队元素，如果列表没有元素了，会进行阻塞，阻塞期间发现新元素，则直接出队，没有则超时返回nil

```lua
--如果todo:send:emailList没有元素，则阻塞5秒钟，5秒内发现新元素则出队，达到5秒则超时
brpop(5, "todo:send:emailList")
```

### Set类型应用

#### 网站UV(访问量)去重统计

set结构存储不重复的对象，但是无序

```lua
--在set对象中写入(自动去重)
sadd("user:address:access", currentDate)
```

获取UV数据(统计)

```lua
scard("user:address:access"+currentDate)
```

#### 网站标签管理

添加标签

```lua
sadd("article:id:tags", "js", "java", "node")
```

判断文章是否包含某标签

```lua
--是否有js标签
sismember("article:id:tags", "js")
```

获取文章全部标签

```lua
smembers("article:id:tags")
```

获取文章标签数量

```lua
scard("article:id:tags")
```

#### 文章点赞案例(可取消)

点赞

```lua
sadd("article:id:like", "userid")
```

取消点赞

```lua
--从set中删除点赞
srem("article:id:like", "userid")
```

判断用户是否已经点赞过了

```lua
sismember("article:id:like", "userid")
```

获取点赞列表

```lua
smembers("article:id:like")
```

获取点赞总数

```lua
scard("article:id:like")
```

#### 微博共同关注

查询我和好友的共同关注

```lua
--获取两个set集合的交集(sinter获取多个set交集)
sinter("user:id:followers", "friend:user:id:followers")
--将这个交集列表存储为一个新set对象(扩展)
sinter("new:setName","user:id:followers", "friend:user:id:followers")
```

获取好友关注了而我没有关注的用户列表

```lua
--返回friend:user:id:followers中存在但不在user:id:followers中存在的列表
--sdiff返回第一个set结合中独有的数据
sdiff("friend:user:id:followers", "user:id:followers")
--将这个差异列表存储为一个新set对象(扩展)
sdiffstore("new:setName", "friend:user:id:followers", "user:id:followers")
```

取并集（其他）

```lua
--返回并集列表
sunion("friend:user:id:followers", "user:id:followers")
--将这个全列表存储为一个新set对象(扩展)
sunion("new:setName", "friend:user:id:followers", "user:id:followers")
```

#### 随机抽奖

参数抽奖

```lua
sadd("draw:lottery", "userid")
```

抽奖(人员重复)

```lua
--随机获取set中的两个元素
srandmember("draw:lottery", 2)
```

抽奖(人员不重复)

```lua
--随机出队set中的两个元素
spop("draw:lottery", 2)
```

### Sorted Set类型应用

在set类型的基础上(不重复)，给每个元素增加了一个分数属性，用于对set对象的中元素进行排序

####  歌曲排行榜示例

增加排行榜歌曲元素

```lua
--zadd(元素名称，分数，存储值)
zadd("music_ranking_list", 0, songId)
```

增加歌曲元素值的分数

```lua
--增加score的值
zincrby("music_ranking_list", score, songId)
```

获取歌曲的分数

```lua
zscore("music_ranking_list",  songId)
```

获取歌曲在集合中的分数排名

```lua
-- (按分数倒序排列的索引值)
zrevrank("music_ranking_list",songId)

-- (按分数正序排列的索引值)
zrank("music_ranking_list",songId)

```

获取集合中按分数排名前几的元素

```lua
--按照分数倒序排列取前三个集合元素
zrevrange("music_ranking_list", 0, 2)

--按照分数正序排列取前三个集合元素
zrange("music_ranking_list", 0, 2)
```

获取集合中按分数范围查询的元素

```lua
--获取分数0-30之间的元素倒序排列
zrevrangebyscore("music_ranking_list", 30, 0)
--获取分数0-30之间的元素正序排列
zrangebyscore("music_ranking_list", 0, 30)
```

获取集合中按索引排列前几的元素

```lua
--按照索引排列取前三个集合元素(索引正序)
zrange("music_ranking_list", 0, 2)

--按照索引排列取前三个集合元素(索引倒序)
zrevrange("music_ranking_list", 0, 2)
```

### 其他特殊类型的应用

#### HyperLogLog概率去重

HyperLogLog是一种特殊的数据结构，他的作用和Set类型相似可以用来做去重的相关统计工作，更关键的是，这个类型在做统计时是一种概率算法得到的结果，所以在效率上(特别是大数据量时)会特别的高，而且占空间极小(16K)，但是正因为这个结构是通过概率算法计算的，往往数据一多就会和实际统计值有一些偏差。因此这个类型往往可以做大的数据量级统计，但是不做精确统计。

##### 网站UV统计去重

写入日志到HyperLogLog对象中

```lua
--写入数据到集合中
pfadd("userId::access::log::date", "userInfo");

--如果写入成功，那么返回1，写入失败(重复数据不做写入)返回0
--可以通过其写入重复数据返回0的特点，可以用来做数据去重(Set类型也可以)
```

统计HyperLogLog对象中元素个数

```lua
--通过概率算法得到的近似值结果
pfcount("userId::access::log::date")
```

多个HyperLogLog对象合并统计

```lua
--创建2个HyperLogLog对象
pfadd("demo1", "userInfo1", "userInfo2", "userInfo3", "userInfo4");
pfadd("demo2", "userInfo3", "userInfo4", "userInfo5", "userInfo6");

--合并demo1、demo2两个对象，写入到demo3中
pfmerge("demo3", "demo1", "demo2")

--获取合并后的统计结果
pfcount("demo3")
```

#### String类型比特位

redis提供了直接操作String类型bit位的数据结构，我们可以直接修改不同bit位0/1编码来修改整个String类型的内容

```lua
--创建一个String类型，写入a(对于ASCII码的二进制值为01100001)
set("name", "a")

--通过直接bit操作修改name的值
--第二参数是bit位的偏移量，第三个参数是对应bit位的值(只有0/1)
--这里是将01100001变为了01100010==》b的ASCII码的二进制值
setbit("name", 6 , 1)
setbit("name", 7 , 0)

--再次查看name的值时得到b
get("name")

--获取某个bit位的值
--获取偏移量位6(左往右第7个bit位)的值,得到1
getbit("name", 6)

--计算bit位中1的数量,得到3
bitcount("name")
```

#### GEO地标数据类型

redis提供了地理坐标类型的数据结构，我们可以通过这个结构来计算两个坐标的距离、或是搜索某个坐标范围内的地点

##### 计算两个坐标的距离

```lua
--录入坐标到某个集合中
geoadd("someone_place", 116.365453,39.919957, "place1");
geoadd("someone_place", 116.366154,39.920088, "place2");

--计算两点的距离
geodist("someone_place", "place1", "place2");
```

获取坐标范围内的数据

```lua
--录入坐标到某个集合中
geoadd("someone_place", 116.365453,39.919957, "place1");
geoadd("someone_place", 116.366154,39.920088, "place2");

--获取place1点范围5公里内的数据
georadiusbymember("someone_place", "place1", 5.0, GEOUnit.KM) 
```

