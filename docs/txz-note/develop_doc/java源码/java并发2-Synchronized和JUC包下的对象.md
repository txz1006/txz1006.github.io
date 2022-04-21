java并发2-Synchronized和JUC包下的对象

#### 一、Synchronized同步关键字的使用

为了确保多线程中计算数据结果正确，就必须要保证一些关键变量是线性使用的，即每次只能有一个线程操作关键变量。Synchronized关键字就是保证代码线性执行的关键字。Synchronized可以修饰方法或自成代码块，被Synchronized修饰的方法被称为同步方法，一个线程执行同步方法时，会对方法上锁，此时，其他线程调用这个方法时(同一对象调用)，因获取不到锁就会陷入阻塞，需要等待上个线程执行完释放锁后，才能获取锁进而执行方法体代码。

![image-20210720102533411](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210720102551.png)
https://zhuanlan.zhihu.com/p/356010805

##### **Synchronized修饰成员方法**

Synchronized可以直接修饰成员方法，会对当前实例对象上锁(this对象)，表示被修饰的方法体代码同一时间内只能有一个线程消费，具体见下方实例：

```java
public class SyncScopeTest {

    public synchronized void m1() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
    }
    
    public static void main(String[] args) {

        SyncScopeTest s1 = new SyncScopeTest();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程1");
                s1.m1();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程2");
                s1.m1();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();

        SyncScopeTest s2 = new SyncScopeTest();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程3");
                s2.m1();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();

    }
}
//main方法执行结果
1602917478252|m1线程1
1602917478253|m1线程3
1602917480253|m1线程2

```

上述示例输出结果可以发现：线程1和线程2执行的是同一个实例对象的synchronized同步方法，所以线程2要等待线程1执行完成后才能执行。线程3执行的是另一个实例对象的同步方法，几乎和线程1同时执行。

##### **Synchronized修饰静态方法**

Synchronized修饰的成员方法是静态方法时，会对当前类的class对象上锁，表示被修饰的方法体代码同一时间内只能有一个线程消费，不论是否是同一个实例对象。

我们将上面例子中的同步方法m1加上static关键字，执行后得到结果：

```java
public static synchronized void m1() throws InterruptedException {
   TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
}
//main方法执行结果
1602918327958|m1线程1
1602918329959|m1线程3
1602918331959|m1线程2
```

执行结果可以看出，无论是否执行的是同一个对象的m1方法，都隔了两秒的时间才执行，证明class对象锁是可以跨实例对象进行方法阻塞的

```java
思考：class对象锁和对象实例锁会相互阻塞吗？
//见下方实例
public class SyncScopeTest {

    public synchronized void m1() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
    }
    
    public static synchronized void m2() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m2"+Thread.currentThread().getName());
    }  
    
    public static void main(String[] args) {

        SyncScopeTest s1 = new SyncScopeTest();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程1");
                s1.m1();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程2");
                s1.m2();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
    }
}

//main方法执行结果
1602918998990|m1线程1
1602918998991|m2线程2
```

由上述结果发现class对象锁和实例对象锁是不互斥的

##### **Synchronized同步代码块**

由于使用Synchronized修改方法使加锁的范围是整个方法体，如果方法体业务过于复杂会导致执行效率非常的低。所以，可以使用synchronized同步块来缩小加锁范围，同时可以自定义加锁对象。

上述给同步成员方法和同步静态方法可以改写为下面的同步代码块：

```java
//普通成员方法
public void m1() throws InterruptedException {
    synchronized(this){
       TimeUnit.SECONDS.sleep(2);
 System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
    }

}

//静态方法
public void m2() throws InterruptedException {
    synchronized(SyncScopeTest.class){
        TimeUnit.SECONDS.sleep(2);
 System.out.println(System.currentTimeMillis()+"|m2"+Thread.currentThread().getName());
    }
}  
```

来测试一下：

```java
public class SyncScopeTest {

    public synchronized void m1() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
    }

    public static synchronized void m2() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m2"+Thread.currentThread().getName());
    }
    
    public void m3() throws InterruptedException {
        synchronized (this){
            TimeUnit.SECONDS.sleep(2);
            System.out.println(System.currentTimeMillis()+"|m3"+Thread.currentThread().getName());
        }
    }
    
    public void m5() throws InterruptedException {
        synchronized(SyncScopeTest.class){
            TimeUnit.SECONDS.sleep(2);
            System.out.println(System.currentTimeMillis()+"|m5"+Thread.currentThread().getName());
        }
    }
    
    public static void main(String[] args) {

        SyncScopeTest s1 = new SyncScopeTest();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程1");
                s1.m1();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程2");
                s1.m3();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();

        new Thread(()->{
            try {
                Thread.currentThread().setName("线程3");
                s1.m2();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
        new Thread(()->{
            try {
                Thread.currentThread().setName("线程4");
                s1.m5();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
    }
//main方法执行结果：
1602920337860|m1线程1
1602920337862|m2线程3
1602920339860|m3线程2
1602920339862|m5线程4
```

