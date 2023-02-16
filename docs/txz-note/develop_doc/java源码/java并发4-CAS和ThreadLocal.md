java并发4-CAS和ThreadLocal

#### 一、CAS乐观锁和Unsafe对象

在之前的学习中，为了保证数据的一致性，无论是Synchronized或是ReentrantLock，都是限制了同一时间只能有一个线程操作目标对象，期间会对目标对象进行加锁和解锁，这种通过序列化线程执行顺序来达到数据正确的思想就是悲观锁思想；与之相反，有一种性能更好的乐观锁思想，他的内容大概是这样的：

##### 乐观锁和原子对象

操作目标对象时不需要进行加锁操作，而是记录下目标对象的值A，在修改目标对象的值时再次获取目标对象的值B，通过计算A和B是否相等来判断目标对象的值是否被修改过，这整个逻辑是一个原子操作。用伪代码表示为：

```java
//获取目标对象的值
a = point
update table set point = 新值 where id = XXX and point = a;
if(sql修改的行数>0){
    //修改成功
}else{
    //事务回滚，重复这个过程，直到修改成功(自旋)
}
```

而CAS(compare and set)就是乐观锁的具体代码实现方案(一种非阻塞式的线程同步方案)：要修改目标值需要先获取内存值V和预期值A比较，若A==V则将目标值修改为B，下面用一个例子展示CAS自旋：

```java
public class AtomicTest1 {

    static volatile int count = 0;

    void requset(){
        int a;
        //直到修改成功会退出循环，不然一直自旋
        do{
            a = getCount();
        }while(!comareAndAdd(a, a+1));
    }

    synchronized boolean comareAndAdd(int expectVal, int newVal){
        if(expectVal == getCount()){
            count = newVal;
            return true;
        }
        return false;
    }

    int getCount(){
        return  count;
    }

    public static void main(String[] args) throws InterruptedException {
        AtomicTest1 test = new AtomicTest1();
        CountDownLatch latch = new CountDownLatch(100);
        for(int i = 0; i< 100; i++){
            new Thread(() ->{
                for(int j = 0; j< 10; j++) {
                    test.requset();
                }
                latch.countDown();
            }).start();
        }
        latch.await();
        System.out.println(test.getCount());
    }

}
//执行结果：
1000
```

实际上在JUC包中提供了这样的原子对象，他们会自动的完成CAS整个逻辑，这些元素对象若下图所示：

![image-20201029161733319](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103030.png)

下面我们用AtomicInteger替换调用上个示例的循环：

```java
public class AtomicTest2 {

    static AtomicInteger count = new AtomicInteger(0);


    public static void main(String[] args) throws InterruptedException {
        AtomicTest2 test = new AtomicTest2();
        CountDownLatch latch = new CountDownLatch(100);
        for(int i = 0; i< 100; i++){
            new Thread(() ->{
                for(int j = 0; j< 10; j++) {
                    test.count.incrementAndGet();
                }
                latch.countDown();
            }).start();
        }
        latch.await();
        System.out.println(test.count.get());
    }

}
//执行结果：
1000
```

在每次修改count时，都会进行一个CAS过程，要么自旋重新进行比较赋值，要么修改成功。

##### Unsafe对象

如果更加深入的了解AtomicInteger对象时，你会发现他的逻辑都是通过sun.misc.Unsafe对象实现的，由于Unsafe能像C语言那样直接操作内存空间，所以需要谨慎操作才行，下面来看一下这个Unsafe对象：

```java
public final class Unsafe {
    private static final Unsafe theUnsafe;
	static {
        registerNatives();
        Reflection.registerMethodsToFilter(Unsafe.class, new String[]{"getUnsafe"});
        theUnsafe = new Unsafe();   
        //...
   }
   public static Unsafe getUnsafe() {
        Class var0 = Reflection.getCallerClass();
        if (!VM.isSystemDomainLoader(var0.getClassLoader())) {
            throw new SecurityException("Unsafe");
        } else {
            return theUnsafe;
        }
    }
}
```

