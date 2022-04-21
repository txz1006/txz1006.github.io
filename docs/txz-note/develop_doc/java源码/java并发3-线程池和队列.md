java并发3-线程池和队列

#### 一、线程池ThreadPoolExecutor对象的要点总结

使用线程池要点：

- 提高线程的响应速度，避免资源反复创建/销毁，加强对线程的管理
- 避免使用Executors提供的创建线程池方法，因为他们多允许创建过多的线程数或是创建过多的队列任务，容易出现OOM问题
- 可以使用线程池提供的查询API制作一个简单的线程池监控对象
- 不同业务应使用不同的线程池，避免使用通用的线程池对象(可能会出现死锁现象：业务A占用了所有的线程池资源，但是需要等到业务B的执行结果，但是业务B拿不到线程池资源，无法执行，形成死锁)
- 线程池创建线程的顺序：每新来一个线程任务，就会新创建一个线程来执行，直到线程数量达到核心线程数(corePoolSize)；若之后再往线程池中添加任务，则会放置到等待队列中(4种等待队列对象：直接提交队列、有界队列、无界队列、优先队列)；若等待队列任务也到达队列上限了，则会再新创建非核心线程，直到线程数达到最大线程数(maximumPoolSize，有些队列是没用设置上限的，所以这个参数可能会无效)，若是线程数已达到线程池的最大线程数，再新来任务则会触发最后的拒绝策略执行任务对象，我们可以自行决定这些新的任务的处理方式。
- 线程池最好指定线程池名称，方便后期问题排查

参考：https://www.cnblogs.com/dafanjoy/p/9729358.html

https://blog.csdn.net/weixin_43778179/article/details/93750558

##### 简单使用示例：

```java
public class ThreadPool {

    static class  T1 extends Thread{
        int i = 0;

        public T1(String name, int i){
            setName(name);
            this.i = i;
        }

        @Override
        public void run(){
            try {
                System.out.println(System.currentTimeMillis()+Thread.currentThread().getName()+"在处理执行了"+getName());
                TimeUnit.SECONDS.sleep(10);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

        }

    }

    public static void main(String[] args) {
        ThreadPoolExecutor poolExecutor = new ThreadPoolExecutor(
                2,6,1,TimeUnit.SECONDS,
                new ArrayBlockingQueue<>(5),
                new ThreadPoolExecutor.AbortPolicy()
        );
        for(int i = 0; i < 10; i++){
            Thread t = new ThreadPool.T1("任务"+i, i);
            poolExecutor.execute(t);
        }
        poolExecutor.shutdown();
    }
}
//mian方法执行结果：
1603702950811pool-1-thread-2在处理执行了任务0
Exception in thread "main" java.util.concurrent.RejectedExecutionException: Task Thread[任务9,5,main] rejected from org.apache.tomcat.util.threads.ThreadPoolExecutor@37374a5e[Running, pool size = 6, active threads = 5, queued tasks = 5, completed tasks = 0]
1603702950812pool-1-thread-1在处理执行了任务1
    
1603702950812pool-1-thread-4在处理执行了任务6
1603702950812pool-1-thread-3在处理执行了任务5
1603702950812pool-1-thread-5在处理执行了任务7
1603702950812pool-1-thread-6在处理执行了任务8
//十秒钟后执行等待队列的任务
1603702960814pool-1-thread-2在处理执行了任务2
1603702960814pool-1-thread-1在处理执行了任务4
1603702960814pool-1-thread-6在处理执行了任务3
```

上述示例的线程池核心线程数是2个，线程上限数是6个，等待队列可以存放5个线程任务；由于使用的等待队列对象是ArrayBlockingQueue<>()有界对象，所以在整个线程消费过程中，线程任务0-4五个线程先会被放入ArrayBlockingQueue等待队列中，之后线程池会创建两个核心线程来消费线程任务0和1，此时等待队列中还有2、3、4单个任务在进行等待，由于**此时判断等待队列已满**和核心线程数已达上限，剩下5-9五个线程任务会创建新的线程来执行；又由于线程池的最终上限是6个线程，所以剩下能创建执行的线程数只有4个，最后一个线程任务9就会触发线程池的拒绝对象，这里设置的是AbortPolicy()策略，所以会抛出异常。