线程1和线程2阻塞，线程3和线程4阻塞，说明此时同步块和同步方法阻塞逻辑相同

------------

同步代码块能自定义加锁对象，缩小加锁范围，可以不是当前实例对象或是class类对象：

```java
public class ThreadTest {
    static Object object = new Object();
    static  class Thread1 extends Thread{
        @Override
        public synchronized void run() {
            synchronized (object){
                System.out.println("线程开始执行-----------"+"==="+Thread.currentThread().toString()+"|"+System.currentTimeMillis());
                try {
                    //sleep会释放cpu执行权，但不会释放同步锁
                    //Thread.currentThread().sleep(3000);
                    //TimeUnit.SECONDS.sleep(3);

                    //wait会释放cpu执行权，也会释放同步锁
                    object.wait();
                } catch (InterruptedException e) {
                    System.out.println("中断执行===========");
                }

                System.out.println("线程结束执行-----------"+"==="+Thread.currentThread().toString()+"|"+System.currentTimeMillis());
            }
        }
    }
    
   static class Thread2 extends Thread{
        @Override
        public void run() {
            try {
                TimeUnit.SECONDS.sleep(3);
                synchronized (object){
                    object.notify();
                    System.out.println("线程已通知"+System.currentTimeMillis());
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
    
    public static void main(String[] args) {
        Thread t0 = new Thread1();
        Thread t1 = new Thread2();
        t0.start();
        t1.start();
    }    
}

//main方法执行结果：
线程开始执行-----------===Thread[Thread-0,5,main]|1602921382621
线程已通知1602921385622
线程结束执行-----------===Thread[Thread-0,5,main]|1602921385623
```

线程0的执行结束行等了3秒钟才执行，说明线程0是对object上的锁，当执行wait()方法时释放锁，去执行线程1，线程1休眠3秒钟后，唤醒object锁中的等待的线程0从而执行了结束打印。

============

注意：不同synchronized同步块锁住的对象，必须是同一个对象才会生效。需要注意一些改变值就是改变对象的类：如Integer、String等(但是Stirng.intern()、-128-127的Intger.valueOf()可以作为锁对象)就不适合作为同步块锁的对象，因为这些对象的值改变时，就是创建了一个新的对象，那么两个同步块进行obj.wait()和obj.noify()时的obj就不是同一个对象了。

参考：https://blog.csdn.net/gxl1989225/article/details/84910315

https://blog.csdn.net/qq_42516090/article/details/108324516



#### 二、ReentrantLock锁的使用

##### 可重入锁

如果在一个Synchronized同步方法中调用另一个同步方法，会不会产生死锁的情况呢？

```java
//例如：
//m2能再次获取锁码？
public synchronized void m1() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m1"+Thread.currentThread().getName());
        this.m2();
    }

public synchronized void m2() throws InterruptedException {
        TimeUnit.SECONDS.sleep(2);
        System.out.println(System.currentTimeMillis()+"|m2"+Thread.currentThread().getName());
    }
//main执行结果：
1603071458631|m1线程1
1603071460632|m2线程1
```

结果是m2方法也获取到了锁，说明同一个线程二次获取同一个锁是可行的，这就是可重入锁。可以先简单说一下实现原理：每一个锁会关联一个使用线程和重入计数器，当计数器为0时，代表没用线程获取锁对象，如果有线程获取到这个锁时，JVM会记录当前使用线程信息同时计数器会加1，其他的线程来获取锁时就会陷入阻塞，但是当前线程再次来获取锁时，会使计数器再加1，当释放锁时计数器会减1，直到计数器为0代表线程已经执行完成。

##### Synchronized的局限性

synchronized通过一个关键字就实现了对象加锁解锁的逻辑，但是这个过程是没法控制的，什么时候阻塞，阻塞多长时间，阻塞线程细节处理都是不清楚的。所以java提供了一个实现同步加/解锁比synchronized更详细的对象，他就是ReentrantLock(可重入锁对象)，通过ReentrantLock可以实现和synchronized一样的功能。

##### ReentrantLock基本使用

使用ReentrantLock实现对象的加/解锁逻辑：

```java
//创建重入锁对象
ReentrantLock lock = new ReentrantLock();
//获取锁
lock.lock();
//解锁(一般放在finally代码块中)
lock.unlock();

//注意：lock()和unlock()必须要成对出现，并按顺序执行，不然会造成锁释放不了，线程一直阻塞的情况
```

一个ReentrantLock实例：

