redis-1(安装配置)

#### 一、redis概论

**1.redis简介**

redis是一个内存型的数据库 ，由于直接使用内存，响应速度快，所以有很多应用场景。

**2.redis应用场景**

数据缓存

单点登陆

消息订阅发布模式

流量秒杀、抢购

数据统计排行

**3.redis存储类型**

字符类型

散列类型

列表类型

集合类型

有序集合



**4.特点功能**

每个数据可以设置过期时间

其中可以使用列表类型做分布式队列

可以设置数据的订阅发布模式



#### 二、redis安装

1.下载tar.gz压缩包

2.使用tar -zxvf命令解压源码包

```
tar -zxvf redis-4.0.8.tar.gz
```

3.进入解压目录，使用make命令进行源码编译，使用make test进行测试

```
//若make结果出现错误，则需要安装相关c和C++依赖
yum install -y gcc g++ gcc-c++ make
//之后清空make
make distclean
```

4.使用make install命令进行安装

```
//安装到program/redis路径下
make install PREDIX=/root/program/redis
//之后会在redis文件夹下出现一个斌文件夹里面有6个命令对象
//回到redis解压文件夹下将redis.conf配置文件复制到/program/redis文件夹下即可
```

5.启动redis，设置内存常驻

```
//编辑redis.conf将daemonize设置成yes
//启动，到/program/redis/bin下执行
./redis-server ../redis.conf
```

6.关闭redis

```
./redis-cli shutdown
#安全退出，此命令会在关闭前创建dump.rdb文件
```



#### 三、redis命令

之后的操作都使用redis/bin下的6个控制端进行的

- 关闭redis：./redis-cli shutdown
- 连接redis控制台：./redis-cli
- 连接远程控制台：./redis-cli  -h 127.0.0.1 -p 6379

![image-20200913152715733](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103144.png)

除redis-server和redis-cli外，其他五个的作用简单解释：

- **redis-serve**r：启动redis
- **redis-cli**：连接redis控制台
- redis-benchmark：性能检查工具
- redis-check-aof：文件检测工具
- redis-check-rdb： reb文件检测工具
- redis-sentinel：sentinal(哨兵)配置

#### 四、使用入门

- select [dbid]

  redis默认有16个数据库(0-15)，每个数据库都可进行数据存储，默认存储为0号数据库，使用select [dbid]可以进入不同的数据库，数据库之间可以使用flushall清除数据

- keys [pattern]

  使用keys [pattern]关键字去匹配查询相关的key数据，pattern包括使用？和*

- EXIST [key]

  key数据值是否存在

- TYPE [key]

  key数据值的类型