由于判断等待队列是否已满的时机是不确定，所以会出现线程任务0和1被两个核心线程消费，等待队列再放入五个线程任务，又可以创建4个新线程的状况(此时线程池可以容纳10个线程任务的执行)，结果如下：

```java
//核心线程
1603704108328pool-1-thread-1在处理执行了任务0
1603704108329pool-1-thread-2在处理执行了任务1
//f
1603704108329pool-1-thread-3在处理执行了任务5
1603704108332pool-1-thread-4在处理执行了任务8
1603704108333pool-1-thread-5在处理执行了任务9
//十秒钟后执行等待队列的任务
1603704118332pool-1-thread-1在处理执行了任务2
1603704118332pool-1-thread-3在处理执行了任务4
1603704118332pool-1-thread-4在处理执行了任务3
1603704118333pool-1-thread-5在处理执行了任务6
1603704118334pool-1-thread-2在处理执行了任务7
```

##### 四种等待队列介绍：

- new **ArrayBlockingQueue**<>(5)：有界队列，示例中使用的就是，在核心线程数的使用已满时，再加入线程任务就会存在到这个队列中，当等待队列已满时，线程池会根据新加入的线程任务数创建额外的线程来执行，增加额外的线程数上限是(maximumPoolSize-corePoolSize)

- new **SynchronousQueue**<>()：立即执行队列，这个队列比较特殊，他不能存放等待任务，可以任务线程池只有“线程池最大线程数”个线程可以使用，超出的会被拒绝。

- new **LinkedBlockingQeque**<>()：无界队列，和有界队列的区别就是，等待队列没用设置元素上限，只要有空间可以一直往等待队列中添加数据，所以线程池的线程数只有corePoolSize个，maximumPoolSize无效。

- new **PriorityBlockingQueue**<>()：优先队列，可以认为是一种有优先级的无界队列，线程任务对象可以通过实现Comparable接口重写compareTo方法来确定执行优先级(结果越小，优先级越高)见下方示例：

  ```java
  public class ThreadPool {
      private static ExecutorService pool;
      public static void main( String[] args )
      {
          //优先任务队列
          pool = new ThreadPoolExecutor(1, 2, 1000, TimeUnit.MILLISECONDS, new PriorityBlockingQueue<Runnable>(),Executors.defaultThreadFactory(),new ThreadPoolExecutor.AbortPolicy());
            
          for(int i=0;i<10;i++) {
              pool.execute(new ThreadTask(i));
          }    
      }
  }
  
  public class ThreadTask implements Runnable,Comparable<ThreadTask>{
      
      private int priority;
      
      public int getPriority() {
          return priority;
      }
  
      public void setPriority(int priority) {
          this.priority = priority;
      }
  
      public ThreadTask() {
          
      }
      
      public ThreadTask(int priority) {
          this.priority = priority;
      }
  
      //当前对象和其他对象做比较，当前优先级大就返回-1，优先级小就返回1,值越小优先级越高
      public int compareTo(ThreadTask o) {
           return  this.priority>o.priority?-1:1;
      }
      
      public void run() {
          try {
              //让线程阻塞，使后续任务进入缓存队列
              Thread.sleep(1000);
              System.out.println("priority:"+this.priority+",ThreadName:"+Thread.currentThread().getName());
          } catch (InterruptedException e) {
              // TODO Auto-generated catch block
              e.printStackTrace();
          }
      
      }
  }
  //执行结果：
  priority:0,ThreadName:pool-1-thread-1
  priority:9,ThreadName:pool-1-thread-1
  priority:8,ThreadName:pool-1-thread-1
  priority:7,ThreadName:pool-1-thread-1
  priority:6,ThreadName:pool-1-thread-1
  priority:5,ThreadName:pool-1-thread-1
  priority:4,ThreadName:pool-1-thread-1
  priority:3,ThreadName:pool-1-thread-1
  priority:2,ThreadName:pool-1-thread-1
  priority:1,ThreadName:pool-1-thread-1
  //除第一个任务外，其他任务都进入了优先队列中
  ```