```java
public class enTrantLock {

    static ReentrantLock lock = new ReentrantLock(false);

    static class T1 extends Thread{

        public T1(String name){
            this.setName(name);
        }

        @Override
        public void run() {
            for(int i=0; i <3;i++){
                try{
                    lock.lock();
                    TimeUnit.SECONDS.sleep(1); 
                    System.out.println(Thread.currentThread().getName()+"获取了锁");
                }finally {
                    lock.unlock();
                }
            }
        }
    }

    public static void main(String[] args) throws InterruptedException {
        Thread t1 = new T1("线程1");
        Thread t2 = new T1("线程2");
        Thread t3 = new T1("线程3");
        t1.start();
        t2.start();
        t3.start();
    }
}

//main方法执行结果：
线程1获取了锁
线程1获取了锁
线程1获取了锁
线程3获取了锁
线程3获取了锁
线程3获取了锁
线程2获取了锁
线程2获取了锁
线程2获取了锁
```

非公平锁实现，一个线程获取锁后会持续获取锁对象，直到线程执行完成，其他线程在此期间一直处理饥饿状态。

===========

注意：synchronized和ReentrantLock默认实现的是非公平锁，即多个线程同时竞争一个锁资源时，并不是先来先得的，可能出现后来先抢到锁的情况。而ReentrantLock对象是有公平锁的实现的：

```java
//公平锁实现的可重入锁(维护有一个请求锁队列，一定先到先得)
//使用需要考虑效率问题，慎用
ReentrantLock lock = new ReentrantLock(true);
```

将上述的enTrantLock类实例的ReentrantLock参数改为true，实现公平队列得到结果：

```java
线程1获取了锁
线程3获取了锁
线程2获取了锁
线程1获取了锁
线程3获取了锁
线程2获取了锁
线程1获取了锁
线程3获取了锁
线程2获取了锁
```

公平锁会将三个线程排成一个队列，一个线程执行完后，如果还需要获取锁会排到公平锁队列的最后，依次三个线程为一个轮回，每个线程都有获取锁的机会。

参考：https://blog.csdn.net/wb_zjp283121/article/details/88972921

##### ReentrantLock获取锁的几种方式

上面我们已经了解了一种方式，即obj.lock()，这种方式是获取锁最直接的方式，会产生线程阻塞，但是不会响应线程的Interrupt()中断请求；此外还有几种获取锁的方式来了解下：

1. lockInterruptibly() 此方法获取锁后，能够响应Interrupt()中断请求，并抛出InterruptException异常；而且也会造成线程阻塞

2. tryLock() 此方法会返回一个boolean结果，在获取锁时，如果不能立即获取到锁对象，则会返回false，获取到锁返回true。不能够响应Interrupt()中断请求

3. tryLock(long a, TimeUnit b) 此方法也会返回一个boolean结果，但是设置有超时时限，如果超时了也会返回false，而且能够响应Interrupt()中断请求

   

##### ReentrantLock的其他方法

- isHeldByCurrentThread()，作用是判断当前线程是否已经获取了锁对象

- isFair()，作用是判断当前锁对象是否是公平锁

- hasQueueThread()，作用是判断当前线程是否处于获取锁的等待队列

- isLocked()， 作用是判断当前锁是否被任何线程获取了

  

#### 三、Condition对象和LockSupport对象

##### Condition对象的使用

在synchronized方法或代码块中可以使用加锁对象的wait()和notify()方法来阻塞当前线程的执行，而在ReentrantLock中，可以通过创建Condition对象来实现这个等待/通知功能，而且这个Condition对象比wait()和notify()更加灵活方便。

Condition对象是用过ReentrantLock实例创建的：

```java
//创建锁
ReentrantLock lock = new ReentrantLock();
//创建锁调节对象
Condition condition = lock.newCondition();
//使线程陷入等待状态(等待状态可以被interrupt()打断)
condition.await();
//随机唤醒一个在当前锁等待的线程
condition.signal();
//唤醒所有在当前锁等待的线程
condition.signalAll();
```

Condition对象相比于wait()方法的优势主要有两点：第一，一个锁可以创建多个Condition对象，用于不同状况下对线程进行阻塞和唤醒；第二，Condition对象有设置超时时限的await(long times, TimeUnit unit)方法，如果设置时间内没有进行唤醒，则线程会自动苏醒继续执行后续逻辑，可以更灵活的控制等待的条件。

下面看一个多Condition对象使用实例：

