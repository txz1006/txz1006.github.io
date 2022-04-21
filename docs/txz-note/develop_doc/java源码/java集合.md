java集合

### 一、集合概述

java是强类型语言，除了八种基础类型外，还需要一些常用的集合数据结构类型来存储处理数据，如列表、队列、栈、K-V存储、图等结构。这些结构在java中都有现成的集合对象，也就是本章的讲的Collection集合对象。

Collection集合常用的对象分有三类：List、Set、Map，大致的类关系图如下：

![image-20201003152127488](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103050.png)

List：集合有序列表，用于存储有序元素对象，元素可重复(遍历顺序=插入顺序)

Set：集合元素不重复列表，列表元素无序，且元素唯一不重复

Map：键值对存储列表，根据key能获取对应的value值

### 二、List集合

List接口下有三个常用的列表对象：ArrayList、LinkedList和Vector：

1.ArrayList，作为最常用的列表存储对象，底层由Object数组实现，初始长度为10，由于数组初始化后长度无法改变，需要新建数组对象进行扩容，每次扩充后的容器大小为原来的1.5倍(newCap = oldCap + oldCap >> 1)，容器上限为2的30次方；此外ArrayList数组支持随机访问机制(通过索引下标能直接访问对应内存数值)，但是对于元素的插入和删除效率较低(需要移动较多的元素)

2.LinkedList：一个双向链表存储对象，每一个链表节点由prev、object、next三部分组成，由于采用记录相邻节点地址的方式连接元素，所以节点在内存空间中的位置并不连续，而且占用空间略大、不支持随机访问，但是不会存在容器空置问题(底层由node内部类对象组成，node对象包含pre、itme、next三个元素)

3.Vector：底层由Object数组实现，且基于synchronized实现线程安全，但是由于性能较差，使用较少。初始数组长度为10，每次扩容变为原来的2倍(或者自定义每次扩容的增加量)

```java
//List线程安全对象一般有三种方式:
//Vector，使用较少
List<String> list1 = new Vector();
//使用Collections将ArrayList包装成安全对象
List<String> list2 = Collections.synchronizedList(new ArrayList<>());
//List的线程安全对象一般使用concurrent包下的CopyOnWriteArrayList对象
List<String> list1 = new CopyOnWriteArrayList();
```

**CopyOnWriteArrayList简单介绍**：

该对象线程安全，使用volatite关键字声明Object数组(保证数组最新可见，禁止指令重排)，实现对象可以进行无锁读取，而在新增，修改，删除元素操作上，使用全局ReentrantLock重入锁进行操作前后的加解锁，保证并发环境下数据地一致性。

在数据新增逻辑上使用，每次新增元素，就会复制出一个新数组对象，而且数组长度比原来+1，线程在这个新数组中进行元素添加，完成操作后将数组引用指向这个新的数组(该List对象的数组初始长度为0)。而数组的读取，还是使用的旧数组数据。

所以，实际上CopyOnWriteArrayList采用的是读写分离的设计模式，效率很高，但是不能保证数据的实时性(只能保证最终一致性)，而且因为要频繁的复制新数组，如果List中元素非常的多，那么可能会导致频繁的GC

**使用建议：**

如果List对象读取操作较多，使用ArrayList

如果插入和修改，删除操作较多，使用LinkedList

如果涉及到线程安全问题，建议使用CopyOnWriteArrayList(优先)或Vector

### 三、Map集合

Map接口下常见使用键值对象有HashMap、HashTable、LinkedHashMap、TreeMap

1.HashMap，Map结构中最常使用的对象，Key可为null但不能重复，Value则没用限制，底层由Node数组构成，也就是数组加链表的结构组成；初始长度为16(在第一次put时进行初始化)，扩容因子是0.75f，这是查询性能和空间使用率的一个平衡值(达到当前容器上限的3/4时进行扩容，初始为12)，扩容后的大小为原来容器的一倍(newCape = oldCape << 1)；在进行put操作时需要对key进行判重和处理哈希冲突的问题：