##### 四种拒绝线程线程策略：

我们可以自定义当线程任务超过线程池处理上限时，如何拒绝处理超限的任务，java提供了4中处理对象：

- new ThreadPoolExecutor.AbortPolicy()：抛出异常，不处理超出上限的任务
- new ThreadPoolExecutor.CallerRunsPolicy()：会让调用线程池的主线程来按顺序执行超限的线程任务，所以主线程会出现阻塞，若此时核心线程出现空闲，之后的超限任务又会分配给核心线程执行。
- new ThreadPoolExecutor.DiscardOldestPolicy()：此拒绝策略会让等待队列首位任务(最先加入队列的)弹出抛弃掉，并让超限的任务加到等待队列最后一个位置；若之后还又超限任务加入，则再次重复上述逻辑
- new ThreadPoolExecutor.DiscardPolicy()：默认抛弃超限的任务，不做任何处理，此策略会导致任务的丢失。

参考：https://www.jianshu.com/p/9fec2424de54

##### 线程池的其他方法：

- pool.shutdown()：终止关闭线程池，大致逻辑是循环线程池中的所有线程，给他们发送中断信号；此方式会等到等待队列的任务执行完后结束。
- pool.shutdownNow()：和shutdown方法的区别是等待队列中的任务会被清空，不会执行就关闭线程池。

##### 其他注意点：

-线程池中的线程是线程安全对象，其中的worker执行线程继承了AQS同步器，每个线程执行业务时会使用ReentrantLock进行加解锁。

-线程池可以自定义产生线程的线程工程对象，只需要实现ThreadFactory接口，重写Thread newThread(Runnable r)即可，也可以使用函数式接口来实现：

![image-20201026192003653](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103011.png)

##### **补充：线程池原理**

线程池底层是一个HashSet<Worker>存储对象,当我们向线程池添加线程任务时，会创建一个Worker执行线程对象来执行我们添加的任务(这个对象就是线程复用对象)，但是这个worker线程对象本身也是一个线程对象，他的run方法里是一个无限循环体，若当前任务执行完成后，他就会循环获取等待队列中的任务来执行。

Worker线程对象的run方法逻辑如下：

![image-20210722095210383](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210722095224.png)

往线程池添加线程任务逻辑如下：

![image-20210722095333732](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210722095334.png)

#### 二、JUC包下的Executor线程池框架的使用

上一章讲解了下ThreadPoolExecutor线程池对象的使用方法和注意点，在日常开发中，线程池不仅仅只有这一个对象能使用，他只是JUC包下Executor线程池框架中最基础的线程池对象而已，在此基础上还有些扩展线程池对象的使用。

Executor线程池框架中，所有的线程池对象，都是从Executor接口扩展实现出来的，我们一般不直接使用这个接口，而是使用他的子接口或接口实现类，下面以ScheduledThreadPoolExecutor对象的继承链图为例：

##### ![image-20201027152822350](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103016.png)

##### ScheduledThreadPoolExecutor对象的使用：

ScheduledThreadPoolExecutor对象继承于ThreadPoolExecutor对象，主要扩展了线程任务执行的一些定时或延时执行逻辑，有点类似于Timer对象的使用，下面来了解一下这个对象：

ScheduledThreadPoolExecutor对象是基于ThreadPoolExecutor对象的扩展对象，可以看下构造方法：

```java
    public ScheduledThreadPoolExecutor(int corePoolSize) {
        super(corePoolSize, Integer.MAX_VALUE,
              DEFAULT_KEEPALIVE_MILLIS, MILLISECONDS,
              new DelayedWorkQueue());
    }
```

通过自定义等待队列DelayedWorkQueue()来实现定时和延时功能，这个对象是基于数组和堆实现的数据结构，具体可以参考：https://blog.csdn.net/w13485673086/article/details/88538826