```java
public class LockCondition<T> {

    private ReentrantLock lock = new ReentrantLock();
    private Condition noFull = lock.newCondition();
    private Condition noEmpty = lock.newCondition();

    private int size;
    private LinkedList<T> list = new LinkedList<T>();

    public LockCondition(int size){
        this.size = size;
    }

    private void pullData(T t) throws InterruptedException {
        lock.lock();
        try{
            while(list.size() == size){
                noFull.await();
            }
            list.add(t);
            System.out.println("入队："+t);
            noEmpty.signal();
        }catch (InterruptedException e){
            e.printStackTrace();
        }finally {
            lock.unlock();
        }
    }

    private T pushData(){
        lock.lock();
        T t = null;
        try{
            while(list.size() == 0){
                noEmpty.await();
            }
            t = list.removeFirst();
            System.out.println("出队："+t);
            noFull.signal();

        }catch (InterruptedException e){
            e.printStackTrace();
        }finally {
            lock.unlock();
            return t;
        }
    }


    public static void main(String[] args) {
        LockCondition<Integer> lockCondition = new LockCondition<>(3);
        for(int i = 0; i < 5; i++){
            Integer c = i ;
            new Thread(() -> {
                try {
                    lockCondition.pullData(c);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }).start();
        }

        for(int i = 0; i < 5; i++){
            Integer c = i ;
            new Thread(() -> {
                lockCondition.pushData();
            }).start();
        }
    }

}

//main方法结果：
入队：3
入队：0
出队：3
入队：2
出队：0
出队：2
入队：4
出队：4
入队：1
出队：1
```

这个实例使用两个condition对象分别用于list容量已满或已空时阻塞生产线程或消费线程，当一方生产了或消费了一个元素时会唤醒另一个线程进行工作。

##### Condition对象常用方法

注意：下面的方法要在获取ReentrantLock锁对象后才生效；等待之后必须要唤醒，不然会陷入死线程状态。

- void await()，使当前对象释放锁，让当前对象陷入等待，可以被中断和唤醒，中断会抛出InterruptException()异常

- boolean await(long times, TimeUnit unit)，在设置时限内可以被中断和唤醒，中断会抛出InterruptException()异常，唤醒会返回true；若是达到超时时限后，会返回false，并自动结束等待状态(obj.wait()不支持这一点)

- long awaitNanos(long times)，功能同上，注意参数单位为纳秒，在设置时限内可以被中断和唤醒；若是达到超时时限后，会返回负数

- void awaitUninterruptibly()，功能和await()类似，但是不支持被中断(obj.wait()不支持这一点)

- boolean awaitUntil(Date date)，功能和带参数分await方法效果相同，但是设置超时参数是Date类型

  ![image-20201020181256784](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102102244.png)

====================

##### ReentrantLock的局限性

ReentrantLock对象虽然能细化实现Synchronized的同步锁功能，但始终存在一些限制：

- 等待/通知方法必须要保证先后顺序执行
- 等待/通知方法必须要在获取锁后执行才能生效


##### LockSupport对象介绍

对于上述限制而已，LockSupport都不会存在这些问题。LockSupport的功能和wait()/notify()功能类似，通过LockSupport.park()和LockSupport.unpark(Thread t)使线程阻塞/唤醒；但是LockSupport没用加锁的概念，所以不需要在获取锁的情况下执行，而且park()/unpark(Thread t)没有先后执行的强制要求，之后会详细介绍。

##### LockSupport的使用

来看一个LockSupport的实例：

```java
public class Support {

    static class T1 implements Runnable{

        @Override
        public void run() {
            System.out.println(Thread.currentThread().getName()+"中断前"+System.currentTimeMillis());
            LockSupport.park();
            System.out.println(Thread.currentThread().getName()+"中断后"+System.currentTimeMillis());
        }
    }

    static class T2 implements Runnable{
        private Thread t;

        public T2(Thread t){
            this.t = t;
        }

        @Override
        public void run() {
            System.out.println(Thread.currentThread().getName()+"中断前-"+System.currentTimeMillis());
            //使用interrupt()也可以唤醒线程
            //t.interrupt();
            LockSupport.unpark(t);
            try {
                TimeUnit.SECONDS.sleep(2);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println(Thread.currentThread().getName()+"中断后-"+System.currentTimeMillis());
        }
    }


    public static void main(String[] args) throws InterruptedException {
        Thread t1 = new Thread(new T1());
        t1.start();
        TimeUnit.SECONDS.sleep(2);
        Thread t2 = new Thread(new T2(t1));
        t2.start();
    }
}
//main方法执行结果：
Thread-0中断前1603250759999
Thread-1中断前-1603250761999
Thread-0中断后1603250762000
Thread-1中断后-1603250764000
```

上述示例展示了LockSupport是如何阻塞线程的，整个过程并没有进行加锁，而且，在线程唤醒后线程Thread-0就立即恢复执行了，这和加锁的情况是不同的(加锁要等到当前线程释放锁后，阻塞线程再次获取到锁后才会继续执行)。

此外，LockSupport.unpark(Thread t)并不需要在LockSupport.park()之后执行才管用，来看下一个示例：

```java
public class Support {
    static class T3 implements Runnable{

        @Override
        public void run() {
            System.out.println(Thread.currentThread().getName()+"阻塞前"+System.currentTimeMillis());
            try {
                TimeUnit.SECONDS.sleep(5);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            LockSupport.park();
            System.out.println(Thread.currentThread().getName()+"阻塞后"+System.currentTimeMillis());
        }
    }


    
    public static void main(String[] args) throws InterruptedException {
        Thread t3 = new Thread(new T3());
        t3.start();
        LockSupport.unpark(t3);
    }
}

//main方法执行结果：
Thread-0阻塞前1603260483588
Thread-0阻塞后1603260488588
```