- 新put一个k-v值时，首先根据key的hashcode找到将要存在在Node数组中的位置，判断当前位置是否已经存放过对象，若没用，则直接新建Node对象插入k-v值
  
    ```java
    由于Hash值的范围是2^32位大小，全加起来有40亿多个值，所以是不能直接拿来确定一个元素在hash表中的下标位置的。
    hash = (h = key.hashCode()) ^ (h >>> 16)
    意义：(让数据在容器中分散更加均匀,减少hash冲突)对每个hash值，在它的低16位中，让高低16位进行了异或运算，让它的低16位同时保持了高低16位的特征，尽量避免一些hash值后续出现冲突，即可能会进入数组的同一个位置（造成hash碰撞）。
    所以，在HashMap中，通过将key的hashcode向右位移16位(hashCode的高16位和低16位作异或)，并和Map中创建的数组容器的容量n做按位与操作，得到key在数组中的下标位置index。
    (由于hashcode是2^N次公式上的一个数，又有被除数是A，除数是B，若B是2^N公式上的数，则有A%B == A&(B-1)，所以下方的(n - 1) & hash也等于hash%n，也就是取一个0~n-1的值)    
    index = (n - 1) & hash     
    参考：https://www.zhihu.com/question/28562088
    ```
    
- 若当前位置已经存在对象(之后称为对象p)，则需要判断是否哈希冲突或是修改value的情况；先取插入key的hashcode和对象p中key的hashcode进行比较，若相等，则进一步使用equal()或==判断两个key对象是否相等，若都相等则为修改已经存在对象的value
  
- 若key的hashcode不等、或是key的equal()不等，则为哈希冲突情况发生，则需要将插入k-v值加入到对象p的next指向链表中(当某个对象p的next指向大于8时。即此哈希值的冲突大于等于8同时数组的容器上限大于等于64时，会将对象p的链表改为红黑树结构，用于减少冲突发生时查遍历元素的次数)
  
- ![image-20201202111123441](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201202111130.png)
  
- ![image-20201202111218591](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201202111218.png)
  
- 如果要要进行resize()扩容，那么就会创建一个新的数组对象，对原来元素进行重新取模确定新的插入位置。
  
- 如果一个HashMap对象获取的某个数组元素哈希冲突达到8个元素，那么就会将单链表转化为红黑树(TreeNode)，但是如果红黑树的元素减少到6及以下的数量时，又会转为单链表形式(Node)
  

2.LinkedHashMap，继承于HashMap，在HashMap的数组+链表的基础结构下，使用Entry(Node子类)链表重新实现了的元素的访问方式，包含有head和tail两个首尾节点对象，和LinkedList类似，每个Enrty节点能根据before和after找到相邻的元素，输入和输出均有序(类似队列)，由于采用链表结构，所以输出有序(和插入顺序一致)

![image-20210414100526255](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210414100535.png)

```
LinkedHashMap可以认为是以HashMap为数据存储基础对象，而访问方式却以LinkedList类似，使用链表将一个个元素连接起来，这样就保证了对象元素访问的顺序性(时间复杂度是1，而TreeMap的复杂度是logN)
```

3.HashTable，和HashMap类似的Map结构对象，区别是HashTable是线程安全对象，在进行get/put操作时，使用了synchronized进行上锁，插入数据的key和value不能为null，虽然线程安全，但是效率较低，使用较少（初始值为11，每次扩容为2倍+1）

4.TreeMap，使用红黑树实现的Map结构，特点是数据插入会默认保存为升序(中文按照首字母排)，能够有序的输出节点数据(升序输出)，增删改查操作效率低于HashMap，一般用于Map的key排序时使用该对象(Key不能为null)

```java
//Map线程安全对象一般有三种方式:
//HashTable，使用较少
Map<String, Object> map1 = new HashTable();
//使用Collections将HashMap包装成安全对象(使用一个同类型线程安全对象包装目标对象，包装对象的方法均采用synchronized关键字修饰，效率和HashTable雷同)
Map<String, Object> map2 = Collections.synchronizedMap(new HashMap<>());
//map的线程安全对象一般使用concurrent包下的ConcurrentHashMap对象(jdk1.7基于ReentrantLock分段锁Segment数组实现，jdk1.8后为synchronized和cas实现)
Map<String, Object> map3 = new ConcurrentHashMap();
```