ScheduledThreadPoolExecutor主要有三个延时执行线程任务方法：

- ScheduledFuture<?> schedule(Runnable command,
                                         long delay, TimeUnit unit)：主线程执行schedule方法后，线程任务会延时delay时间后执行。

```java
    public static void main(String[] args) {
        ScheduledExecutorService scheduledExecutorService = new ScheduledThreadPoolExecutor(2);
        System.out.println(System.currentTimeMillis());
        //延时执行任务
        ScheduledFuture future = scheduledExecutorService.schedule(() ->{
            System.out.println(System.currentTimeMillis());
        }, 2, TimeUnit.SECONDS);
        scheduledExecutorService.shutdown();
    }
//执行结果：
1603786847507
1603786849597
```

- ScheduledFuture<?> scheduleAtFixedRate(Runnable command,
                                                    long initialDelay,
                                                    long period,
                                                    TimeUnit unit)：一个定时循环执行线程任务方法，在该方法被执行时，首次会延时initialDelay时间后进行第一次执行，之后每隔period时间后再此执行线程任务(从线程任务开始执行时就进行下次执行period时间的倒计时等待，若当前线程任务的执行时间大于了period时间，则会在当前线程任务完成后立即开始下次定时任务的执行)

```java
static AtomicInteger atomicInteger = new AtomicInteger(0);
public static void main(String[] args) {
        //定时执行任务(循环执行)
        ScheduledFuture future = scheduledExecutorService.scheduleAtFixedRate(()->{
            System.out.println(System.currentTimeMillis()+"开始次数："+atomicInteger.get());
            try {
                TimeUnit.SECONDS.sleep(2);
            } catch (InterruptedException e) {
                System.out.println("被中断了。。。。");
                e.printStackTrace();
            }
            System.out.println(System.currentTimeMillis()+"结束次数："+atomicInteger.getAndIncrement());
        },2, 5, TimeUnit.SECONDS);
        TimeUnit.SECONDS.sleep(60);
        scheduledExecutorService.shutdown();    
}
//执行结果：
1603787312161
1603787314166开始次数：0
1603787316167结束次数：0
1603787319165开始次数：1
1603787321165结束次数：1
1603787324165开始次数：2
1603787326165结束次数：2
//注意：每次线程开始执行的时间之差是period参数，5秒
//如果把线程中间的休眠时间从2秒改为6秒则会有下面的结果：
1603788093461
1603788095529开始次数：0
1603788101531结束次数：0
1603788101531开始次数：1
1603788107532结束次数：1
1603788107532开始次数：2
```

- ScheduledFuture<?> scheduleWithFixedDelay(Runnable command,
                                                       long initialDelay,
                                                       long delay,
                                                       TimeUnit unit)：这个方法和scheduleAtFixedRate基本相同，区别是从第二次开始执行线程任务的时间间隔是按照上个线程任务结束后开始执行period时间的倒计时等待的。

```java
static AtomicInteger atomicInteger = new AtomicInteger(0);
public static void main(String[] args) {
        //定时执行任务(循环执行)
        ScheduledFuture future = scheduledExecutorService.scheduleWithFixedDelay(()->{
            System.out.println(System.currentTimeMillis()+"开始次数："+atomicInteger.get());
            try {
                TimeUnit.SECONDS.sleep(2);
            } catch (InterruptedException e) {
                System.out.println("被中断了。。。。");
                e.printStackTrace();
            }
            System.out.println(System.currentTimeMillis()+"结束次数："+atomicInteger.getAndIncrement());
        },2, 5, TimeUnit.SECONDS);
        TimeUnit.SECONDS.sleep(60);
        scheduledExecutorService.shutdown();    
}
//执行结果：
1603788720273
1603788722279开始次数：0
1603788724281结束次数：0
1603788729282开始次数：1
1603788731283结束次数：1
1603788736284开始次数：2
1603788738284结束次数：2
//注意：每次线程结束执行时间到下次线程开始执行之差是period参数，5秒
```

  此外，上面三个方法的返回对象是ScheduledFuture，一个Future接口的子接口，若线程任务是通过实现Callable<T>接口实现的，则可以通过Future对象的get()方法获取线程的计算结果。

