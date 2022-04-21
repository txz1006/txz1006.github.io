mysql-14(执行计划解析)

### explain执行计划解析

#### explain个字段解析

explain命令会根据查询sql的成本计算情况，拥有索引情况，索引长度情况等条件进行一次综合判断汇总，最后会生成一条或多条执行计划信息，这些执行计划就是这个sql当前的最有查询方式。

下面我们先来看一些查询计划的示例：

一个单表的查询语句：

![image-20210125094008101](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210125094141.png)

两表关联查询语句：

![image-20210125094358105](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210125094358.png)

有子查询的关联语句：

![image-20210125094524034](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210125094524.png)

上面的执行计划信息都不多，但是却告诉了我们这个查询语句将以怎样的方式执行，下面我们来仔细说明一下每个字段的含义。

- \*\*id：\*\*指当前查询是否属于同一个语句查询，一个查询语句对于一个id，如果是则id就是相同的，如果不是，则id会递增，如上图的示例三，子查询的id就是2

- \*\*select_type:\*\*顾名思义，说明了当前查询语句查询类型，如SIMPLE是简单查询，PRIMARY是主查询，SUBQUERY是子查询、DERIVED是衍生查询，MATERIALIZED是生成的磁盘临时表

- \*\*table：\*\*就是当前查询语句的表名信息

- \*\*partitions：\*\*这个字段先忽略，一般用不着

- \*\*type：\*\*这个字段就是说明当前查询是否使用了索引，以怎么样的方式走的索引查询。就是我们之前提到过多的ref、index、const等等。一般来说效率排行是const >eq\_ref>ref>ref\_or_null>range>index>all

- \*\*possible_keys:\*\*可能会用到的索引名称，这个字段会将可以用到的索引都列出来，但是考虑成本等因素，可能会走其中一个索引，或者一个都不走

- \*\*key：\*\*当前查询实际用到的索引

- \*\*key_len:\*\*说明索引这个字段里的最大值的长度是多少，一般是个估值

- \*\*ref：\*\*这个字段说的是和前面的key指的索引字段相关联的字段什么，是一个常量？还是一个其他表的字段？例如：select * from t1 where x1 = 'xxx'语句中，如果t1.x1字段存在索引，则key就是t1.x1的索引名称，而ref就是常量'xxx'

- \*\*rows：\*\*是按照当前查询计划查询数据表的数据，估计能够查出多少条数据出来(不一定准确)；这个查询值是不算非索引条件的。例如：select * from t1 where x0 >3 and x1 = 'xxx'语句中，如果x0字段有索引，x1没有索引；则查询出的rows就是select * from t1 where x0 >3的数据行数量，而 x1 = 'xxx'的过滤条件需要在rows条数据中过滤出来

- \*\*filtered：\*\*就是在rows条数据行中过滤出来了多少百分比的数据出来。例如，select * from t1 where x0 >3查出来的rows是10000条，而filtered的值是20.00，也就是之后根据 x1 = 'xxx'条件又在这10000条数据估计能过滤出了20%的数据，最后计算查询出是数据集是10000 * 20%=2000条数据(值越小越好)

- \*\*extra:\*\*最后一个字段，用来表示当前查询语句是用怎么的方式查询的。常见的有Using where，指当前查询使用了没有索引的where条件、Using index指使用了索引查询、Using join buffer (Block Nested Loop)使用了join buffer 技术进行循环嵌套查询(多表join联查)、Using filesort需要将结果集加载到内存中使用专门的排序算法排序(order by、group by、distinct会出现)、Using temprory会生成临时表来存储一部分子查询结果。

- ```
  Using where:列数据是从仅仅使用了索引中的信息而没有读取实际的行动的表返回的，这发生在对表的全部的请求列都是同一个索引的部分的时候，表示mysql服务器将在存储引擎检索行后再进行过滤。
  Using temporary：表示MySQL需要使用临时表来存储结果集，常见于排序和分组查询。
  Using filesort：MySQL中无法利用索引完成的排序操作称为“文件排序”。
  Using join buffer：改值强调了在获取连接条件时没有使用索引，并且需要连接缓冲区来存储中间结果。如果出现了这个值，那应该注意，根据查询的具体情况可能需要添加索引来改进能。
  Impossible where：这个值强调了where语句会导致没有符合条件的行。
  Select tables optimized away：这个值意味着仅通过使用索引，优化器可能仅从聚合函数结果中返回一行。
  ```

  

