JVM-7(模拟实机GC)

### 模拟实机GC

本节我们通过自己设置JVM参数，来模拟实践我们之前讲过的GC知识。

首先我们需要了解几个GC打印配置参数：

```sh
-XX:+PrintGCDetails   ##打印详细的GC信息
-XX:+PrintGCTimeStamps ##打印GC发生的时间
-Xloggc:gc.log   ##将GC信息输出成gc.log
```

然后我们设置一个比较小的堆空间，参数如下：

```sh
## 测试JDK使用的1.8版本
## 堆空间设置为10m，其中新生代为5m，直接进入老年代对象大小限制为10m
-XX:InitialHeapSize=10485760 -XX:MaxHeapSize=10485760 -XX:NewSize=5242880 -XX:MaxNewSize=5242880 -XX:SurvivorRatio=8 -XX:PretenureSizeThreshold=10485760 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:gc.log
```

下面我们就以此配置为基础来测试验证GC逻辑。

##### 1.模拟Young GC

先来看一段代码：

```java
    public static void main(String[] args) {
        //创建一个1m的字节数组对象，使用引用对象a指向这个数组对象
        byte[] a = new byte[1024  * 1024];
        //再创建一个1m的字节数组对象
        a = new byte[1024  * 1024];
        //再创建一个1m的字节数组对象
        a = new byte[1024  * 1024];
        //放弃对象的引用指向
        a = null;
        //创建一个2m的字节数组对象
        byte[] b = new byte[2 *1024  * 1024];
    }
```

这段代码就是创建了多个字节数组对象，由于之前我们配置的JVM参数中新生代只有5m，所以实际上年轻代的eden区为4m，两个survivor区各0.5m，对于上述代码的对象分配，如果不进行Young GC，一次性是放不下这5m的数组对象的，下面我们来分步骤解析下这个GC过程。

我们在idea中加入JVM的配置参数：

![image-20210221145439376](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210221145439.png)

然后执行一次main方法，我们就会发现项目目录中出现了一个gc日志文件：

![image-20210221145616948](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210221145617.png)

其中的gc日志如下：

```sh
## JVM当前配置信息
Java HotSpot(TM) Client VM (25.31-b07) for windows-x86 JRE (1.8.0_31-b13), built on Dec 17 2014 20:46:12 by "java_re" with MS VC++ 10.0 (VS2010)
Memory: 4k page, physical 16648500k(8607424k free), swap 26609972k(12022352k free)
CommandLine flags: -XX:InitialHeapSize=10485760 -XX:MaxHeapSize=10485760 -XX:MaxNewSize=5242880 -XX:NewSize=5242880 -XX:OldPLABSize=16 -XX:PretenureSizeThreshold=10485760 -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:SurvivorRatio=8 -XX:+UseConcMarkSweepGC -XX:-UseLargePagesIndividualAllocation -XX:+UseParNewGC 
## GC详情信息
0.136: [GC (Allocation Failure) 0.136: [ParNew: 3720K->510K(4608K), 0.0030540 secs] 3720K->1913K(9728K), 0.0032218 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
## GC结束后的堆空间详情
Heap
 par new generation   total 4608K, used 3743K [0x05800000, 0x05d00000, 0x05d00000)
  eden space 4096K,  78% used [0x05800000, 0x05b28618, 0x05c00000)
  from space 512K,  99% used [0x05c80000, 0x05cff9c8, 0x05d00000)
  to   space 512K,   0% used [0x05c00000, 0x05c00000, 0x05c80000)
 concurrent mark-sweep generation total 5120K, used 1403K [0x05d00000, 0x06200000, 0x06200000)
 Metaspace       used 118K, capacity 2280K, committed 2368K, reserved 4480K

```

我们就以这个gc日志结合main方法代码来分析下这个日志内容。

首先来看第一阶段，也就是引用a创建的3个数组对象，每个对象1m，这对于4.5m的eden区(4m的eden区+一个s区)而言是不需要GC的

![image-20210221144103823](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210221144111.png)

