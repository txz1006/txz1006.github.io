mysql-7(redo.log和undo.log)

### redo.log和undo.log日志解析

#### redo日志解析

在之前的mysql结构中，我们知道mysql在执行一条sql时会写undo.log日志用于事务回滚，修改内存数据后会写redo.log，用于防止事务数据丢失，下面我们就来具体探究下着两个过程：

![image-20210109173906536](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210109173906.png)

首先来看redo.log日志的生成。在修改完buffer pool中的数据页数据后就会生成一条redo日志信息，格式大概是这样的：

```
表空间号+数据页号+数据页偏移量+修改数据的字节数+实际的修改数据
```

生成这样一条数据后，并不会直接放入到log buffer pool中，而是需要等到当前事务中的Sql全部执行完成后，将多条redo日志作为一个redo log group(日志组)写入到log buffer pool中。

![image-20210109194724670](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210109194724.png)

log buffer pool和buffer pool类似，在mysql启动后会在分配一块内存区域作为日志 写入的缓冲池，这个缓冲池中会划分出一个个的redo log block，就和存储行数据的数据页类似，他的结构是这样的：

![image-20210109200520114](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210109200520.png)

在未使用前，这些日志块都是空的，等待数据的写入。当收到一个redo日志组数据后就会写到这些日志块中并等待被写入磁盘中的redo.log文件中，整个redo日志的写入流程如下：

![image-20210109201603195](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210109201603.png)

下面来了解下触发redo log block刷入磁盘的几种状况：

- 当 log buffer pool中的redo日志数据量已经达到当前缓冲池的一半大小时，会触发redo日志写入磁盘中

```
log buffer pool的大小可以通过查询innodb_log_buffer_size参数来查看，默认是16M的大小，当log block的大小达到8M时就会 将所有的redo日志刷入磁盘中
```

- 当事务提交时，会将redo日志所在的log block刷入磁盘中
- 定时线程任务，每秒会执行一次，将log block刷入磁盘中
- 关闭mysql进程后会将所有的log block刷入磁盘中

一般情况下，第一种情况很难发生(在一秒钟内给log buffer中写入8M的数据)，所以我们一般用得到的是第二和第三种情况。

redo日志会在第二、三种机制下将redo日志不停的刷入磁盘的redo日志文件中，这样当事务成功提交后，redo日志一定写入了磁盘文件，哪怕此时服务宕机了也可以使用redo日志恢复数据。

这里还有一个点需要注意，那就是磁盘中的redo日志文件不会一直增加，而是保存一定的大小后反复循环覆盖的写入。

在MySQL中可以指定redo日志输出位置，通过show variables like 'datadir%'，来设置mysql输出文件的根目录，通过innodb_log_group_home_dir来设置redo日志的位置。此外，可以通过设置innodb_log_file_size来控制日志文件的大小，默认值是48M；而且redo  log是额可以输出两个日志文件的，通过innodb_log_files_in_group来设置，默认值为2，就是可以输出两个日志文件，每个文件是48M，当两个文件动后写满后就会覆盖第一个日志文件继续存储。

日志一般默认在mysql目录下的data文件夹下，redo日志的默认文件 如下图所示，ib_logfile0和ib_logfile1

![image-20210109204119771](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210109204119.png)

#### undo日志解析

当一个事务执行过程中有一个sql语句执行失败了，要进行事务回滚，把这个事务之前修改成功的表数据修改回到事务执行之前。那么就必然存在记录了修改前的数据的文件，这个文件就是undo.log日志，它会在undo日志中记录下执行sql相反的sql，如：

```
执行一条 insert语句，那么在undo日志会记录一条delete语句
执行一条delete语句 ，就会在undo日志中记录多条insert语句
执行update语句将A改为B，那么在undo日志中就会有一条日志将B改为A
```

而一条undo日志的格式是这样的：

![image-20210111164118857](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210111164127.png)

此外，可以通过innodb_max_undo_log_size设置undo最大日志文件大小值(默认为1个G)，通过innodb_undo_directory设置undo日志输出位置，通过innodb_undo_tablespaces设置undo日志的数量(默认是2个)。

![image-20210111171745311](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210111171745.png)

 