这个结果说明LockSupport.unpark(t3)不是立即执行的，他会等到当前线程执行了LockSupport.park()后才执行，所以和执行的顺序无关。

下面简单说明一下LockSupport加锁/解锁的原理：每个线程有一个permit标记(只有0和1两种值)，默认是0，当执行LockSupport.park()时，判断当前permit的值，若是0则阻塞当前线程，若是1则将permit 设为0并阻塞当前线程，当执行LockSupport.unpark(t3)时，会将permit 设为1(多次执行都是1，值不会累加)

##### LockSupport的常用方法

- LockSupport.park(Blocker b)，阻塞当前线程时可以设置一个blocker参数，主要用于jstack命令分离堆栈信息时，方便定位问题位置

![image-20201021144029896](F:\个人\srpingIOC\images\image-20201021144029896.png)

- LockSupport.parkNanos(long times)，增加阻塞超时限制，超时后自动唤醒线程。示例：

```java
//设置超时1秒钟
LockSupport.parkNanos(TimeUnit.SECONDS.toNanos(1));
```

#### 四、Semaphore、CountDownLatch和CyclicBarrier对象

##### Semaphore基本用法

同一时间内，ReentrantLock的Lock限制只能一个线程获取锁，Semaphore对象可以控制有限个线程同时获取许可(锁)，主要有下面两个方法：

```java
//当前信号对象，允许两个线程同时获取到许可
Semaphore semaphore = new Semaphore(2);
//从信号对象中获取许可(可响应中断)
semaphore.acquire();
//信号对象许可加1(可以增加Semaphore许可上限)
semaphore.release();
```

下面看一个示例：

```java
public class SemaphoreTest1 {

    static Semaphore semaphore = new Semaphore(2);

    static class T1 extends Thread{
        private int i = 0;
        public T1(String name){
            this.setName(name);
        }

        @Override
        public void run() {
            try {
                semaphore.acquire();
                System.out.println(Thread.currentThread().getName()+"-获取到许可"+System.currentTimeMillis());
                System.out.println(Thread.currentThread().getName()+"-当前可用许可数为"+semaphore.availablePermits());
                TimeUnit.SECONDS.sleep(1);
            } catch (InterruptedException e) {
                System.out.println(Thread.currentThread().getName()+"-获取到许可被打断了");
                e.printStackTrace();
            }finally{
                semaphore.release();
                System.out.println(Thread.currentThread().getName()+"-释放了许可");
            }
        }
    }

    public static void main(String[] args) {
        for(int i = 0; i <=5; i++){
            new T1("线程"+i).start();
        }
    }

}
//main方法执行结果：
线程1-获取到许可1603356531949
线程1-当前可用许可数为1
线程0-获取到许可1603356531949
线程0-当前可用许可数为0
线程1-释放了许可
线程4-获取到许可1603356532949
线程4-当前可用许可数为0
线程0-释放了许可
线程5-获取到许可1603356532950
线程5-当前可用许可数为0
线程4-释放了许可
线程2-获取到许可1603356533951
线程2-当前可用许可数为0
线程5-释放了许可
线程3-获取到许可1603356533951
线程3-当前可用许可数为0
线程2-释放了许可
线程3-释放了许可
```

上述示例一共创建了6各线程去获取Semaphore的许可，而Semaphore只允许两个线程同时获取许可，剩余线程会在获取许可时陷入阻塞；而main方法执行结果也证明了这点，每两个线程获取许可的时间近似相同，和下一组两个线程的间隔为1秒，前一个线程执行了semaphore.release()后增加许可，剩下等待的线程才可以竞争这个许可(Semaphore是不公平对象，等待线程没用排序)

##### Semaphore释放许可的正确姿势

如果线程在semaphore.acquire()获取许可期间抛出异常(可能是响应线程中断)，那么就是获取许可失败了，可是结果还是执行semaphore.release()后增加许可了，这会导致semaphore的许可数量会增多，所以需要通过变量来控制预防这种异常：

```java
//以上个例子的run()为例：
//使用permitFlag变量来控制许可的增加不会异常
	boolean permitFlag = false;
        public void run() {
            try {
                semaphore.acquire();
                permitFlag = true; 
                System.out.println(Thread.currentThread().getName()+"-获取到许可"+System.currentTimeMillis());

                TimeUnit.SECONDS.sleep(1);
            } catch (InterruptedException e) {
                System.out.println(Thread.currentThread().getName()+"-获取到许可被打断了");
                e.printStackTrace();
            }finally{
                if(permitFlag){
                                    semaphore.release();
                System.out.println(Thread.currentThread().getName()+"-释放了许可");
                }
            }
        }
    }

```