三个对象创建完后，将引用a指向置null，这样三个数组对象就变成了没有被引用的垃圾，示意图如下：

![image-20210221145111092](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210221145111.png)

然后第二阶段，需要创建一个2m的对象，然而此时的eden区剩余空间是不够2m的，所以会触发一次Young GC，对应GC日志如下：

```sh
0.136: [GC (Allocation Failure) 0.136: [ParNew: 3720K->510K(4608K), 0.0030540 secs] 3720K->1913K(9728K), 0.0032218 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
```

- 0.136是JVM在运行0.136秒时发生了此处GC
- GC的原因是Allocation Failure，空间分配失败
- 发生的GC详情是[ParNew: 3720K->510K(4608K), 0.0030540 secs]，垃圾回收器是ParNew，也就是发生的Young GC，GC前后新生代空间占用变化是3720K->510K，新生代的总可用空间是4608K(eden区+一个S区的大小之和)，此次GC花费时间是0.0030540秒(3ms)，整个堆空间的使用变化情况是3720K->1913K(9728K), 0.0032218 secs，9728K的大小是eden区+一个S区+老年代的大小之和

对应到代码逻辑就是，我们创建三个数组对象后还需要创建一个2m的对象，但是此时eden区空间不足，于是发生了 此次GC。其中三个数组对象的大小是3720K，在GC后还有510K，这510K数据会进入S区，等待下次GC时触发动态年龄判断，从而升入老年代中。

此次GC后堆空间的分配情况如下 ：

```sh
Heap
 par new generation   total 4608K, used 3743K [0x05800000, 0x05d00000, 0x05d00000)
  eden space 4096K,  78% used [0x05800000, 0x05b28618, 0x05c00000)
  from space 512K,  99% used [0x05c80000, 0x05cff9c8, 0x05d00000)
  to   space 512K,   0% used [0x05c00000, 0x05c00000, 0x05c80000)
 concurrent mark-sweep generation total 5120K, used 1403K [0x05d00000, 0x06200000, 0x06200000)
 Metaspace       used 118K, capacity 2280K, committed 2368K, reserved 4480K
```

eden区使用了78%，约是3194K左右，这个大小是GC后写入的2m数组对象，S from区使用99%，也就是GC后存活的510K数据会进入S区，S to区没有被使用。老年代是 5120K，已经被使用了1403K。

到这里我们基本可以看懂此次GC的详细解释了，但是其中会有些地方对不上，比如三个1m的对象为什么是3720K？GC后的510K对象是什么东西？

关于这个可以简单认为我们创建一个对象时，除了创建对象本身外还会附加创建一些当前对象的描述对象，也就是一个对象在堆中的实际大小会比定义的数据大一些。

```
注意：可以的话最好将代码打成Jar包放到linux系统下执行，直接使用windos系统，idea等编辑器执行代码会有一些误差。
```

##### 2.模拟S区动态年龄判断进入老年代

我们完善下之前的main方法，再创建一个2m的对象，这样就会触发二次Young GC，而且由于之前的S区已经使用了99%，超过了50%，会将年龄大于等于1的对象移动到老年代中。

```java
    public static void main(String[] args) {
        byte[] a = new byte[1024  * 1024];
        a = new byte[1024  * 1024];
        a = new byte[1024  * 1024];
        a = null;
		//发生一次GC
        byte[] b = new byte[2 *1024  * 1024];
        //如果没有下面的引用置null，那么在二次GC时上面的2m对象会存活
        b = null;
        //需要再创建一个2m的对象，发生二次GC
        b = new byte[2 * 1024  * 1024];
    }
```

我们执行下代码，得到下面的GC数据：

