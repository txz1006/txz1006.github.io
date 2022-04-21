JVM-8(实例实践)

### JVM定制模板
使用命令查询当前JVM设置的参数：
`java -XX:+PrintCommandLineFlags -version`

一台4核8G的服务器的JVM模板，能适用于多数服务器模板

```sh
-Xms4096M -Xmx4096M -Xmn3072M -Xss1M  -XX:MetaspaceSize=256M -XX:MaxMetaspaceSize=256M -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=92 -XX:+UseCMSCompactAtFullCollection -XX:CMSFullGCsBeforeCompaction=0 -XX:+CMSParallelInitialMarkEnabled -XX:+CMSScavengeBeforeRemark -XX:+DisableExplicitGC -XX:+PrintGCDetails -Xloggc:gc.log -XX:+HeapDumpOnOutOfMemoryError  -XX:HeapDumpPath=/usr/local/app/oom
```

**XX:+UseCMSCompactAtFullCollection**开启Full GC后进行内存压缩整理

**-XX:CMSFullGCsBeforeCompaction**=0 压缩整理执行频率是每次Full GC后都执行一次

**-XX:CMSInitiatingOccupancyFaction**=92老年代占用率达到多少时触发Full GC

**XX:+CMSParallelInitialMarkEnabled**的作用是Full GC时在初始标记阶段会使用多线程进行标记

**-XX:+CMSParallelRemarkEnabled**:在重新标记的时候多线程执行，降低STW；

**-XX:+CMSScavengeBeforeRemark**的作用是Full GC时在重新标记阶段前执行一次Young GC减少重新标记时进行RC root的对象数量

**-XX:SoftRefLRUPolicyMSPerMB**=1000 的作用是设置软引用对象存活时间单位(毫秒)，软引用存活时间是freeSpace * SoftRefLRUPolicyMSPerMB，举个例了，比如JVM剩余空间有1000M，那么软引用对象的存活时间就是1000 *  1000 = 1000s = 16分钟左右

**-XX:TraceClassLoading** 打印类加载器加载了哪些类

**-XX:TraceClassUnloading**打印类加载器卸载了哪些类

**-XX:+PrintHeapAtGC**:在每次GC前都要GC堆的概况输出

**-XX:+UseCMSInitiatingOccupancyOnly**：JVM只通过CMSInitiatingOccupancyFraction的阈值来触发Full GC

**-XX:+DisableExplicitGC**：禁止通过代码来触发Full GC(即System.gc();无效)

```sh
## OOM时输出一个快照文件
-XX:+HeapDumpOnOutOfMemoryError 
-XX:HeapDumpPath=D:\study\log_hprof\gc.hprof 
-XX:+PrintGCDetails 
-Xloggc:D:\study\log_gc\gc.log
```

参考：https://www.cnblogs.com/parryyang/p/5750146.html

### 系统发生OOM案例分析

#### 哪些内存区域会发生OOM？

方法区(元空间)、栈空间、堆空间

#### **发生OOM后如何定位问题？**

方法区和对内存可以通过配置-XX:+HeapDumpOnOutOfMemoryError 和-XX:HeapDumpPatlianggeJVM参数，在JVM内存泄漏时输出一个内存快照，然后适用MAT工具进行内存分析，搞清楚到底是哪些对象过多导致的OOM，然后通过这个对象定位到具体代码再进行修改。

栈空间OOM则是方法嵌套调用过多超过了栈空间设置上限导致的，直接通过查看系统日志就可以定位到问题代码的位置。


####出现服务卡死(排查CPU负载过高、OOM情况)
问题分析：服务卡死可能有两种情况，一种情况是内存占用过多，甚至还在上升(50%往上)，这种情况可能是出现了内存泄漏导致频繁的GC，长时间的STW影响了服务的调用。

另一种情况是CPU使用率过高，导致服务线程拿不到CPU使用资源，一致处于等待状态，这样情况可能是出现死锁，磁盘排序、内存排序、或者数据库全表扫描等。


如果是第一种情况，我们可以通过jstat命令观察一下项目的GC情况，然后通过jmap导出一份内存快照出来，使用MAT分析下那些对象占了大量内存，确定问题后修改代码

步骤1：首先通过TOP命令筛选异常进程，比如高内存占用，低CPU使用率

步骤2，确定进程后，通过jstack导出一份线程使用详表，使用jmap导出一份进程内存快照

步骤3，通过分析线程和内存快照，确定问题代码位置，分析原因，修改代码


#### 永久代发送OOM的案例

CGlib动态代理，Enhancer创建代理对象时，不使用缓存，导致每次调用代码都要创建新的代理对象，进而占满永久代的空间出现OOM。

处理方式：开启Enhancer对象缓存