由于semaphore.release()会增加许可数量，所以可以使用这个特性来实现类似join()的功能：

```java
//线程B和C需要使用线程A执行的结果，所以必须要在线程A执行完后执行
//下面给出伪代码：
static Semaphore semaphore = new Semaphore(0);
//线程A在实现完后使用semaphore.release()增加许可
new Thread(() ->{
    //业务代码。。。。
    semaphore.release(2);
}).start();
//线程B和线程C类似，在执行业务前需要获取许可才执行
new Thread(() ->{
    semaphore.acquire();
    //业务代码。。。。
}).start();
```

##### Semaphore的其他方法

- boolean semaphore.tryAcquire()，是否立即能获取到许可，获取成功返回true，获取不到返回false
- boolean semaphore.tryAcquire(long times, TimeUnit unit)，设置了时限来获取许可，获取不到返回false
- boolean  tryAcquire(int  permit)，一个线程是否立即可以获取多个许可
- acquire(int  permit)，一个线程可以获取多个许可

====

##### CountDownLatch基本用法

CountDownLatch闭锁可以认为是可以等待多个线程执行完成的join()对象，创建CountDownLatch时，设置要等待线程的个数，主线程使用countDownLatch.await()方法陷入阻塞，每个线程执行完成后执行countDownLatch.countDown()，使CountDownLatch实例的等待计数减1，当等待计数为0时主线程从阻塞状态恢复执行(等待计数小于0时会抛异常)，主要方法如下：

```java
//主线程
//创建闭锁对象(需要计算两次计时)
CountDownLatch latch = new CountDownLatch(2);
//在闭锁对象计时降为0之前陷入等待
latch.await();

//前置业务线程
//闭锁对象计时减一
latch.countDown();
```

来看示例：

```java
public class CountDownLatchTest1 {

    static CountDownLatch latch1 = new CountDownLatch(1);
    static CountDownLatch latch2 = new CountDownLatch(3);
    static class T1 extends Thread{
        private int i = 0;
        public T1(String name, int i){
            this.setName(name);
            this.i = i;
        }
        @Override
        public void run() {
            try {
                latch1.await();
                System.out.println(Thread.currentThread().getName()+"开始比赛！"+System.currentTimeMillis());
                TimeUnit.SECONDS.sleep(i);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println(Thread.currentThread().getName()+"完成比赛！"+System.currentTimeMillis());
            latch2.countDown();
        }
    }
    public static void main(String[] args) throws InterruptedException {
        new T1("张三",1).start();
        new T1("李四", 2).start();
        new T1("王五",3).start();
        TimeUnit.SECONDS.sleep(1);
        latch1.countDown();
        System.out.println("裁判宣布：开始比赛！");
        latch2.await();
        System.out.println("裁判宣布：结束比赛！");
    }
}
//main方法执行结果：
裁判宣布：开始比赛！
李四开始比赛！1603361167117
张三开始比赛！1603361167117
王五开始比赛！1603361167117
张三完成比赛！1603361168120
李四完成比赛！1603361169119
王五完成比赛！1603361170118
裁判宣布：结束比赛！
```

上述示例使用了两个CountDownLatch来做线程业务倒计时，latch1用于多个业务线程开始前的阻塞，latch2用于等待多个业务线程执行完后的主线程阻塞。打印结果可以印证latch1.countDown()执行后三个线程开始执行，等三个线程执行后才会执行latch2.await()后的代码。

##### CountDownLatch其他方法

- boolean await(long times, TimeUnit unit)，设置有超时限制的闭锁等待方法，若限制时间内闭锁对象减到0，则返回true；若时间超时则返回false，无论闭锁对象是否减到0，都会直接唤醒当前线程。

##### **CountDownLatch实现原理**

CountDownLatch底层依赖于AQS抽象同步队列实现，在CountDownLatch进行初始化时，就是给同步队列的State变量赋值，当执行countDown()时就是将这个state变量减一，而调用await()方法则会让当前线程陷入等待，并且会在一个无限for循环中监控等待state减为0，当state减到0时会将所有等待线程解锁继续执行。

====

##### CyclicBarrier基本用法

CyclicBarrier循环栅栏功能和CountDownLatch作用类似，都是在满足条件前使多个线程陷入等待状态，满足条件后各线程可同时开始执行；只不过CyclicBarrier的唤醒条件和CountDownLatch是相反的，CountDownLatch是倒减到0时唤醒所有线程，CyclicBarrier是累加到一个阈值时唤醒所有线程，而且CyclicBarrier是可以重复使用和重置的。主要方法如下：

```java
//创建栅格对象(等待线程达到3时唤醒所有线程)
CyclicBarrier cyclicBarrier = new CyclicBarrier(3);
//使当前线程陷入等待
cyclicBarrier.awat();
```