```sh
0.119: [GC (Allocation Failure) 0.119: [ParNew: 3932K->491K(4608K), 0.0014414 secs] 3932K->491K(9728K), 0.0015260 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
0.128: [GC (Allocation Failure) 0.128: [ParNew: 2539K->0K(4608K), 0.0040190 secs] 2539K->2541K(9728K), 0.0040779 secs] [Times: user=0.00 sys=0.00, real=0.01 secs] 
Heap
 par new generation   total 4608K, used 2089K [0x00000000ff600000, 0x00000000ffb00000, 0x00000000ffb00000)
  eden space 4096K,  51% used [0x00000000ff600000, 0x00000000ff80a558, 0x00000000ffa00000)
  from space 512K,   0% used [0x00000000ffa00000, 0x00000000ffa00000, 0x00000000ffa80000)
  to   space 512K,   0% used [0x00000000ffa80000, 0x00000000ffa80000, 0x00000000ffb00000)
 concurrent mark-sweep generation total 5120K, used 493K [0x00000000ffb00000, 0x0000000100000000, 0x0000000100000000)
 Metaspace       used 3008K, capacity 4486K, committed 4864K, reserved 1056768K
  class space    used 321K, capacity 386K, committed 512K, reserved 1048576K
```

我们发现在二次Young GC后，2539K->0K(4608K)直接变为了0，两个S区占用率都是0%，也就是年轻代空了，这明显不是都被清理，往后看到老年代的空间被用了493K，这是第一次GC后存活的对象大小，也就是说S区的500K左右通过动态年龄判断进入了老年代中。

##### 3.模拟Young GC后存活对象过大进入老年代

改造上面的main方法，让引用a有一个1m的对象会在GC后存活。

```java
public static void main(String[] args) {
    byte[] a = new byte[1024  * 1024];
    a = new byte[1024  * 1024];
    a = new byte[1024  * 1024];

    byte[] b = new byte[2 *1024  * 1024];
}
```

执行下代码，得到下面的GC数据：

```sh
0.118: [GC (Allocation Failure) 0.118: [ParNew: 3850K->491K(4608K), 0.0021226 secs] 3850K->1517K(9728K), 0.0022178 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
Heap
 par new generation   total 4608K, used 2621K [0x00000000ff600000, 0x00000000ffb00000, 0x00000000ffb00000)
  eden space 4096K,  52% used [0x00000000ff600000, 0x00000000ff814930, 0x00000000ffa00000)
  from space 512K,  95% used [0x00000000ffa80000, 0x00000000ffafacb0, 0x00000000ffb00000)
  to   space 512K,   0% used [0x00000000ffa00000, 0x00000000ffa00000, 0x00000000ffa80000)
 concurrent mark-sweep generation total 5120K, used 1026K [0x00000000ffb00000, 0x0000000100000000, 0x0000000100000000)
 Metaspace       used 3005K, capacity 4486K, committed 4864K, reserved 1056768K
  class space    used 321K, capacity 386K, committed 512K, reserved 1048576K
```

我们发现GC后的大对象并不是都进入了老年代中，其中的隐藏对象还是进入了S区中，而eden区a指向的那个1m在S区放不下就直接进入了老年代中，后面的老年代中有 1026K被使用就是这么来的。

#### 常用JVM监控命令工具

接下来我们介绍一些常用的JVM监控工具，能尽快帮助我们了解JVM的内存变化。

无论是上面操作系统，首先我们需要知道当前 JVM进程的PID是多少，例如linux系统可以使用使用ss -atnlp |grep java命令来查询PID信息：

![image-20210220162218641](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220162420.png)

##### jstat的使用

我们先列出一些常用的jstat命令：

```sh
jstat -gc [PID]  ##打印JVM所有堆内存占用情况

jstat -gcnew [PID]  ##年轻代GC分析(其中TT和MTT是年轻代中存活对象的年龄和最大存活年龄)
jstat -gcnewcapacity [PID]  ##年轻代内存分析

jstat -gcold [PID]  ##老年代GC分析
jstat -gcoldcapacity [PID] ##老年代内存分析

jstat -gcmetacapacity [PID] ##元空间内存分析

jstat -class [PID] ##JVM加载class数量分析
```

以jstat -gc命令为例，我们在windows的dos窗口执行下这个命令得到如下结果：
![image-20210222150303846](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222150317.png)

其中的参数含义如下：