可以发现Unsafe对象是一个单例类对象，而且调用getUnsafe()必须要通过特别的类加载器才能获取到theUnsafe实例，通常我们获取到这个实例是通过反射获取的：

```java
public class UnsafeTest {

    static Unsafe unsafe;

    static{
        try {
            Field field = Unsafe.class.getDeclaredField("theUnsafe");
            field.setAccessible(true);
            unsafe = (Unsafe) field.get(null);
        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }
    }

    public static void main(String[] args) {
        System.out.println(unsafe);
    }

}
//执行结果：
sun.misc.Unsafe@1cd475
```

下面我们来通过Unsafe来代替AtomicInteger实现下CAS逻辑：

```java
public class AtomicTest3 {

    static int count = 0;

    static Unsafe unsafe;

    static long fieldOffset;

    static{
        try {
            Field field = Unsafe.class.getDeclaredField("theUnsafe");
            field.setAccessible(true);
            unsafe = (Unsafe) field.get(null);
            //获取当前类属性count的偏移量
            fieldOffset = unsafe.staticFieldOffset(AtomicTest3.class.getDeclaredField("count"));
        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }
    }


    public static void main(String[] args) throws InterruptedException {
        AtomicTest3 test = new AtomicTest3();
        CountDownLatch latch = new CountDownLatch(100);
        for(int i = 0; i< 100; i++){
            new Thread(() ->{
                for(int j = 0; j< 10; j++) {
                    unsafe.getAndAddInt(AtomicTest3.class, fieldOffset, 1);
                }
                latch.countDown();
            }).start();
        }
        latch.await();
        System.out.println(test.count);
    }

}
//执行结果：
1000
```

##### CAS的问题

- ABA问题：CAS会有ABA的问题出现，即一个线程要修改的目标值是A，此时另一个线程将目标值修改成了B，右修改成了A，造成目标值没被修改过的假象；前一个线程在执行修改操作时发现内存值和期望值相同，认为目标值没被修改过就可以进行修改。
- 自旋过长问题：若目标修改过于频繁，会导致某些线程一直在自旋赋值，需要重试很多次才会成功

ABA问题的处理方式：每次修改目标时，携带一个版本号(唯一值)，即ABA就变为了A1->B2->A3，这样就知道两个A是变更过的了，在JUC的原子操作对象中就通过AtomicStampedReference来解决ABA的问题，

#### 二、ThreadLocal

ThreadLocal是线程对象的补充对象，这个类本身不存储任何值，他只提供了对当前线程的thread.threadLocals属性的读写操作(类似于一个类提供get/set给外部操作私有属性)，这样相同线程创建不同的ThreadLocal对象，会在同一个ThreadLocalMap中存储不同的k-v，而不同线程在使用同一个ThreadLocal对象时，会创建各自的ThreadLocalMap对象。

##### ThreadLocal结构

下面我们来看一看ThreadLocal的具体结构：

```java
public class ThreadLocal<T> {
    
    //设置值
    public void set(T value) {
        Thread t = Thread.currentThread();
        //获取当前线程的ThreadLocalMap对象
        ThreadLocalMap map = getMap(t);
        if (map != null)
            //map对象已经存在则设置值(key=当前ThreadLocal实例,val=线程存储变量)
            map.set(this, value);
        else
            //不存在，则需要先创建ThreadLocalMap对象
            createMap(t, value);
    }
    //获取值
    public T get() {
        Thread t = Thread.currentThread();
        //获取当前线程的ThreadLocalMap对象
        ThreadLocalMap map = getMap(t);
        if (map != null) {
            //进一步获取ThreadLocalMap存储的val
            ThreadLocalMap.Entry e = map.getEntry(this);
            if (e != null) {
                @SuppressWarnings("unchecked")
                T result = (T)e.value;
                return result;
            }
        }
        return setInitialValue();
    }
    //删除map中存储的值
    public void remove() {
         ThreadLocalMap m = getMap(Thread.currentThread());
         if (m != null)
             m.remove(this);
     }
    
    ThreadLocalMap getMap(Thread t) {
        return t.threadLocals;
    }
    
    void createMap(Thread t, T firstValue) {
        t.threadLocals = new ThreadLocalMap(this, firstValue);
    }
    
    //下面是静态内部类ThreadLocalMap
    //static class ThreadLocalMap {
    //。。。。。
    //}
}
```