下面看一个实例：

```java
public class CyclicBarriierTest1 {
    static CyclicBarrier cyclicBarrier = new CyclicBarrier(3);

    static class T1 extends Thread{
        private int i = 0;
        public T1(String name, int i){
            this.setName(name);
            this.i = i;
        }

        @Override
        public void run() {
            battle();
            driver();
        }

        public void battle(){
            try {
                cyclicBarrier.await();
                System.out.println(Thread.currentThread().getName()+"开始比赛！"+System.currentTimeMillis());
                TimeUnit.SECONDS.sleep(i);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (BrokenBarrierException e) {
                e.printStackTrace();
            }

            System.out.println(Thread.currentThread().getName()+"完成比赛！"+System.currentTimeMillis());
        }

        public void driver(){
            try {
                 System.out.println(Thread.currentThread().getName()+"已登车！"+System.currentTimeMillis());
                cyclicBarrier.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (BrokenBarrierException e) {
                e.printStackTrace();
            }

            System.out.println(Thread.currentThread().getName()+"司机开车离开！"+System.currentTimeMillis());
        }
    }

    public static void main(String[] args) {
        new CyclicBarriierTest1.T1("张三",1).start();
        new CyclicBarriierTest1.T1("李四", 2).start();
        new CyclicBarriierTest1.T1("王五",3).start();

    }
}
//main方法执行结果：
王五开始比赛！1603362761465
李四开始比赛！1603362761465
张三开始比赛！1603362761465
张三完成比赛！1603362762465
张三已登车！1603362762465
李四完成比赛！1603362763497
李四已登车！1603362763497
王五完成比赛！1603362764465
王五已登车！1603362764465
张三司机开车离开！1603362765465
李四司机开车离开！1603362765465
王五司机开车离开！1603362765465
```

示例中一个CyclicBarrier对象使用了两次，第一次要等到三个线程都进入等待时唤醒所有线程开始执行，先执行完成的线程陷入第二次CyclicBarrier的等待状态，等到所有线程执行到入第二次CyclicBarrier的await()时(所有人已登车后，一同离开)，才会二次唤醒所有线程执行'开车离开'。所以，CyclicBarrier可以重复使用。

若是任意一个CyclicBarrier线程在等待过程中使用了interrupt()或是await(long times, TimeUnit unit)超时，则会破坏栅栏对象的阻塞状态，使所有线程立即开始执行，见下方示例：

```java


public class CyclicBarriierTest1 {
    static CyclicBarrier cyclicBarrier = new CyclicBarrier(3);

    static class T1 extends Thread{
        private int i = 0;
        public T1(String name, int i){
            this.setName(name);
            this.i = i;
        }

        @Override
        public void run() {
            battle();
        }

        public void battle(){
            try {
                if(Thread.currentThread().getName().equals("张三")){
                    cyclicBarrier.await(1, TimeUnit.SECONDS);
                }else{
                    cyclicBarrier.await();
                }
                System.out.println(Thread.currentThread().getName()+"开始比赛！"+System.currentTimeMillis());
                TimeUnit.SECONDS.sleep(i);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (BrokenBarrierException e) {
                e.printStackTrace();
            } catch (TimeoutException e) {
                e.printStackTrace();
            }

            System.out.println(Thread.currentThread().getName()+"完成比赛！"+System.currentTimeMillis());
        }
    }

    public static void main(String[] args) throws InterruptedException {
        new CyclicBarriierTest1.T1("张三",1).start();
        new CyclicBarriierTest1.T1("李四", 2).start();
        TimeUnit.SECONDS.sleep(5);
        new CyclicBarriierTest1.T1("王五",3).start();
    }
}
//main方法执行结果：
张三完成比赛！1603446746653
java.util.concurrent.TimeoutException
李四完成比赛！1603446746654
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:258)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:436)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
java.util.concurrent.BrokenBarrierException
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:251)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:33)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
java.util.concurrent.BrokenBarrierException
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:208)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:33)
王五完成比赛！1603446750651
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
```

当张三线程超时，CyclicBarriier对象被破坏，张三和李四的线程立即抛出异常，执行catch代码块和之后的代码，在4秒后，王五线程开始执行，发现CyclicBarriier对象被破坏，所以不用等待，立即抛出异常继续执行。

使用线程的interrupt()中断可以产生一样的效果：

