多线程AQS简析

### AQS类的简单解析

#### 1.AQS的使用对象

ReentrantLock、CountDownLatch等多线程工具对象都是通过AbstractQueuedSynchronizer(以下简称AQS对象)实现的，这些对象都使用了AQS类的FIFO队列和state锁状态维护的线程互斥等待功能

#### 2.AQS是什么

AQS类是java提供的一个抽象类，这类中维护了一个线程FIFO链表队列，和一个锁状态对象state。以ReentrantLock对象为例，通过一个Sync内部类对象继承了AQS抽象类，从而实现了使用sync类实现了加锁和解锁逻辑。

我们先了解下AQS类的主要内部组成、以及FIFO线程链表队列

```java
//AQS类
//java.util.concurrent.locks.AbstractQueuedSynchronizer
public abstract class AbstractQueuedSynchronizer
    extends AbstractOwnableSynchronizer
    implements java.io.Serializable {

    private static final long serialVersionUID = 7373984972572414691L;
    //指向首个node节点
    private transient volatile Node head;
	//指向最后一个node节点
    private transient volatile Node tail;
    //锁状态字段(大于0代表有线程获取了锁)
    private volatile int state;

    protected AbstractQueuedSynchronizer() { }
	//将等待线程封装成的node类
    static final class Node {
        /** Marker to indicate a node is waiting in shared mode */
        static final Node SHARED = new Node();
        /** Marker to indicate a node is waiting in exclusive mode */
        static final Node EXCLUSIVE = null;

        /** waitStatus value to indicate thread has cancelled */
        static final int CANCELLED =  1;
        /** waitStatus value to indicate successor's thread needs unparking */
        static final int SIGNAL    = -1;
        /** waitStatus value to indicate thread is waiting on condition */
        static final int CONDITION = -2;
        /**
         * waitStatus value to indicate the next acquireShared should
         * unconditionally propagate
         */
        static final int PROPAGATE = -3;
		//当前线程的等待状态，对应上面4个值
        volatile int waitStatus;
		//指向前一个node节点
        volatile Node prev;
        //指向后一个node节点
        volatile Node next;
        //当前线程对象
        volatile Thread thread;

        Node nextWaiter;

        final boolean isShared() {
            return nextWaiter == SHARED;
        }

        final Node predecessor() throws NullPointerException {
            Node p = prev;
            if (p == null)
                throw new NullPointerException();
            else
                return p;
        }

        Node() {    // Used to establish initial head or SHARED marker
        }

        Node(Thread thread, Node mode) {     // Used by addWaiter
            this.nextWaiter = mode;
            this.thread = thread;
        }

        Node(Thread thread, int waitStatus) { // Used by Condition
            this.waitStatus = waitStatus;
            this.thread = thread;
        }
    }
    
    //...
}
```

上述AQS类中维护了一个线程Node内部类对象，这个对象会将当前线程信息封装成一个node实例，用于获取不到锁对象时，进入FIFO队列中阻塞(AQS类中主要维护了一个获取不到锁的等待线程队列)。

AQS类中还有head和tail属性，分别指向队列的队首元素和队尾元素，整个队列关系如下图所示：

![image-20201219143503748](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201219143522.png)

线程队列说明完了，下面就是state这个成员变量，这个变量就是维护了整个锁对象是否上锁的关键。

关于state对象主要有以下几点说明：

- state对象默认为0，此时处于未上锁状态，所有的线程都可以去尝试争取这个锁
- 一个线程尝试获取到锁的动作就是使用CAS将state改为1时，当修改成功时，代表这个线程已经获取到锁了，则会将当前线程设置为独占锁的线程
- 其他线程使用CAS修改state失败时，则代表获取锁失败，则会进入之前说的FIFO等待线程队列进行阻塞，等待锁释放时被唤醒，进行下一轮锁的争取
- 当前或到锁的线程再次获取锁时，会将state+1，代表线程进行了锁的重入操作
- 当获取锁线程释放锁时，会将state-1，直到减为零时，代表锁完全释放

#### 3.加锁过程

下面我们来分析下整个加锁的过程，下面以ReentrantLock为例来说明整个过程，先来看下ReentrantLock的类关系图：

![image-20201219151734289](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201219151734.png)

ReentrantLock的主要加/解锁中依赖于Sync内部类实现，Sync内部类是一个继承AQS类的抽象类，有NofairSync非公平锁实现和FairSync公平锁两种实现，在创建ReentrantLock实例时可以选择sync成员变量的实现方式(默认为非公平锁实现)

