mysql-15(搭建主从同步mysq)

### 搭建主从复制架构

如果一台mysql服务器的极限是每秒抗4000读写请求，而多数数据库的状况是读多写少的实际情况，如写入速度是3000TPS，读取是4000QPS，一共是7000读写请求，远超4000请求的。所以需要进行读写分离，即搭建主从复制数据库架构，写入的请求只写入主库中，之后主库将数据复制给从库，读取的请求则读取从库的数据，这样两台mysql服务器旧可以抗住这7000读写请求了，而且还有负载余力。主从架构搭建好后，就可以通过MyCat或Shareding-Sphere等中间件实现程序的读取从从库中请求，写入从主库中请求。

而主从架构的大概原理是这样的：

1.  从库建立与主库的TCP连接，并向主库请求binlog文件信息
    
2.  主库通过dump线程将binlog日志通过网络传输给从库服务器
    
3.  从库接受倒主从的binlog日志后，会将这些日志写入本地relay日志文件
    
4.  从库会使用一个sql线程将relay日志数据重做倒从库的数据库中
    

![image-20210127150429855](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210127150505.png)

#### 1.环境准备

需要两台装有Mysql5.6以上版本数据库的服务器，并且3306端口互相开放，可以ping通。注意在搭建主从架构时应避免有新数据写入数据库。

#### 2.主库配置

选择其中一台服务器的mysql作为主库，导出当前主数据库的所有备份数据和binlog信息：

使用mysqldump导出当前数据库所有数据，mysqldump执行文件在mysql/bin文件夹下

```sql
--在当前文件夹下导出.sql文件夹
mysqldump --single-transaction -uroot -p123456 --master-data=2 --all-databases --triggers --routines --events -A > backup.sql
```

我们将backup.sql导出来放到从库发服务器中

#### 2.从库配置

若主库中已有生产数据，则需要通过主库的backup.sql将旧数据写入倒从库中：

```sql
-- 在mysql中通过source命令导入sql文件
source /home/backup.sql
```

若主库无数据，则可以跳过数据导入。

在从服务器开启主从同步：

```sql
change master to master_host= '193.112.44.154', 
master_user='root', master_password='pengwenbo' ,MASTER_LOG_FILE='mysql-bin.000007', MASTER_LOG_POS=2516;
```

注意MASTER\_LOG\_FILE和MASTER\_LOG\_POS等信息都要配置主库的信息，可以在主库中通过**show master status**命令查看

配置完成后，可以通过**show slave status**查询主从配置数据，此时，Slave\_IO\_Running和Slave\_SQL\_Running都是no，代表主从服务并未开启。

通过命令\*\*start slave；\*\*开启从服务器请求主库binlog日志信息线程

开启后，再通过**show slave status**查询主从配置数据，发现Slave\_IO\_Running和Slave\_SQL\_Running都是no变为Yes，则主从配置成功。

配置成功后，选择一个主从库中都有的数据表，在主库中新增一条数据，回到从库中发现数据已经复制到了从库。

#### 3.其他问题

1.断开主从结构，需要在从库中执行下列命令：

```sql
stop slave;
reset slave all;
```

2.若命令**start slave；**执行后，发现Slave\_IO\_Running和Slave\_SQL\_Running还是no状态，则可以，在**show slave status**查询中看Last_error字段的错误详情。

如出现 master and slave have equal MySQL server ids;问题时，要修改mysql服务器id（默认为1）

```sql
show variables like 'server_id';
set global server_id=2;
```

再次start slave，发现Slave\_IO\_Running和Slave\_SQL\_Running均开启

#### 4.半同步

上述的主从架构是传统的主从架构，属于异步复制。就是主库将binlog日志通过网络传输给从库就结束，至于从库收到数据了没有，主库是不清楚的。所以，在实际的主从复制会采用半复制的方式，即主库复制数据倒从库后需要等待从库返回成功的信息后，主库才会提交当前事务。

半同步是实现有两种，一种是通过mysql的扩展插件实现的，另一种是mysql5.7的默认主从复制方式。

下面来看插件实现半同步的操作：

```sh
-- 在异步复制的基础上按照执行插件命令即可
-- 在主库中执行
install plugin rpl_semi_sync_master soname 'semisync_master.so'; 
set global rpl_semi_sync_master_enabled=on; 
show plugins; 
```

可以看到你安装了这个插件，那就ok了。

接着在从库也是安装这个插件以及开启半同步复制功能：

```sh
install plugin rpl_semi_sync_slave soname 'semisync_slave.so'; 
set global rpl_semi_sync_slave_enabled=on; 
show plugins; 
```

接着要重启从库的IO线程：

```sh
stop slave io_thread; 
start slave io_thread; 
```

然后在主库上检查一下半同步复制是否正常运行：**show global status like '%semi%';**，如果看到了 Rpl\_semi\_sync\_master\_status的状态是ON，那么就可以了。

#### 5.GTID主从同步

除了传统的主从复制外，还有一种GTID的主从复制方案

参考：https://my.oschina.net/u/3678773/blog/4402960

#### 6.主从复制延迟问题如何处理

通过show status；寻找Second\_Bhind\_Master参数，这个指的是从库获取到主库数据的延迟(ms)

可以通过percora-toolkit工具在监控主从数据库的延迟状况

1.通过Mycat、Shareding-Sphere等中间件，对于新写入的数据让请求强制去读主库的数据

2.在从库设置参数，将slave\_parallel\_workers设置为大于0的数，将slave\_parallel\_type设置为LOGICAL_CLOCK，让从库使用多线程并行复制主库的binlog数据

3.主库配置sync\_binlog=1，innodb\_flush\_log\_at\_trx\_commit=1
sync_binlog的默认值是0，MySQL不会将binlog同步到磁盘，其值表示每写多少binlog同步一次磁盘。
innodb\_flush\_log\_at\_trx_commit为1表示每一次事务提交或事务外的指令都需要把日志flush到磁盘。
注意: 将以上两个值同时设置为1时，写入性能会受到一定限制，只有对数据安全性要求很高的场景才建议使用，比如涉及到钱的订单支付业务，而且系统I/O能力必须可以支撑！

====================
如何延迟还比较严重那么可以这么做：
1.把主库拆成多个主库
2.直接查询主库
3.重写代码，延迟读取(如支付后跳转到支付成功页面，再返回，这个时间肯定复制成功了)

#### 7.mysql主从架构高可用

如果保证主从mysql架构中，主库挂了，会自动将一个从库升级为主库，其他从库重新挂倒这个新主库上？

使用mysql的MHA软件配置即可，MHA是perl语言写的mysql脚本 ，实现的效果类似于redis的哨兵模式。