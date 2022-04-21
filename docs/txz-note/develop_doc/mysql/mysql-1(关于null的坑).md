mysql-1(关于null的坑)

#### 一、关于NULL值的坑

前文建议，在创建数据表时，应尽量给所有字段设置默认值，不给与null打交道的机会

原因如下：

##### 逻辑判断符(=、!=、>=、<=)和NULL做比较时都返回NULL

也就是两个字段作比较，如果一方为NULL，则这条数据行就会查不到(查不到字段为null的数据行)

##### IN(...)和NOT IN(...)条件判断中如果存在NULL，则会出现以下问题

1. IN(...)条件中存在NULL时，并不会查询到字段为NULL的数据行
2. NOT IN(...)条件中存在NULL时，整个查询结果都是NULL
3. NOT IN(...)查询数据时，查不到字段为NULL的数据行

##### 判断NULL只能用IS NULL和IS NOT NULL

##### 使用COUNT()函数统计时，count(column_name) 只会统计非NULL数据行，count(1)或count(*)则能统计带NULL的数据行

![image-20210722143207406](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210722143207.png)

#### 二、MYSQL引擎与索引

在了解索引前，先了解下几种数结构：

##### 二分法查找元素

在一个有序的数据队列中，使用二分法查找目标元素，复杂度是O(LogN)，由于需要将目标数据维护成有序队形代价过高，不适用于多数据场景。

##### 二叉树查找元素

以根节点为核心，比根节点小的元素挂在左子树上，比根节点大的元素挂在右子树上；在数据查找上效率一般和二分法相同，复杂度上最优解也是O(LogN)，但是由于数据随机性未知，可能会产生每层树结构只有一个元素的情况，那样的结构就成了单链表，复杂度变为O(N)

##### 二叉平衡树(AVL)查找元素

基于二叉树的优化树结构，和二叉树的主要区别是在插入元素到树中时，若插入后左树的高度和右数的高度相差大于1时，会进行树结构平衡，即更换根节点，始终使树的左/右子树的高度之差小于等于1；树平衡时会有右旋、左旋、左右旋、有左旋四种结构的调整，见下图：

![image-20201104170956052](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201104171004.png)

```java
判断是否需要平衡树的步骤有这几步：
1.按照正常的二叉树插入规则插入元素X，之后从插入的节点X向上回溯寻找第一个不平衡的节点A，我们把节点X到节点A之间的路径上的A的子节点称为节点B，A节点的孙子节点称为节点C
2.根据节点X和节点A的位置关系，有四种分类：
    -节点X位于节点A的左孙子树下(见下LL型)，导致节点A的左树高度-右树高度大于1，此时需要对节点A之下(包括节点A)的所有节点进行右旋操作，使树重新平衡
    -节点X位于节点A的右孙子树下(见下RR型)，导致节点A的左树高度-右树高度小于-1，此时需要对节点A之下(包括节点A)的所有节点进行左旋操作，使树重新平衡
    -节点X位于节点A的左儿子节点的右孙子树下(见下LR型)，导致节点A的左树高度-右树高度大于1，此时需要先对节点A之下的所有节点进行左旋，将不平衡类型从LR型变为LL型，之后再对节点A之下(包括节点A)的所有节点进行右旋操作，使树重新平衡
    -节点X位于节点A的右儿子节点的左孙子树下(见下RL型)，导致节点A的左树高度-右树高度小于-1，此时需要先对节点A之下的所有节点进行右旋，将不平衡类型从RL型变为RR型，之后再对节点A之下(包括节点A)的所有节点进行左旋操作，使树重新平衡    
    
参考：https://mp.weixin.qq.com/s/POX8QV9JFrRcAi-q-sJvOA    
```

约定标记：

![image-20201105175142796](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201105175151.png)

LL型失衡调整：

![image-20201105175243754](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201105175243.png)

RR型失衡调整：

![image-20201105175303749](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201105175303.png)

LR型失衡调整：

![image-20201105175333980](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201105175334.png)

RL型失衡调整：

![image-20201105175412199](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201105175412.png)

红黑树(自平衡二叉树)

1.5条限制



参考：https://mp.weixin.qq.com/s/X3zYwQXxq93P_XUzFmKluQ

##### B-树查找元素



##### B+树查找元素

##### 三、join和exist

**left join on (...and...)和left join on ... where ...的区别**

答：两个表作关联时会生成一个中间的关联表数据，on之后使用and是筛选生成中间关联表的数据；而on之后使用where则是先按照两个表的全量数据生成中间关联表后，再对中间关联表做where后的过滤。

参考：https://www.cnblogs.com/caowenhao/p/8003846.html

**exists可以用来取代in关键字,而且一般效率更高**

如果t1表中的id在t2表中查到数据，则exists会返回true，代表t1表中的这条数据符合查询条件

select * from table_1 t1 where exists(select id from table_2 t2 where t1.id = t2.pid)

等同于：

select * from table_1 t1 where t1.id in(select pid from table_2 t2)