创建一个ReentrantLock实例，调用实例的lock()方法，具体为非公平锁实现的lock()

```java
//java.util.concurrent.locks.ReentrantLock.NonfairSync#lock
final void lock() {
    //使用CAS设置锁状态为1(state初始状态为0)
    if (compareAndSetState(0, 1))
       //将首个赋值state成功的线程设置为独占锁的获取线程 
        setExclusiveOwnerThread(Thread.currentThread());
    else
        //获取锁失败的线程进入自旋，等待下次获取锁的机会
        acquire(1);
}

//java.util.concurrent.locks.AbstractQueuedSynchronizer#acquire
public final void acquire(int arg) {
    //步骤1：tryAcquire(arg)再次尝试获取锁，获取成功返回true
    //步骤2：步骤1获取锁失败时，将此线程加入等待队列中addWaiter(Node.EXCLUSIVE)
    //步骤3：执行acquireQueued(addWaiter(node, arg))使线程进入自旋，根据线程的waitStatus状态判断是否需要使线程陷入等待
    //步骤4：若步骤1返回false，在步骤3的自旋中返回true，则会中断当前线程
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

主要逻辑是访问lock()方法的线程尝试设置state锁状态为1，设置成功的线程为获取锁的线程，获取失败的线程进入自旋，要么阻塞，要么解锁阻塞状态再次尝试获取锁成功。

实际上tryAcquire(arg)在这里就是一个插队的方法，可能队列中还有不少等待线程，此次再来一个线程则可能通过tryAcquire(arg)方法插队获取到锁

**尝试获取锁**

```java
//尝试获取锁
//java.util.concurrent.locks.ReentrantLock.NonfairSync#tryAcquire
protected final boolean tryAcquire(int acquires) {
    return nonfairTryAcquire(acquires);
}