ScheduledFuture作为定时任务的特定返回对象有几个特别的方法可以作用于线程池的延时等待队列：

- future.**cancel**(boolean ifInterruptedThread)：是否通过主线程执行这个方法来终止定时线程池的执行，方法的boolean参数是是否要中断当前执行的线程，若为false，则会在当前执行的线程任务完成后结束执行；若为true，则会给当前执行的线程任务发送中断信号。
- future.**isCancelled**()：判断线程池的执行是否已经被取消
- future.**isDone**()：判断线程池的执行是否已经结束

```java
//示例：
    static AtomicInteger atomicInteger = new AtomicInteger(0);


    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ScheduledExecutorService scheduledExecutorService = new ScheduledThreadPoolExecutor(2);
        System.out.println(System.currentTimeMillis());
        //定时执行任务(循环执行)
        ScheduledFuture future = scheduledExecutorService.scheduleAtFixedRate(()->{
            System.out.println(System.currentTimeMillis()+"开始次数："+atomicInteger.get());
            try {
                TimeUnit.SECONDS.sleep(10);
            } catch (InterruptedException e) {
                System.out.println("被中断了。。。。");
                e.printStackTrace();
            }
            System.out.println(System.currentTimeMillis()+"结束次数："+atomicInteger.getAndIncrement());
        },2, 5, TimeUnit.SECONDS);
        TimeUnit.SECONDS.sleep(8);
        future.cancel(false);
        System.out.println(future.isCancelled());
        System.out.println(future.isDone());
//执行结果：
//在首次执行线程任务8秒后执行future.cancel(false)
1603790695489
1603790697497开始次数：0
true
true
1603790707499结束次数：0  
//主线程执行future.isCancelled()和future.isDone()都是true
//第一次线程任务在10秒后执行结束次数打印后结束线程池的执行

//================
//若将future.cancel(X)参数改为true则当前执行线程任务会收到中断信号
1603790991576
1603790993582开始次数：0
java.lang.InterruptedException: sleep interrupted
true
	at java.base/java.lang.Thread.sleep(Native Method)
true
	at java.base/java.lang.Thread.sleep(Thread.java:339)
被中断了。。。。
	at java.base/java.util.concurrent.TimeUnit.sleep(TimeUnit.java:446)
1603790999579结束次数：0    
    
```

##### Executors默认提供的几种线程池

Executors默认创建几种线程池的方式，由于这几种方式多使用Integer.MAX_VALUE来作为线程池的创建线程上限数或是等待队列上限数，所以容易出现OOM的问题，慎用！！！

- Executors.newCachedThreadPool()：

```java
public static ExecutorService newCachedThreadPool() {
        return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                      60L, TimeUnit.SECONDS,
                                      new SynchronousQueue<Runnable>());
}
//没有核心线程数，完全使用超核心线程作为处理线程，而且等待队列是直接提交队列，所以来多少个任务就会创建多少个线程；空间时会释放所有线程
```

- Executors.newSingleThreadExecutor()：

```java
public static ExecutorService newSingleThreadExecutor() {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>()));
}
//只有单个线程处理任务，但是等待队列是无界队列，可以无上限的增加等待任务
```

- Executors.newFixedThreadPool(10)：

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>());
}
//newSingleThreadExecutor线程池的多线程版，等待队列是无界队列，可以无上限的增加等待任务
```

- Executors.newScheduledThreadPool(10)：

```java
public static ScheduledExecutorService newScheduledThreadPool(int corePoolSize) {
        return new ScheduledThreadPoolExecutor(corePoolSize);
}
//默认使用ScheduledThreadPoolExecutor创建延时线程池
```

##### Future接口和Callable接口

在之前使用线程池执行线程任务时，我们使用的是void poolService.execute(Runnable r)，这是Executor顶级接口的方法，但实际开发中，Executors框架还提供了一种子线程返回结果给主线程的方法：<T> Future<T> submit(Callable<T> task)，方法的参数是一个Callable对象，这个对象和Runnable对象很相似，主要区别是Callable提供的call方法可以带返回值。

```java
public class FutrueTest {