从上面的代码可以知道，ThreadLocal对象可以给当前线程的threadLocals属性赋值，这个值是一个map对象，具体而言是ThreadLocal的一个静态内部类ThreadLocal.ThreadLocalMap，也就是说当我们使用ThreadLocal存储数据时，那么就是给当前线程绑定一个map对象，这个线程任何时候都可以获取到这个map内的数据。

所以的ThreadLocal都是操作的ThreadLocalMap对象。所以，我们的目光需要移动到静态内部类ThreadLocal.ThreadLocalMap上：

```java
static class ThreadLocalMap {
    //初始数组长度
    private static final int INITIAL_CAPACITY = 16;
    //数据存储数组
    private Entry[] table;
    
    static class Entry extends WeakReference<ThreadLocal<?>> {
            /** The value associated with this ThreadLocal. */
            Object value;
			//实际存储的key指向ThreadLocal实例的引用是软引用
             //在每次gc时，若ThreadLocal实例没有强引用指向，会被回收掉
            Entry(ThreadLocal<?> k, Object v) {
                super(k);
                value = v;
            }
     }
     //构造方法，其中的的key是当前ThreadLocal实例，val是存储的对象
     //创建一个Entry对象，存储到table数组中
     ThreadLocalMap(ThreadLocal<?> firstKey, Object firstValue) {
            //如果发生扩容，会扩大为原来的2倍
            table = new Entry[INITIAL_CAPACITY];
            //取模
            int i = firstKey.threadLocalHashCode & (INITIAL_CAPACITY - 1);
            table[i] = new Entry(firstKey, firstValue);
            size = 1;
            setThreshold(INITIAL_CAPACITY);
    }
    //从Entry对象中根据ThreadLocal获取存储的val
    private Entry getEntry(ThreadLocal<?> key) {
            int i = key.threadLocalHashCode & (table.length - 1);
            Entry e = table[i];
            if (e != null && e.get() == key)
                return e;
            else
                return getEntryAfterMiss(key, i, e);
    }
    //同一个线程，新增其他ThreadLocl对象或修改ThreadLocl对象所在val
   private void set(ThreadLocal<?> key, Object value) {

            Entry[] tab = table;
            int len = tab.length;
            int i = key.threadLocalHashCode & (len-1);
			
            for (Entry e = tab[i];
                 e != null;
                 e = tab[i = nextIndex(i, len)]) {
                ThreadLocal<?> k = e.get();

                if (k == key) {
                    e.value = value;
                    return;
                }

                if (k == null) {
                    replaceStaleEntry(key, value, i);
                    return;
                }
            }

            tab[i] = new Entry(key, value);
            int sz = ++size;
            if (!cleanSomeSlots(i, sz) && sz >= threshold)
                rehash();
   }
    
    //当前线程从ThreadLocalMap中移出当前ThreadLocal实例及val
    private void remove(ThreadLocal<?> key) {
            Entry[] tab = table;
            int len = tab.length;
            int i = key.threadLocalHashCode & (len-1);
            for (Entry e = tab[i];
                 e != null;
                 e = tab[i = nextIndex(i, len)]) {
                if (e.get() == key) {
                    e.clear();
                    expungeStaleEntry(i);
                    return;
                }
            }
    }
}
```

在ThreadLocalMap我们知道，通过set()存储的数据，实际是以当前ThreadLocal实例为key，存储数据为val放在Entry数组中的，而其中的key又是以弱引用的方式指向的ThreadLocal实例，在每次gc时，若这个ThreadLocal实例没有其他强引用的指向，即使有这些弱引用存在，也会被回收掉。