#### ConcurrentHashMap实现

1.在jdk1.7中，ConcurrentHashMap是基于Segment数组->HashEntry数组实现的，本质是也是数组+链表实现的，特点是Segment是继承了ReentrantLock，我们存储的K-V分散在多个Segment对象中，当我们需要进行put命令时，就需要对目标Segment进行加锁，这个Segment是整个Segment数组的一个元素，所以1.7中ConcurrentHashMap的独特性是使用分段锁技术，示意图如下：

![image-20210317101529544](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210317141830.png)

而在jdk1.8时，ConcurrentHashMap是基于优化后的synchronized和cas技术实现的

```
//补充
HashMap是线程不安全的原因：
jdk1.7中，hashmap在进行扩容时，由于采用头插法，可能会出现某个线程陷入扩容死循环的状态
jdk1.8中，hashmap在进行扩容时，由于采用尾插法，虽然处理了死循环问题，但是会有元素被覆盖的问题
所以，对应并发场景，最好采用ConcurrentHashMap等专业的线程安全对象
```

**ConcurrentSkipListMap实现**

ConcurrentSkipListMap是基于跳表实现的Map对象，不仅支持并发操作，而且在高并发情况下，效率更优于ConcurrentHashMap

### 四、Set集合

Set接口下常用的对象有HashSet、LinkedHashSet、TreeSet

1.HashSet，此对象可以看作是去重办的List，底层是基于HashMap完成的(即把HashMap对象中的Key作为存储节点)，所以HashSet的去重标准实际上就是HashMap的key去重标准，先判断hashcode值后判断equal方法是否相同(所以重写equal()必须要重写hashcode())，HashSet特点是无序、唯一

2.LinkedHashSet，此对象是HashSet的子类，同理此Set对象是基于LinkedHashMap实现的，特点同上

3.TreeSet，特点有序、唯一；基于TreeMap实现

```
//Set线程安全对象一般有三种方式:
//使用Collections将HashSet包装成安全对象
Set<String> set1 = Collections.synchronizedSet(new HashSet<>());
//set的线程安全对象一般使用concurrent包下的ConcurrentHashMap对象
Set<String> set2 = new CopyOnWriteArraySet();
```

### 五、集合遍历与集合工具类

#### 1.Iterator遍历

Iterator是一个集合遍历接口，用于遍历集合对象；从上面的类关系图可以发现，Collection接口继承了Iterator接口，也就是List、Set、Queue都有自己Iterator接口的实现；而Map接口也提供了KeySet()和EntrySet()将Map元素转成集合对象进行Iterator遍历。

下面以Map为例进行Iterator遍历：

```java
Map map = new HashMap();
map.put("String", "1");
map.put("Integer", "2");
map.put("Boolean", "3");
Iterator<Map.Entry> mapIt = map.entrySet().iterator();
while(mapIt.hasNext()){
    Map.Entry entry = mapIt.next();
    String key = entry.getKey();
    String val = entry.getValue();
}
```

#### 2.Collections工具类

Collections是java.util包中提供的集合工具类，他提供了很多常用的集合操作静态方法，如集合判空、排序、反转、统计、查找等。

```java
Collections.reverse(List list); //列表反转
Collections.sort(List list); //列表排序
Collections.sort(List list, Comparator e); //列表自定义排序
Collections.swap(List list, int a, int b); //列表中交换a和b位置的元素
Collections.replaceAll(List list, Object oldVal, Object newVal); //列表元素替换
Collections.max(List list); //列表最大元素
//...
```

Collections工具类还提供将集合对象转为线程安全对象的静态方法：

```java
//返回线程安全的集合对象
Collections.synchronizedCollection(Collection c);
//返回线程安全的List
Collections.synchronizedList(List list);
//返回线程安全的Set
Collections.synchronizedSet(Set set);
//返回线程安全的Map
Collections.synchronizedMap(Map map);
```

上述线程安全对象效率不太行，请优先考虑java.util.concurrent包下的集合安全对象