mysql-2(基础)

#### 一、mysql的基础使用方式

在所有的编码开发中，有些数据是要保存到磁盘中的，这样才可以一直使用，基本不会丢失；完成这个持久化业务的工具就是数据库软件了，他能帮助开发者完成数据的存储/修改/删除/再读取的操作。

在实际使用中开发者需要将三方数据库提供的驱动加载到DriverManager类中，之后使用该驱动管理创建数据库连接Connection对象，进而可以进行增删改查操作了，下面是一个实例：

```java
public static void main(String[] args) throws ClassNotFoundException, SQLException {
    //加载驱动(将三方mysql驱动对象注入到jdk对象DriverManager中)
    Class.forName("com.mysql.cj.jdbc.Driver");
    //创建连接
    String url = "jdbc:mysql://localhost:3306/mysql?serverTimezone=UTC";
    String username = "root";
    String password = "123456";
    Connection connection  = DriverManager.getConnection(url, username, password);
    //创建访问对象
    Statement statement = connection.createStatement();
    //查询结果
    //ResultSet resultSet = statement.executeQuery("select * from user");
    //或者
    statement.execute("select * from user");
    ResultSet resultSet = statement.getResultSet();
    //遍历获取结果
    while(resultSet.next()){
        String q1 = resultSet.getString("Host");
        String q2 = resultSet.getString("User");
        System.out.println(q1+"=="+q2);
    }
    //关闭连接
    resultSet.close();
    statement.close();
    connection.close();
}
```

#### 二、数据库基本架构

##### 1.连接池

在web系统中，通常会有很多用户来访问系统应用，每一个用户都会分配到一个单独的线程来处理业务逻辑，过程中肯定会涉及到数据库的读写，这就需要用到数据库连接对象了，如果按照上一节的逻辑，每个线程在访问数据库时都要创建/销毁一次连接对象，那么效率肯定低下。

所以，就有了所谓连接池的产生，连接池会维护多个数据库连接对象，而且创建后可复用不会释放，这样用户访问数据库时可以直接拿线程池中的连接对象来用，而且不用管连接对象的其他逻辑。

多个线程使用不同的连接对象访问数据库，对应的在数据库方也要有个连接池对象，需要能够并发的监听和处理请求过来的数据库操作。

##### 2.监听sql请求的线程

数据库会安排一个单独的线程来监听sql请求，当监听到sql请求后会从请求中解析出要执行的sql语句，至此，这个线程会将sql语句交给其他线程来做下一步处理。

##### 3.处理sql的对象

监听sql请求的线程会将sql交给一个sql接口对象，这个对象就是数据库内部处理sql的核心对象，sql接口对象拿到sql语句后，就开始了正式的解析工作。

##### 4. sql查询解析器

sql接口对象首先会将sql语句交给查询解析器，这个对象会分析关键字将sql语句拆分成查询内容/查询表/查询条件(以查询为例)，理解sql语句的具体含义后，就清楚要执行咋样的操作了。

##### 5.查询优化器

查询解析器解析完sql后会将解析结果交给查询优化器，用于选择出一套最优的查询途径来，这套查询逻辑会整理成一个查询计划(就是使用explain查询到的计划)，将之交给下一个处理对象

##### 6.查询执行器

查询优化器会将查询计划交给查询执行器，用于执行这些计划去磁盘或内存中查询数据

##### 7.存储引擎

查询执行器执行计划时，会调用存储引擎接口，通过存储引擎去磁盘或内存中执行遍历出结果数据

- **InnoDB存储引擎**

  在存储引擎执行查询计划时可以分为以下几步：

  1. 查询引擎中的buffer pool(缓存池中有没有需要的数据)，有直接查询并返回结果；没有则进一步到磁盘中读取数据并将之加载到缓存池中，在操作数据前会对数据行添加独占锁，之后就可以处理数据了
  
  2. 以update修改语句为例，加锁后就可以修改数据了；在修改前，会将修改前的旧数据写入undo.log日志，用于事务回滚；之后执行修改数据动作
  
  3. 缓冲池的数据修改后(注意：此时仅是缓冲池的数据修改了，但是磁盘中的数据还是旧数据)，会将修改过程写入一个log buffer pool缓冲池中，这个日志缓冲池会记录下缓冲池中修改数据的sql动作，并写入到redo.log日志中，可用于恢复mysql宕机后缓冲池没有执行完的sql命令(前提是redo日志已经刷到磁盘中)。需要注意的是，写入redo.log日志有个配置参数innodb_flush_log_at_trx_commit，可以选择写入redo日志的策略：
     - 当策略为0时，不会生成写入redo.log日志(当缓冲区执行sql宕机时，会丢失缓冲池所有正在执行的操作sql)
     - 当策略为1时，每次要提交事务前，会将log缓冲池中的数据写入到磁盘redo.log日志文件中(事务提交成功后，即使宕机了，也可以使用redo.log恢复buffer pool中修改后的数据)，默认策略
     - 当策略为2时，每次要提交事务前，会将log缓冲池中是数据写入到os cache中，os cache会定时将数据刷到磁盘对应的redo.log日志文件中(由于os cache会有一定的延迟，所以此策略下宕机会有1秒钟的数据丢失)
     
  4. 在写入的redo日志的过程中，mysql还有一个归档日志binlog会记录下当前sql操作的逻辑，这个binlog是属于mysql server本身，而不属于存储引擎，这是他和redo日志的区别。binlog写入磁盘的策略有一个配置参数控制sync_binlog，而写入策略也有两种：
  
     - 当策略为0时(默认策略)，提交事务时会将，日志信息写入到os cache中，再由os cache延迟刷入到磁盘的binlog文件中
     
     - 当策略为1时，提交事务时会强制将日志信息直接写入到磁盘binlog文件中，默认策略
     
     当binlog写入成功后，会在redo日志中写入一个commit标记，表示binlog已经记录完本次变更，之后准备提交事务时，redo日志才会写入磁盘，redo日志写入成功后，事务也能提交成功

  5. 事务提交成功后，buffer pool中的数据是修改过的数据，但是磁盘还是旧数据，所以会有个后台线程会延迟将buffer pool中的脏数据刷入到磁盘存储，这就完成了以整个sql过程。
  
     
     
     整个sql操作图如下：
     
     ![image-20201222142930547](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201222142945.png)
     
     

PS：在事务提交前mysql宕机了的数据会有一致性问题吗？

不会，这个过程中可能在刷redo日志、刷binlog日志，写commit标记到redo日志等几个节点过程宕机，当commit标记写入成功，基本算事务已经提交成功了。我们可以以commit标记是否成功写入作为分割点，在commit标记写入前宕机了都算是当前事务执行失败，不会影响磁盘数据。当commit标记写入成功后宕机了，无论是否已经正真提交事务，也不会影响数据一致性，因为再次重启数据库后，可以通过redo日志恢复事务数据。