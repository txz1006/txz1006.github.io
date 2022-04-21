mysql-12(索引设计和执行计划 )

### 索引设计和执行计划实践

#### 哪些情况才适合加索引

1.若一个字段的数值基数特别少，如sex性别字段的数值有(1,2)，那么基数就是2，对于这种基数少的字段，建索引是效率不高的。因为索引是用二分法查的，基数小的时候二分法的效率不高，所以，基数高的字段建 索引才 合适

2.建立索引的字段数值或类型应尽量简单，如tinyint等类型

3.对于text、varchar等内容 非常多的字段，可以使用这些字段的前多少个字符来创建索引(前缀索引)

4.\[where function(e) = 123\]，这样在查询条件中对字段进行函数处理后在等值的方式无法使用索引，因为通过函数计算后的结果多半无法和索引排序规则对应

5.一个表的索引不应建太多，一般在2-3个左右就行，这两三个索引最好覆盖大多数查询条件

6.如果数据量不大，主键可以使用递增数值

#### 索引怎么建才合适

1.由于查询在多数情况下只能使用一个索引树，所以当where条件和order by/group by冲突时，一般优先考虑where的查询条件索引，因为where条件可以过滤一大部分非目标数据，而且再通过limit的限制可以将查询结果集的数据量降低很多，此时进行order by/group by的效率其实也不会低太多。

2.在设计联合索引时，应尽量将必选的查询条件放在索引左边，如index(province, city, sex, age)，这样在查询时province, city基本必选，而性别字段sex和年龄age都是可选字段，如果不选性别，却选了age，则可以通过sex in ('F','M') and age>20 and age <25，这样的in范围字段来保证联合索引尽量 全部都被使用

3.如果是范围查询，如>、<大小于等范围查询一般放在联合索引的最后一个字段，因为范围查询会导致结果集的数据中下一个联合索引字段是无序的。

4.尽量使用一两个复制的联合索引覆盖80%的表查询条件，再使用一两个辅助索引复制20%的非典型性查询条件

#### 执行计划类型

我们在一个查询sql前加上 explain关键字后再执行这个语句，就会得到这个语句的查询计划了，查询计划说明了这个sql要以怎样的方式来查询结果数据，是走二级索引(非主键索引)、还是遍历二级索引、或者是直接全表扫描，这些查询方式在查询计划中都有体现，下面我们来了解下常见的执行计划类型。

\*\*const：\*\*如果计划类型是const，则说明查询where条件是走了唯一索引的，而且通过索引直接定位到了一条数据行，这个索引通常是主键或unique key索引的，即每条数据的该索引字段都不同。

\*\*ref：\*\*如果查询计划是ref，说明where条件是通过普通的二级索引查询到的

\*\*ref\_or\_null:\*\*如果查询计划是ref\_or\_null，则查询条件是通过二级索引查询的，但是where还查询了该索引字段为null的数据(只限于等值匹配规则后查询null值)

```
注意：or会导致索引失效，可以用in或分开查询使用union连接
```

![image-20210122104012154](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210812110340.png)

\*\*range：\*\*此类型是通过二级索引查询一个范围的数据，通常是使用>、<、like、between等关键字查询一批数据

![image-20210122105555330](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210122105555.png)

\*\*index：\*\*此类型和其名称并不一致，当执行计划是index时，它会直接遍历索引树的叶子节点索引页,并通过叶子叶子节点的双链表一个个索引页的遍历，直到找全所有目标索引数据。而且查询的字段必须是主键或索引中的字段

![image-20210122112306311](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210812110250.png)

如果查询的是全表数据，那么很可能直接走全表扫描。(在表关联中常用)

![image-20210122112437714](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210122112437.png)

\*\*all:\*\*顾名思义，全表扫描，会直接遍历聚簇索引的叶子节点，也就是一个个数据页的遍历。

#### 索引失效的场景

所有的查询语句都和数据量有关，mysql都会估算成本来判断走不走索引，并不是说使用or、is null、is not null、!=就一定不会走索引，一般情况下在覆盖索引下使用这些条件也会走索引，但是如果要进行回表查询就多半不走索引了，当然有时候回表查询时可以强制使用索引的，但是这样走索引的效率也不一定高，所以，mysql会优先选择查询成本低的一种方式，如果走索引成本高于不走索引，那么就会选择不走索引的方式。

**1.查询条件使用is not null和!=**

如果这些查询仅仅是查询联合索引中的字段或索引字段本身，是会走索引的

!=走了索引：

![image-20210325164326628](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210812110430.png)

is not null走了索引：

![image-20210325164712926](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325164713.png)

需要回表时没有走索引，但是这里possible_keys存在潜在索引可以使用，如果我们强制使用这个索引，那么这个is not null也可以走索引，但是效率不一定会提高

![image-20210325164916092](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325164916.png)

!=全表扫描，不走索引：

![image-20210325165651707](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325165651.png)

**2.使用%开头的字符串进行like模糊查询**

全表查询确实，不走索引

![image-20210325170002690](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325170002.png)

但是仅仅是覆盖索引查询，会走索引

![image-20210325170255321](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325170255.png)

3.**使用not in、not like**

not in全表查询不走索引

![image-20210325170454705](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325170454.png)

not like全表查询不走索引

![image-20210325170949414](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325170949.png)

覆盖索引查询，会走索引

![image-20210325171021878](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325171022.png)

4.**OR引起的索引失效**

or并不是都会引起索引失效，一般会在or连接一个非索引字段时才会失效

单个索引字段的or连用，会走索引

![image-20210325172605363](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325172605.png)

多个索引字段的or连用，也会走索引

![image-20210325172651233](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325172651.png)

or连接非索引字段，不走索引

![image-20210325172740081](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325172740.png)

5.**查询条件左侧使用函数或运算**

条件使用了运算符，不走索引![image-20210325173334093](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325173334.png)

使用了函数也不走索引

![image-20210325173436552](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325173436.png)

6.**查询条件存储类型不一致问题**

resident\_grid\_code是varchar类型，这里给的int条件参数

![image-20210325173208060](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325173208.png)

类型改为字符串后，走了索引

![image-20210325173255901](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210325173256.png)

7.联合索引的范围查询(>、<、like、between and、in、exists、!=)字段未放在查询语句最后