整体的存储关系图如下所示：

![image-20210319111717575](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210319111717.png)

##### ThreadLocal内存泄漏问题

首先，内存泄漏是指一些对象对象长期持有某些内存空间，且无法释放的问题，这样时间长了会导致内存泄漏对象不断累积，最终导致内存溢出。

**ThreadLocal如何会发生内存泄漏的呢？**

前面提到过，Entry对象的key是弱引用指向的ThreadLocal实例，如果ThreadLocal实例没有其他外部强引用指向时，在下一次gc过程中会将ThreadLocal实例回收(尽管有弱引用的存在)，这样会形成一个key为null,val有值的entry对象，如果当前线程的生命周期和容器相同(例如线程池的核心线程)，那么这个entry指向的val对象就永远不会被回收，这样就形成了内存泄漏。

![image-20210319142132011](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210319142132.png)

**为什么要使用弱引用？直接用强引用不行吗？**

如果直接使用强引用，那么ThreadLocal实例和entry对象的val值对象都不会被回收，可能都会造成内存泄漏。（一般ThreadLocal实例会被定义为static静态对接，所以引用不会丢失）

**如何处理内存泄漏问题呢？**

在ThreadLocal使用完后，手动调用下remove()方法，将Entry对象从ThreadLocalMap中删除掉

**ThreadLocalMap使用的Entry数组如何处理哈希冲突？**

ThreadLocalMap底层使用的Entry数组，和hashMap不同，他并没有使用单链表(拉链法)进行哈希冲突的处理，而是采用一种开放地址法来处理的：

简单的说就是先通过哈希计算得到一个Entry数组的下标地址，判断这个下标所在位置是否已经有值，没有就直接写入，有就判断当前set的key和下标位置对象的key是否相同，不相同就是冲突了，需要重新计算下一个下标地址，相同就是map对象的修改，这种方式如出现多次哈希冲突，效率会很低。

![image-20210319144758363](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210319144758.png)

**ThreadLocal可以实现线程隔离，那么可以实现多线程数据共享吗？**

通过InheritableThreadLocal对象可以实现线程间的数据共享，原理是，使用inheritableThreadLocals存储共享数据，在之后创建新线程时，会在Thread的init()初始化方法中获取父线程的inheritableThreadLocals数据

```java
//java.lang.InheritableThreadLocal
void createMap(Thread t, T firstValue) {
    t.inheritableThreadLocals = new ThreadLocalMap(this, firstValue);
}
```

![image-20210319153034471](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210319153034.png)

##### ThreadLocal的使用场景

ThreadLocal可以保证线程之间的数据隔离

1.数据库连接上使，每个线程复用一个连接对象

```java
	//定义一个数据库连接
	private static Connection conn = null;
	private static ThreadLocal<Connection> connContainer = new ThreadLocal<Connection>();
	//获取连接
	public synchronized static Connection getConnection() {
		//获取连接对象(每个线程首次访问都会创建一个ThreadnLocalMap，key是同一个connContainer，val是下面的conn(一个线程只用一个xia)，之后会复用)
		conn = connContainer.get();
		try {
			if(conn == null) {
				Class.forName(DRIVER);
				conn = DriverManager.getConnection(URL, USER, PWD);
				connContainer.set(conn);
			}
		} catch (SQLException e) {
			e.printStackTrace();
		} catch (ClassNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return conn;
	}
```

2.处理SimpleDateFormat线程不安全问题，因为SimpleDateFormat对象父类DateFormat中的calendar对象是公用成员变量，并发情况下会被多次改动

```java
//每个线程创建一个SimpleDateFormat对象
static class test{
    public static ThreadLocal<SimpleDateFormat> threadLocal = ThreadLocal.withInitial(()->{
        return new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
    });
}
```

参考：https://www.zhihu.com/question/341005993