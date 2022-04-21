redis-2(基础操作)

### 一、redis中各种基础操作

redis存储数据的格式是K-V类型的，所以对key要有一定的设计规则，便于快速寻找、定位数据。

数据格式为：

```
对象类型:对象ID:对象属性名:对象子属性名
//例如：
sms:limit:mobile:136XXXXXXX
```

所有的非查询命令执行成功返回1，失败返回0

#### 1.字符类型(string)

存储数据为字符串类型（val是string）

```sh
#创建赋值
set [key val]
#获取
get [key]

#获取多个key值
mget [key1 key2 key3 ...]

#追加
append [key val]

#字符串长度
strlen [key]
```

字符类型中可存储数值类型并可以对其进行加减乘除

```sh
#创建赋值
set [key num]
#加一
incr [key]
#加N
incrby [key addNum]

#减一
decr [key]
#减N
decrby [key deNum]
```

#### 2.散列类型(hash)

散列实际指哈希K-V存储类型，不同于字符类型的set[key val]存储类型，散列的K-V键值是将value又存储为一个K-V键值对，用命令表示为hset[key field value]，这种类型特别适合存储对象数据，比如一个key可以对应一个对象，多个field对应这个对象的属性，每个field属性的值为value。(注意：散列类型不能嵌套存储其他类型的数据)

（val是hash对象）
```sh
#创建赋值:hset [key field value]
hset person name mike
hset person age 18
hset person sex 男
#取单个key值:hget [key field]
hget person name
#取多个key值:hmget [key field...]
hmget person name age sex
#取全部的k-v值:hgetall [key]
hgetall person
#判断某个属性是否存在:hexist [key field]
hexist person name
#删某个属性:hdel [key field]
hdel person name
#对数值属性加值:hincrby [key field num]
hincrby person age 12
#新增属性:hsetnx [key field value]
#若field在key的哈希表中已存在，则添加失败;若key也不存在则会新建
hsetnx person age 78
```



#### 3.列表类型(list)

创建一个存储数据的队列(数据可重复、有序)，可左右同时进行进出操作,可做业务队列
（val是list列表）
```sh
#队列左边入队
lpush [key val]
#队列左边出队
lpop [key val]
#队列右边入队
rpush [key val]
#队列右边出队
rpop [key val]

#获取队列数据个数
llen [key]
#将key队列的index位置设置为val
lset [key index val]
#将key队列中值为val的数据删除count次
lrem [key count val]
#截取队列片段(可使用负数)
lrange [key startIndex endIndex]
```

#### 4.集合类型(set）

存储一个无序、不重复的集合
（val是不重复list）

```sh
#创建赋值:sadd [key val...]
#若设置了重复的值，则会被忽略
sadd line 1 2 3 4
sadd ff 3 4 5 6
#获取集合全部数据:smembers [key]
smembers line
#取第一个集合和其他集合的集合差:sdiff [key key....]
#下面的示例返回[1,2]
sdiff line ff 
#取集合之间的合集:sunion [key key...]
#下面的示例返回[1,2,3,4,5,6]
sunion line ff
#删除元素
srem line 1

```

#### 5.有序集合(有序set)

存储一个有排序规则的集合，可以做排序相关的业务
（val是不重复list，每个元素可以携带一个数值）

```sh
#创建新建:zadd [key [score val]...]
#每个元素值对应存储一个score分数，之后可以根据这个score进行排序(score相同时按val的首字母排序，score可为小数，不能为非数值)
zadd video 1 baidu.com
zadd video 2 aliyun.com
zadd video 3 teacher.com
#按score的范围查询:zrange [key 0 -1 {withscores}]
#带上withscore后缀会查询出列表的score值，不带只查val
zrange video 0 -1 withscores
#查询集合的元素数量:zcard [key]
zcard video
#查询score范围内的元素数量:zcount [key min max]
zcount video 0 1
#删除元素:zrem [key member...]
zrem video baidu.com
#删除score范围内的元素:zremRangeByScore [key min max {withscores}]
zremrangebyscore video 2 3
#索引范围内按score从大到小排序:zRevRange [key min max {withscores}]
zrevrange video 0 -1
#查询score范围内从大到小排序:zRevRangeByScore [key max min {withscores}]
zrevrangebyscore video 10 2 
```

#### 6.redis事务

redis可以将一堆命令聚合成一个原子队列来执行，要么成功，要么失败

```sh
#开启事务
multi

#开启事务后所有的执行命令会被存储到一个队列中

#结束事务
#通过exec执行事务队列，要么都成功，要都失败
exec
```

#### 7.过期时间

redis可以为存储数据设置过期时间，过期后自动删除

```sh
set name mick
#设置过期时间: expire [key second]
#设置name为10秒过期
expire name 10

#通过ttl命令查询剩余过期时间: ttl [key]
#若key没有设置过期则返回-1，若key不存在则返回-2，存在过期时间返回秒数
ttl name
```

#### 8.订阅发布

通过命令完成订阅发布， 开两个redis客户端，一个广播，一个接收

```sh
#消息订阅:subcribe [channel]
#订阅成功后，会进入阻塞状态，接受广播发布信息
subcribe china
#消息发布:publish [channel val]
#广播发送hello信息,返回订阅用户数
publish china hello
```

发布：

![image-20200917162232340](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103155.png)

订阅：

![image-20200917162313222](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103201.png)

问题处理：

```
//出现(error) NOAUTH Authentication required.时，需要先输入redis密码
auth [redis密码]

//修改redis的远程连接方式
修改redis.conf配置文件的bind和protected-mode
bind改为0.0.0.0(任何ip都可访问)
protected-mode改为no(授权访问关闭)
之后重启redis
```

发布订阅参考：https://blog.csdn.net/higherzjm/article/details/84564288