```sh
S0C ##Survivor0区的分配大小(kb)
S1C ##Survivor1区的分配大小(kb)
S0U ##Survivor0区的已经使用的空间大小(kb)
S1U ##Survivor1区的已经使用的空间大小(kb)

EC ##Eden区的分配空间大小(kb)
EU ##Eden区的已经使用的空间大小(kb)

OC ##老年代的分配空间大小(kb)
OU ##老年代的已经使用的空间大小(kb)

MC ##永久代的分配空间大小(kb)
MU ##永久代的已经使用的空间大小(kb)

YGC ##系统总共的Young GC次数
YGCT ##Young GC花费时间(s)

FGC ##系统总共的Full GC次数
FGCT ##Full GC花费时间(s)

GCT ##所有GC的耗时总和(s)
```

在jstat命令后还可以跟两个参数一个是打印时间间隔，还有一个是打印次数，这样我们就可以观察JVM周期性的变化了。

例如，下面是每隔1秒打印一次年轻代的内存数据，一共打印10次

![image-20210222151640316](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222151640.png)

在了解jstat命令的基础使用方法后，我们就可以来分析JVM的一些内存变化了，主要有这么几个常用的标准需要核查：

Young GC触发的频率、每次Young GC后存活对象的大小、每次Young GC后进入老年代的对象大小、老年代占用空间增长速率、Full GC频率以及Full GC时长。

比如你Eden区有800MB内存，那么发现高峰期每秒新增5MB对象，大概高峰期就是3分钟会触发一次Young GC。日常期每秒新增0.5MB对象，那么日常期大概需要半个小时才会触发一次Young GC。

比如系统运行24小时后共发生了260次Young GC，总耗时为20s。那么平均下来每次Young GC大概就耗时几十毫秒的时间。

比如3分钟会有一次Young GC。那么此时我们可以执行下述jstat命令：jstat -gc PID 180000 10。这就相当于是让他每隔三分钟执行一次统计，连续执行10次，这样就可以观察老年代空间的变化推断每次Young GC后有多少对象是存活和进入老年代。



##### jmap和jhat的使用

我们用jstat可以观察JVM的内存变化，那么下面我们可以用jmap和jhat来分析内存使用的分配占比，比如哪些对象占用的空间最多，哪些对象创建的数量最多等等，我们可以通过分析这些数据来将这些对象的存活时间降低（指将这些对象的引用改为局部变量）来释放出更多的空间。

我们先来看jmap命令，我们可以通过jmap -heap [PID]来获取JVM中基础内存使用情况，和jstat的数据类似：

![image-20210222164244170](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222164244.png)

然后是下一个命令jmap -histo [PID]来获取JVM内存中对象的分配情况：

![image-20210222164729553](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222164729.png)

这是JVM中各个对象按照占用空间的大小进行排序的列表。

当然我们也可以将这些数据输出成快照文件，使用其他可视化工具进行详细的分析：

使用jmap输出快照文件：jmap -dump:live,format=b,file=dump.hprof [PID]，输出后我们会得到一个dump.hprof文件

![image-20210222165205405](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222165205.png)

之后我们就可以使用jhat命令来分析这个快照文件了，命令是jhat dump.hprof，这样jhat命令会开启内置服务器并启动一个7000端口的项目，之后我们就可以通过访问本地7000端口来具体分析这个快照文件的内容了：

![image-20210222165657084](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222165657.png)

访问本地7000端口：http://localhost:7000/

![image-20210222165756784](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222165756.png)

我们可以点击各个类名称来分析类的占用情况。

##### jstack的使用

jstack是分析线程的命令工具，可以用来分析死锁问题、哪个线程使用CPU占用率高等情况

#### JVM监控实例

下面我们来做一些JVM监控实例

首先我们配置一些JVM参数：

```
-XX:InitialHeapSize=209715200 -XX:MaxHeapSize=209715200 -XX:NewSize=104857600 -XX:MaxNewSize=104857600 -XX:SurvivorRatio=8 -XX:PretenureSizeThreshold=10485760 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:gc.log
```

堆空间设置了200M，其中年轻代为100M(Eden区80M，S区个10M)。

然后是测试代码：