    static class f1 implements Callable<String>{

        @Override
        public String call() throws Exception {
            TimeUnit.SECONDS.sleep(2);
            return "hello";
        }
    }

    static class r1 implements Runnable{
        @Override
        public void run() {
            System.out.println("hello");
        }
    }

    public static void main(String[] args) throws ExecutionException, InterruptedException {
       ExecutorService service = Executors.newFixedThreadPool(10);
        System.out.println("开始执行：===="+System.currentTimeMillis());
        Future future = service.submit(new f1());
        System.out.println(future.get());
        System.out.println("结束执行：===="+System.currentTimeMillis());
        Future future1 = service.submit(new r1());
        future1.get();
    }
}
//执行结果：
开始执行：====1603873567808
hello
结束执行：====1603873569873
hello
//要点：异步线程未执行完前，主线程的future.get()会阻塞
```

使用线程池的submit()方法可以执行对应的线程任务并返回结果对象Future，Future调用get方法可以获取到异步线程执行的结果。需要注意的是异步线程未执行完前，主线程会在future.get()行上陷入阻塞，上例的执行结果中的开始结束时间就差了异步线程休眠的2秒。

需要注意的是，future.get()会在一些情况下结束阻塞状态，注意有下面两种：

- 调用future.cancel(false)方法，则future.get()会抛出CancellationException异常并结束阻塞状态

```java
    public static void main(String[] args) throws ExecutionException, InterruptedException {
       ExecutorService service = Executors.newFixedThreadPool(10);
       Future<String> future = service.submit(()->{
            System.out.println("开始执行：===="+System.currentTimeMillis());
            try {
                TimeUnit.SECONDS.sleep(5);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println("结束执行：===="+System.currentTimeMillis());
            return "hello";
        });
        System.out.println("主线程1-"+System.currentTimeMillis());
        System.out.println(future.cancel(false));
        System.out.println(future.isDone());
        TimeUnit.SECONDS.sleep(3);
        service.shutdown();
        try{
            System.out.println(System.currentTimeMillis()+"获取线程执行结果："+future.get());
        }catch (Exception e){
            e.printStackTrace();
        }
        System.out.println("主线程2-"+System.currentTimeMillis());
    }
//执行结果：
主线程1-1603876245678
true
true
开始执行：====1603876245679
java.util.concurrent.CancellationException
	at java.base/java.util.concurrent.FutureTask.report(FutureTask.java:121)
	at java.base/java.util.concurrent.FutureTask.get(FutureTask.java:191)
	at org.jeecg.FutrueTest.main(FutrueTest.java:52)
主线程2-1603876248681
结束执行：====1603876250679
//注意：异步线程需要5秒执行，主线程1和2的打印大概就是中间休眠的3秒钟，3秒后主线程被唤醒
//若future.cancel()方法参数设置未true，则会给异步线程发送中断信号，要注意中断的处理
```

- future.get()有一个多态方法可设置阻塞等待超时时限，若达到超时时限，则future.get()会抛出TimeoutException异常并结束阻塞

```java
//注释掉上述示例的下面三行
        System.out.println(future.cancel(false));
        System.out.println(future.isDone());
        TimeUnit.SECONDS.sleep(3);
//并将future.get()改为future.get(2, TimeUnit.SECONDS)，得到结果：
主线程1-1603876880995
开始执行：====1603876880995
主线程2-1603876882998
java.util.concurrent.TimeoutException
	at java.base/java.util.concurrent.FutureTask.get(FutureTask.java:204)
	at org.jeecg.FutrueTest.main(FutrueTest.java:52)
结束执行：====1603876885996
//future.get()在等待2秒后抛出异常并被唤醒
```

Future接口对象只能交给线程池来执行，所以JUC中提供了一个FutureTask对象，这个对象不仅可以交给线程池来执行，也可以直接交给某个线程来执行(该类实现了Runnable接口)：

```java
FutureTask futureTask = new FutureTask<String>(()->{
    return "6666";
});
new Thread(futureTask).start();
//service.submit(futureTask);
System.out.println(futureTask.get());
//执行结果：
6666
```

##### ExecutorCompletionService对象

若是线程池中提交的全是Callable对象，则所有异常线程都有一个Future对象要处理返回数据：

```java
public static void main(String[] args) throws ExecutionException, InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(10);
        Future<String> future1 = executor.submit(()->{
            TimeUnit.SECONDS.sleep(2);
            return "task1=====";
        });
        Future<String> future2 = executor.submit(()->{
            TimeUnit.SECONDS.sleep(4);
            return "task2=====";
        });
        executor.shutdown();
        System.out.println(System.currentTimeMillis());
        String str1 = future1.get();
        System.out.println(System.currentTimeMillis()+"处理"+ str1);
        String str2 = future2.get();
        System.out.println(System.currentTimeMillis()+"处理"+ str2);
}
//执行结果：
1603877930374
1603877932375处理task1=====
1603877934375处理task2=====
//需要注意的是两个任务是并行的，若是先执行future2.get()则会有下面的结果：
1603878178023
1603878182030处理task2=====
1603878182030处理task1=====
```

这种线程池中全是Callable对象的情况，JUC中也提供一个对象来专门处理这种情况，他就是ExecutorCompletionService。

ExecutorCompletionService提供了一个能接收线程池参数的构造方法：

```java
    public ExecutorCompletionService(Executor executor) {
        if (executor == null)
            throw new NullPointerException();
        this.executor = executor;
        this.aes = (executor instanceof AbstractExecutorService) ;
            (AbstractExecutorService) executor : null;
        this.completionQueue = new LinkedBlockingQueue<Future<V>>();
    }