```java
//线程都使用 cyclicBarrier.await();，但是使用线程中断
public void battle(){
    try {

        cyclicBarrier.await();
        System.out.println(Thread.currentThread().getName()+"开始比赛！"+System.currentTimeMillis());
        TimeUnit.SECONDS.sleep(i);
    } catch (InterruptedException e) {
        e.printStackTrace();
    } catch (BrokenBarrierException e) {
        e.printStackTrace();
    }

    System.out.println(Thread.currentThread().getName()+"完成比赛！"+System.currentTimeMillis());
}
public static void main(String[] args) throws InterruptedException {
        CyclicBarriierTest1.T1 t1 = new CyclicBarriierTest1.T1("张三",1);
        t1.start();
        new CyclicBarriierTest1.T1("李四", 2).start();
        t1.interrupt();
        TimeUnit.SECONDS.sleep(5);
        new CyclicBarriierTest1.T1("王五",3).start();
}
//main方法执行结果：
java.lang.InterruptedException
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:212)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
java.util.concurrent.BrokenBarrierException
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:208)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
张三完成比赛！1603447193556
李四完成比赛！1603447193557
java.util.concurrent.BrokenBarrierException
王五完成比赛！1603447198552
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:208)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
```

CyclicBarriier对象被破坏后，可以使用reset()方法恢复重置栅格对象，见下方示例：

```java
//执行cyclicBarrier.reset()后再执行一次
public static void main(String[] args) throws InterruptedException {
    CyclicBarriierTest1.T1 t1 = new CyclicBarriierTest1.T1("张三",1);
    t1.start();
    new CyclicBarriierTest1.T1("李四", 2).start();
    t1.interrupt();
    TimeUnit.SECONDS.sleep(5);
    new CyclicBarriierTest1.T1("王五",3).start();

    System.out.println("=========重新开始比赛=======");
    cyclicBarrier.reset();
    new CyclicBarriierTest1.T1("张三",1).start();
    new CyclicBarriierTest1.T1("李四", 2).start();
    new CyclicBarriierTest1.T1("王五",3).start();
}
//main方法执行结果：
java.lang.InterruptedException
张三完成比赛！1603447612294
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:212)
李四完成比赛！1603447612294
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
java.util.concurrent.BrokenBarrierException
	at java.base/java.util.concurrent.CyclicBarrier.dowait(CyclicBarrier.java:251)
	at java.base/java.util.concurrent.CyclicBarrier.await(CyclicBarrier.java:363)
	at org.jeecg.CyclicBarriierTest1$T1.battle(CyclicBarriierTest1.java:31)
	at org.jeecg.CyclicBarriierTest1$T1.run(CyclicBarriierTest1.java:24)
=========重新开始比赛=======
李四开始比赛！1603447617290
张三开始比赛！1603447617290
王五开始比赛！1603447617290
张三完成比赛！1603447618291
李四完成比赛！1603447619291
王五完成比赛！1603447620291
```

CyclicBarriier对象除了一个线程阈值的参数外，还有一个两参的构造方法：

```java
public CyclicBarrier(int parties, Runnable barrierAction);
```

第二个参数是一个线程实现类，这个实现类会由达到阈值的最后一个线程来执行，见下方示例：

```java
public class CyclicBarriierTest2 {
    static CyclicBarrier cyclicBarrier = new CyclicBarrier(3, ()->{
        System.out.println(Thread.currentThread().getName()+"来关门！"+System.currentTimeMillis());
    });

    static class T1 extends Thread{
        private int i = 0;
        public T1(String name, int i){
            this.setName(name);
            this.i = i;
        }

        @Override
        public void run() {
            battle();
        }

        public void battle(){
            try {

                cyclicBarrier.await();
                System.out.println(Thread.currentThread().getName()+"开始比赛！"+System.currentTimeMillis());
                TimeUnit.SECONDS.sleep(i);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (BrokenBarrierException e) {
                e.printStackTrace();
            }

            System.out.println(Thread.currentThread().getName()+"完成比赛！"+System.currentTimeMillis());
        }
    }

    public static void main(String[] args) throws InterruptedException {
        new CyclicBarriierTest2.T1("张三",1).start();
        new CyclicBarriierTest2.T1("李四", 2).start();
        TimeUnit.SECONDS.sleep(5);
        new CyclicBarriierTest2.T1("王五",3).start();

    }
}
//main方法执行结果：
王五来关门！1603448215108
王五开始比赛！1603448215108
张三开始比赛！1603448215108
李四开始比赛！1603448215108
张三完成比赛！1603448216108
李四完成比赛！1603448217109
王五完成比赛！1603448218108
```

可以发现Runnable barrierAction由最后达到阈值的王五线程来执行的。

##### **CyclicBarriier实现原理**

CyclicBarriier的实现原理和CountDownLatch类似但是又有一些差异，他不是直接使用的AQS抽象类，而是在其内部创建了ReentrantLock和Condition对象，通过这两个对象完成的多线程阻塞又同时开始逻辑：

在创建CyclicBarriier对象时，设置的线程数也是设置给AQS的state变量的，而且每当一个线程调用await()就会让state减一，并在之后把线程加入Condition的队列中，让线程陷入等待，等到state减为0时，Condition会释放所有线程开始执行。

多线程协作示例：

https://www.cnblogs.com/MrSi/p/9690937.html