#### 大数据表优化实例

**示例1**：使用in关键字查询

SELECT COUNT(id) FROM users WHERE id IN (SELECT user\_id FROM users\_extent\_info WHERE latest\_login_time < xxxxx)

**问题**：用户表信息查询过慢，需要优化

**分析过程**：通过explain查询该语句的查询计划，发现该语句对子查询SELECT user\_id FROM users\_extent\_info WHERE latest\_login\_time < xxxxx进行了磁盘物华，变成了一个磁盘临时表(select\_type是MATERIALIZED)，之后全表扫描了users表数据，并与这个物化临时表进行了关联查询(Using join buffer)，筛选出了一部分目标数据，最后是查询这个join结果集获取结果数据。

在执行完explain命令后，可以通过show warnings命令查询sql的警告信息，发现这个sql使用semi join(半连接，mysql内部查询优化方式的一种)来进行in查询的。

使用semi join半连接后，会将users\_extent\_info 子查询的结果物化成磁盘表，之后全表扫描users表，拿每一条users表的信息去循环比对物化表的数据，比对成功就是目标数据了。

**发现问题**：查询慢的主要原因是子查询进行了MATERIALIZED表物化到磁盘中，这个过程是非常慢的

**解决方式**：方式一，将mysql配置optimizer\_switch中的semijoin=on半连接优化关闭。方式二，改写sql为SELECT COUNT(id) FROM users WHERE ( id IN (SELECT user\_id FROM users\_extent\_info WHERE latest\_login\_time < xxxxx) OR id IN (SELECT user\_id FROM users\_extent\_info WHERE latest\_login_time < -1))添加一个or语句，会取消semijoin优化

**示例2：**

select * from products where category='xx' and sub_category='xx' order by id desc limit xx,xx

**问题：**产品表突然变成慢查询，需要核查优化

**分析过程**：这个表是有索引的index(category,sub_category)，通过explain查询该语句的查询计划，发现该语句没有使用二级联合索引，而是走的PRIMARY主键索引。

**发现问题：**也就是这个表的数据出现某些情况，导致mysql认为走index(category,sub_category)二级索引的成本变高，还不如直接走主键扫描。

**解决方法：**强制使用二级索引进行查询，select * from products force index(index\_category) where category='xx' and sub\_category='xx' order by id desc limit xx,xx

**问题分析：**扫描原因导致index(category,sub_category)二级索引的成本变高？可能是系统增加了新的分类数据，这些分类还没有添加对应的产品信息，所以在查询产品数据时导致二级索引查不到一条数据，二级索引查不到数据，mysql容易将这种情况变成全表扫描，所以就突然变慢了。

示例**3：**

SELECT * FROM comments WHERE product\_id ='xx' and is\_good_comment='1' ORDER BY id desc LIMIT 100000,20

**问题：**评论表的深度分页查询慢，需要优化

**分析过程**：这个表是有索引的index(product\_id)，通过explain查询该语句的查询计划，发现该语句只有product\_id索引，所以在查询出 product\_id ='xx'的数据后，就需要回表查询整个数据行了，这个数据量会非常的大，之后会遍历这些数据过滤到 is\_good_comment='1'的数据，再按照id倒序排列返回结果。

**解决方法：**由于每次只需要去十条数据，所以可以优先只用主键索引，修改后sql为SELECT * from comments a,(SELECT id FROM comments WHERE product\_id ='xx' and is\_good_comment='1' ORDER BY id desc LIMIT 100000,20) b WHERE a.id=b.id。即通过子查询获取到id，只获取id，这样子查询不需要回表，用在这个id结果集去二次关联这个表，让a.id=b.id，这样查询只需要在聚簇索引查询十条数据即可。

#### 技巧：

除了mysql本身的问题外，mysql所在服务器的磁盘IO性能、CPU运算性能、网络IO性能都可能会影响sql的查询速度，如果其中一个指标已到达上限，那么就很可能出现阻塞的情况，从而导致查询变慢。此外，若是数据库有长事务要处理，这个也可能导致数据库的查询变慢。