final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    //获取当前线程的锁状态
    int c = getState();
    //锁状态为0表示无线程获取锁
    if (c == 0) {
        if (compareAndSetState(0, acquires)) {
            //尝试获取锁，成功则将status设置为1，并将线程设置为独占线程
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    //如果当前线程和之前获取锁的独占线程是同一个对象，则将state+1(锁重入)
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

首次获取锁失败的线程会再次通过tryAcquire方法尝试获取线程，若当前线程和获取锁的线程相同，则使state再加1

再次获取锁失败使，会将当前线程封装为Node节点的addWaiter(Node.EXCLUSIVE)加入到FIFO等待队列

```java
//java.util.concurrent.locks.AbstractQueuedSynchronizer#addWaiter
private Node addWaiter(Node mode) {
    //将当前节点封装成Node节点(Node节点是AQS抽象类中的封装等待线程的对象)
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    Node pred = tail;
    if (pred != null) {
        node.prev = pred;
        //尝试将当前新增节点设置为尾节点
        if (compareAndSetTail(pred, node)) {
            //将原来的尾节点next指向新增节点
            pred.next = node;
            return node;
        }
    }
    //自旋，确保多个等待线程正确的插入到队列中
    enq(node);
    //返回最后一个线程节点
    return node;
}

//java.util.concurrent.locks.AbstractQueuedSynchronizer#enq
private Node enq(final Node node) {
    //一直自旋，直到当前线程node对象成功入队，之后返回此node对象
    for (;;) {
        Node t = tail;
        //如果等待线程队列没有元素
        if (t == null) { // Must initialize
            //则创建一个一个空的node节点，使head和tail都指向他
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            //再次循环时，将当前线程的node节点插入到队尾
            node.prev = t;
            //尝试将node节点设置到tail中(CAS设置)
            //若内存值还是t，则将tail赋值为node
            if (compareAndSetTail(t, node)) {
                //插入成功后返回倒数第二个节点(在加锁过程中没有使用)
                t.next = node;
                return t;
            }
        }
    }
}
```

线程node节点创建成功后会再次尝试获取锁，获取失败时会使用LockSupport.park()进行阻塞；等待队列一直自旋尝试获取锁acquireQueued(node, args)

```java
//java.util.concurrent.locks.AbstractQueuedSynchronizer#acquireQueued
//队列中第二个线程元素尝试获取锁
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        //是否需要中断唤醒当前线程的标记
        boolean interrupted = false;
        //获取不到锁的线程一直自旋，直到获取到锁返回interrupted标记
        for (;;) {
            //获取当前节点的前一个节点
            final Node p = node.predecessor();
            //如果前一个节点就是队列首节点，则尝试获取锁
            if (p == head && tryAcquire(arg)) {
                //获取到锁后，将当前节点设置为队首head
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            //判断非队首元素是否需要阻塞
            //(二次循环时shouldParkAfterFailedAcquire会返回true，并阻塞线程)
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}

//java.util.concurrent.locks.AbstractQueuedSynchronizer#shouldParkAfterFailedAcquire
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    //获取等待线程node的等待状态(waitStatus默认为0)
    int ws = pred.waitStatus;
    //如果状态是-1则返回true，代表该线程需要中断唤醒了
    if (ws == Node.SIGNAL)
        return true;
    //如果状态大于0，则倒序循环等待队列，
    //将waitStatus状态都大于0的节点从队列中删除
    if (ws > 0) {
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
		//如果是等于0的状态，则将predNode的状态改为-1
        //此时，队首元素的waitStatus为-1
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}

//阻塞当前线程，等待唤醒后返回true
private final boolean parkAndCheckInterrupt() {
    LockSupport.park(this);
    return Thread.interrupted();
}
```

acquireQueued方法是线程等待队列最终自旋获取锁的地方，线程首次自旋获取锁失败时会将waitStatus设为-1，再次自旋获取锁失败时，会执行parkAndCheckInterrupt()进行阻塞，等待锁释放时被唤醒。

若获取锁成功时，则当前线程一定是队列中的第二个元素，并且会将这个元素设置为队首元素(也就是等待队列的队首元素是获取到锁正在执行的线程，第二个元素是尝试获取锁的线程)

#### 4.释放锁过程

调用ReentrantLock实例的unlock方法，则会调用AQS类中的release(1)方法

```java
//java.util.concurrent.locks.AbstractQueuedSynchronizer#release
public final boolean release(int arg) {
    //尝试释放锁
    //子类实现
    if (tryRelease(arg)) {
        //获取队首node元素，如果node的等待状态不是0则，会唤醒线程去获取锁
        Node h = head;
        if (h != null && h.waitStatus != 0)
            //子类实现
            unparkSuccessor(h);
        return true;
    }
    return false;
}

//java.util.concurrent.locks.ReentrantLock.Sync#tryRelease
protected final boolean tryRelease(int releases) {
    //加锁状态减1
    int c = getState() - releases;
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    //减到0时，其他线程可以抢锁，同时去除独占锁
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    //锁状态赋值更新
    setState(c);
    return free;
}

//java.util.concurrent.locks.AbstractQueuedSynchronizer#unparkSuccessor
private void unparkSuccessor(Node node) {
	//获取队首元素的等待状态
    int ws = node.waitStatus;
    //等待状态小于0时，则置0
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);
	//队首元素
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        //队列中只有一个元素，则直接获取队尾元素
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    //唤醒队列中第二个元素去获取锁信息
    if (s != null)
        LockSupport.unpark(s.thread);
}
```

释放锁逻辑相对简单一些，获取锁的线程会将state状态-1，当state减到0时，则会将锁的独占线程设置为null(setExclusiveOwnerThread(null))，同时将等待队列的第二个元素进行阻塞唤醒。



#### 5.非公平锁和公平锁的差异

![image-20201219155737678](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201219155737.png)

```java
public final boolean hasQueuedPredecessors() {
    // The correctness of this depends on head being initialized
    // before tail and on head.next being accurate if the current
    // thread is first in queue.
    Node t = tail; // Read fields in reverse initialization order
    Node h = head;
    Node s;
    //返回true，一定需要排队获取锁
    //如果当前线程不是等待队列的第二个元素，意味着等待队列有至少两个不同的线程，那么就一定要排队
    //返回false，则可以立即插队尝试获取锁，可能不用排队
    //如果当前线程是等待队列的第二个元素(已入队情况)，或队列为空，或只有一个元素(队列为空情况)
    return h != t &&
        ((s = h.next) == null || s.thread != Thread.currentThread());
}
```

公平锁相比于非公平锁就多一个hasQueuedPredecessors方法，这个方法会判断当前线程是否已经排在了线程等待队列中(当前线程可能已入队)，如果队列为空，则该线程前没有排队的线程，就可以直接尝试获取锁；或当前线程是等待队列的第二个node元素(马上轮到该线程了，就可以尝试获取锁)，则返回false无需排队。若队列不为空且至少有两个不同的等待线程，则返回true，一定需要排队