```

ExecutorCompletionService处理多个Callable对象线程池的示例：

```java
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(10);
        ExecutorCompletionService service = new ExecutorCompletionService<String>(executor);

        List<Callable> list= new ArrayList<>();
        list.add(()->{
            TimeUnit.SECONDS.sleep(4);
            return "task2=====";
        });
        list.add(()->{
            TimeUnit.SECONDS.sleep(2);
            return "task1=====";
        });
        System.out.println(System.currentTimeMillis());
        for(Callable callable : list){
            service.submit(callable);
        }
        executor.shutdown();
        for(Callable callable : list){
            String str = (String) service.take().get();
            System.out.println(System.currentTimeMillis()+"处理"+ str);
        }
    }
//执行结果：
1603879516168
1603879518170处理task1=====
1603879520171处理task2=====
//注意service.take().get()会获取先结束的异步线程
```

若现在的业务场景是只能获取线程池中第一个结束的异步线程结果，用ExecutorCompletionService如何实现：

```java
    static ExecutorService executor = Executors.newFixedThreadPool(10);
    static ExecutorCompletionService service = new ExecutorCompletionService<String>(executor);

    public static void main(String[] args) {

        List<Callable> list= new ArrayList<>();
        list.add(()->{
            TimeUnit.SECONDS.sleep(4);
            return "task2=====";
        });
        list.add(()->{
            TimeUnit.SECONDS.sleep(2);
            return "task1=====";
        });
        System.out.println(System.currentTimeMillis());
        List<Future> futureList = new ArrayList<>();
        for(Callable callable : list){
            futureList.add(service.submit(callable));
        }
        executor.shutdown();
        String str = getFirstFuture(futureList);
        System.out.println(System.currentTimeMillis()+"处理"+ str);
    }