```java
public class AllGCTests {

    public static void main(String[] args) throws InterruptedException {
        Thread.sleep(30000);
        while(true){
            loadData();
        }
    }

    public static void loadData() throws InterruptedException {
        byte[] arr = null;
        //每次大约创建5M的数据
        for(int i=0; i < 50; i++ ){
            arr = new byte[100 * 1024];
        }
        arr = null;
        Thread.sleep(1000);
    }
}
```

逻辑不复杂，就是先休眠30秒，之后每秒大约创建5M的数据对象。按照JVM参数在开始创建对象后，大约16S左右就会进行一次Young GC。

我们使用jstat -gc [PID] 1000 500命令来打印下JVM内存的变化，jstat监控图如下：

![image-20210222174602373](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210222174602.png)

我们可以分析下上面这个列表：

首先项目启动后Eden区默认创建了4915K的数据，在休眠30秒后，开始以每秒大概5M的数据量进行增长(4915->9816->14816->19817等等)，经过了15秒后，第16秒的打印Eden区数据从79827变为3089，也就是发生了第一次Young GC(GC时长为1ms)，而且S1区占用率从0变为了981k，这和我们理论上得出的结果一致。

JVM优化目标：Young GC一般10s以上一次每次10ms以内， full gc十分钟以上一次每次1s以内。

##### 模拟Full GC

将直接进入老年代对象限制 大小改为20M，-XX:PretenureSizeThreshold=20971520

测试代码如下：

```java
public class AllGCTests {

    public static void main(String[] args) throws InterruptedException {
        Thread.sleep(30000);
        while(true){
            loadData();
        }
    }

    public static void loadData() throws InterruptedException {
        byte[] arr = null;
        for(int i=0; i < 4; i++ ){
            arr = new byte[10 * 1024 * 1024];
        }
        arr = null;

        byte[] data1 = new byte[10 * 1024 * 1024];
        byte[] data2 = new byte[10 * 1024 * 1024];

        byte[] data3 = new byte[10 * 1024 * 1024];
        data3 = new byte[10 * 1024 * 1024];
        Thread.sleep(1000);
    }
}
```

代码也很简单，就是先创建40M左右的垃圾对象，之后再创建3个10M的有引用对象，给data3再创建10M对象时会导致Eden区不足触发一次Young GC，由于存活对象有data1、data2、data3共30M对象，这些对象是放不进S区的，所以会直接进入老年代中，然后清空Eden区并写入最后的10M对象。

通过jstat命令监控如下：

![image-20210223104909862](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210223104909.png)

可以发现在红框第一行发生了第一次Young GC，S区进入了883K的未知对象，Eden区在GC后重新写入了10M的对象数据，老年代新增了30M的数据，这些都和理论推导一致，需要注意的是此次GC并没有将年轻代的全部对象都转移到老年代中，仍然有883K的未知对象进入了S区中。

在之后的几秒中每一秒都发生一次Young GC，老年代从30M一直增长到60M多，每次增长20M~30M多，在60M左右是无法再容纳一次年轻代GC进入老年代的30M对象，所以会触发一次Full GC，清空老年代。然后又有年轻代存活的30M数据 进入老年代，所以就有了老年代60M多数据变为了30M数据。

整体上说就是每秒都会Young GC，每3~4秒进行一次Full GC

**那么如何优化JVM呢？**

增加S区大小防止Young GC对象进入老年代。

我们将年轻代增加到200M，Eden区和S区的比例变为2:1:1

```
-XX:InitialHeapSize=314572800 -XX:MaxHeapSize=314572800 -XX:NewSize=209715200 -XX:MaxNewSize=209715200 -XX:SurvivorRatio=2 -XX:PretenureSizeThreshold=20971520 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:gc.log
```

再次启动项目，监控JVM变化：

![image-20210223112346857](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210223112346.png)

这样修改后，我们发现老年代的占用率明显降低，只有在S区占用率超过50%后达到30多M后，才会有833K的数据进入老年代中，这样Full GC的频率大大的降低了，此次优化的也基本达到目的。