//该方法逻辑是返回第一个Callable对象的结果，并在finally中取消未完成的Callable对象的执行
    public static String getFirstFuture( List<Future> futureList){
        try {
            for(Future future : futureList){
                String str = null;
                str = (String) service.take().get();
                if(str != null){
                    return str;
                }
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }finally {
            for(Future future : futureList){
                future.cancel(true);
            }
        }
        return null;
    }

//执行结果：
1603880256499
1603880258503处理task1=====
```

实际是在线程池对象中，已经提供了这样功能的方法：

```java
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(10);
        List<Callable<String>> list= new ArrayList<>();
        list.add(()->{
            TimeUnit.SECONDS.sleep(4);
            return "task2=====";
        });
        list.add(()->{
            TimeUnit.SECONDS.sleep(2);
            return "task1=====";
        });
        String str = executor.invokeAny(list);
        executor.shutdown();
        System.out.println(System.currentTimeMillis()+"处理"+ str);
    }
//执行结果：
1603880488579处理task1=====
```

==========

在jdk1.8中，JUC包下提供了一个CompletableFuture对象简化了线程池执行异步线程返回Future的逻辑操作，详情可以参考https://www.cnblogs.com/cjsblog/p/9267163.html

#### 三、队列

在第一章中JDK提供了4种队列对象来供我们使用，这些队列都实现了Queue接口，是属于一进一出的通道型数据结构。下面是ArrayBlockingQueuede的继承链

![image-20201102164252941](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102164253.png)

在Queue接口中提供了6个常用方法：

![image-20201102164521676](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102164521.png)

其中add(e)和offer(e)是给队列添加元素，remove()是移除队首元素，element()和peek()是检测队列状态。不操作队列。

我们一般不直接操作Queue接口方法，实际上我们用的更多的是其子接口的方法，如线程池的4个阻塞队列，使用的是BlockingQueue

![image-20201102165813003](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102165813.png)

按照操作队列的方法可以总结了以下三类：

##### 插入队列的方法：

- add(e)：给对列添加元素，添加失败时抛出异常，成功返回true(基于offer(e)方法实现)

![image-20201102170358386](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102170358.png)

- offer(e)：给对列添加元素，如果队列已满则插入失败返回false，成功返回true，操作队列使用了重入锁

![image-20201102170649822](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102170649.png)

- put(e)：给对列添加元素，如果队列已满则会阻塞线程，等待队列产生空缺时再入队，阻塞可以被中断

![image-20201102171222103](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102171222.png)

- offer(E e, long timeout, TimeUnit unit)：限时给对列添加元素，如果队列已满则会阻塞线程，若阻塞时间超出设置的时限时直接返回false，成功返回true

  ![image-20201102171851389](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102171851.png)

##### 移除队列方法：

- remove()：默认移除队列首位元素，移除失败抛出异常，成功则返回首位元素（基于poll()方法实现）

![image-20201102172028925](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102172028.png)

- poll()：移除队列首位元素，队列为空时返回null，不为空时返回首位元素

![20201102172706](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102172706.png)

- poll(long timeout, TimeUnit unit)：移除队列首位元素，队列为空时会等待设置时限，若超时限后返回null，若超时限内队列新入队了元素，则返回元素

![image-20201102173004746](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102173004.png)

- take()：移除首位元素，若队列为空则会阻塞线程，需要等待队列入队新元素后才会立即移除并返回这个元素

![image-20201102174010096](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102174010.png)

##### 检测队列的方法：

- peek()：检测队列是否为空，获取队列首位元素，队列为空时返回null

![image-20201102174743004](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102174743.png)

- element()：检测队列是否为空，获取队列首位元素，队列为空时抛出异常（基于peek()实现）

![image-20201102174852415](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102174852.png)

##### 其他

限流的方式：

方式一：**信号量模式**

使用semaphore对象限制访问业务的线程数量，获取到许可权限的线程可以操作数据，并在业务结束后释放信号权限，供之后的线程进行抢占

方式二：**漏桶模式**

创建一个有界队列模仿漏桶，使用一个对象来模拟漏桶滴水(使用while(true)死循环，不断从队列中获取元素，每获取一次队列之后阻塞N时间限制)

方式三：**令牌桶模式**

创建一个有界队列模仿令牌桶，线程要操作业务需要从这个队列中获取到令牌才能继续执行，否则就会阻塞(如guava的RateLimiter对象)

