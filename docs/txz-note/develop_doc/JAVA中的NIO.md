JAVA中的NIO (New IO)

## JAVA中的NIO

标准的IO是基于字节流和字符流进行操作的，而JAVA中的NIO是基于Channel和Buffer进行操作的。

**传统IO**

字节流

InputStream

OutputStream

字符流

Reader

Writer

**NIO**

Channel

Buffer..

Channel

Buffer..

Channel

Buffer..

* * *

## 核心模块

NIO主要有三个核心部分：Selector、Channel、Buffer

数据总是从Channel读取到Buffer或者从Buffer写入到Channel中。

Selector可以监听多个Channel的多个事件。

Selector

Channel

Channel

Channel

Event...

Event...

Event...

* * *

## 传统的IO与Channel的区别

1.传统的IO是BIO的，而Channel是NIO的。

*当流调用了read()、write()方法后会一直阻塞线程直到数据被读取或写入完毕。

2.传统IO流是单向的，而Channel是双向的。

* * *

## Channel

```
FileChannel：从文件中进行读取

DatagramChannel：可以通过UDP协议在网络中进行数据的传输

SocketChannel：可以通过TCP协议在网络中进行数据的传输

ServerSocketChannel：可以作为一个服务器监听连接 
```

**Channel通用API:**

```
read(buffer)：将数据从Channel读取到Buffer中，读取完毕返回-1。

read(buffer [])：将数据从Channel读取到多个Buffer中，仅当第一个Buffer被写满后往第二个Buffer中进行写入。

write(buffer)：将Buffer中的数据写入到Channel中。

write(buffer[])：将多个Buffer中的数据写入到Channel中，仅当第一个Buffer中的数据被读取完毕后再从第二个Buffer中进行读取。

register(selector,interest)：将Channel注册到Selector中，同时需要向Selector传递要监听此Channel的事件类型(注册到Selector中的Channel一定要非阻塞的)

configureBlocking(boolean)：设置Channel是否为阻塞。

transferFrom(position,count,channel)：将其他Channel中的数据传输到当前Channel中。

transferTo(position,count,channel)：将当前Channel中的数据传输到其他Channel中。 
```

**SocketChannel API**

```
open()静态方法：创建SocketChannel。

connect(new InetSocketAddress(port))方法：连接服务器。

finishConnect()方法：判断是否已经与服务器建立连接。 
```

**ServerSocketChannel API**

```
open()静态方法：创建ServerSocketChannel。

accept()方法：该方法会一直阻塞线程直到有新连接到达。 
```

**阻塞式与非阻塞式Channel**

正常情况下Channel都是阻塞的，只有当调用了configureBlocking(false)方法时Channel才为非阻塞。

阻塞式Channel的connect()、accept()、read()、write()方法都会阻塞线程，直到处理完毕。

非阻塞式Channel的connect()、accept()、read()、write()方法都是异步的。

*当调用了非阻塞式Channel的connect()方法后，需要使用finishConnect()方法判断是否已经与服务器建立连接。

*当调用了非阻塞式Channel的accept()方法后，需要根据方法的返回值是否为NULL判断是否接收到新的连接。

*当调用了非阻塞式Channel的read()方法后，需要根据方法的返回值是否大于0判断是否有读取到数据。

*在使用非阻塞式Channel的write()方法时，需要借助while循环与hasRemaining()方法保证buffer中的内容被全部写入。

*FileChannel一定是阻塞的。

**示例**

```
public void testFileChannel() throws IOException {
    RandomAccessFile randomAccessFile = new RandomAccessFile(new File("F:\\笔记\\nginx.txt"), "rw");
    FileChannel fileChannel = randomAccessFile.getChannel();
    ByteBuffer byteBuffer = ByteBuffer.allocate(64);
    int count = fileChannel.read(byteBuffer);
    while (count != -1) {
        byteBuffer.flip();
        System.out.println(new String(Arrays.copyOfRange(byteBuffer.array(),0,byteBuffer.limit()),Charset.forName("UTF-8")));
        byteBuffer.clear();
        count = fileChannel.read(byteBuffer);
    }
} 
```

* * *

## Buffer

Buffer是一块可以进行读写操作的内存(顺序存储结构)

```
ByteBuffer：基于Byte类型进行存储

CharBuffer：基于Char类型进行存储

DoubleBuffer：基于Double类型进行存储

FloatBuffer：基于Float类型进行存储

IntBuffer：基于Int类型进行存储

LongBuffer：基于Long类型进行存储

ShortBuffer：基于Short类型进行存储 
```

**Buffer的内部结构**

1.capacity：表示buffer的容量

2.position：表示当前的位置(从0开始，最大值为capacity-1)

3.limit：在写模式中表示可以写入的个数(与capacity一样)，在读模式中表示可以读取的个数。

![](../_resources/21e7e594fb0a45adbdc743dac8dc5a6a.png)

**从写模式转换成读模式**

limit设置为position+1，position设置为0。

**从读模式转换成写模式**

limit设置为capacity，position设置为0。

**往Buffer中写数据**

1.将数据从Channel读取到Buffer中。

2.使用Buffer的put()方法。

**从Buffer中读数据**

1.将Buffer中的数据写入到Channel中。

2.使用Buffer的get()方法

**Buffer通用API:**

```
allocate(size)静态静态：初始化一个Buffer。

flip()：将buffer从写模式转换成读模式。

array()：将Buffer中的内容转换成数组(不受limit控制)

get()：获取Buffer中的内容。

hasRemaining()：判断Buffer中是否还有未读的元素(limit - (postion+1) )

rewind()：将positon设置为0。

clear()：将limit设置为capacity，position设置为0。

compact()：将所有未读的元素移动到Buffer的起始处，position指向最后一个未读的元素的下一位，limit设置为capacity。

*clear()和compact()方法都可以理解成将Buffer从读模式转换成写模式，区别在于compact()方法会保留未读取的元素。

mark()：在当前position处打一个标记。

reset()：将position恢复到标记处。 
```

* * *

## Selector

Selector用于监听多个Channel的多个事件(单线程)

Selector

Channel

Channel

Channel

connect

accept

connect

read

**Channel的事件类型**

1.连接就绪：当SocketChannel、DatagramChannel成功与服务器建立连接时将会触发连接就绪事件。

2.接收就绪：当有连接到达服务器时将会触发接收就绪事件。

3.读就绪：当SocketChannel、DatagramChannel有数据可读时将会触发读就绪事件。

4.写就绪：当SocketChannel、DatagramChannel可以进行数据写入时将会触发写就绪事件。

**SelectionKey**

SelectionKey用于存储Selector与Channel之间的相关信息。

SelectionKey中提供了四个常量分别代表Channel的事件类型。

```
SelectionKey.OP_CONNECT

SelectionKey.OP_ACCEPT

SelectionKey.OP_READ

SelectionKey.OP_WRITE 
```

SelectableChannel提供的register(selector,interest)方法用于将Channel注册到Selector中，同时需要向Selector传递要监听此Channel的事件类型，当要监听的事件类型不止一个时可以使用或运算，当将Channel注册到Selector后会返回SelectionKey实例，用于存储Selector与此Channel之间的相关信息。

**SelectionKey API：**

```
interestOps()方法：返回Selector监听此Channel的事件类型。

readyOps()方法：返回此Channel目前就绪的事件。

isAcceptable()：判断Channel是否接收就绪。

isConnectable()：判断Channel是否连接就绪。

isReadable()：判断Channel是否读就绪。

isWriteable()：判断Channel是否写就绪。

channel()：返回具体的Channel实例。

selector()：返回Selector实例。

attach()：往SelectionKey中添加一个附加对象。

attachment()：返回保存在SelectionKey中的附加对象。 
```

**Selector API：**

```
open()静态方法：创建一个Selector。

select()方法：该方法会一直阻塞线程直到所监听的Channel有事件就绪，返回就绪的Channel个数(只会返回新就绪的Channel个数)

selectedKeys()方法：返回就绪的Channel对应的SelectionKey。

*当Channel就绪的事件处理完毕后，需要手动删除SelectionKey集合中该Channel对应的SelectionKey，当该Channel再次有事件就绪时会自动加入到Selectionkey集合中。 
```

**非阻塞式Channel与Selector**

非阻塞式Channel一般与Selector配合使用

当Selector监听到ServerSocketChannel接收就绪时，那么此时可以立即调用ServerSocketChannel的accept()方法获取新连接。

当Selector监听到SocketChannel读就绪时，那么此时可以立即调用SocketChannel的read()方法进行数据的读取。

**非阻塞式服务器**

```
/**
 * @Author: Zhuang HaoTang
 * @Date: 2019/10/26 16:35
 * @Description:
 */
public class Server {

    public void start() throws IOException {
        Selector selector = Selector.open();
        ServerSocketChannel serverSocketChannel = createNIOServerSocketChannel();
        System.out.println("start nio server and bind port 8888");
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
        int ready = selector.select();
        while (ready > 0) {
            System.out.println("ready channel count " + ready);
            Set<SelectionKey> selectionKeySet = selector.selectedKeys();
            for (Iterator<SelectionKey> iterator = selectionKeySet.iterator(); iterator.hasNext(); ) {
                SelectionKey selectionKey = iterator.next();
                if (selectionKey.isAcceptable()) {
                    System.out.println("acceptable");
                    acceptHandler(selectionKey);
                } else if (selectionKey.isReadable()) {
                    System.out.println("readable");
                    readHandler(selectionKey);
                }
                iterator.remove();
            }
            ready = selector.select();
        }
    }

    private ServerSocketChannel createNIOServerSocketChannel() throws IOException {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.bind(new InetSocketAddress(InetAddress.getLocalHost(), 8888));
        serverSocketChannel.configureBlocking(false);
        return serverSocketChannel;
    }

    private void acceptHandler(SelectionKey selectionKey) throws IOException {
        Selector selector = selectionKey.selector();
        ServerSocketChannel serverSocketChannel = (ServerSocketChannel) selectionKey.channel();
        SocketChannel socketChannel = serverSocketChannel.accept();
        socketChannel.configureBlocking(false);
        socketChannel.register(selector, SelectionKey.OP_READ);
        System.out.println("accept client connection " + socketChannel.getLocalAddress());
    }

    private void readHandler(SelectionKey selectionKey) throws IOException {
        SocketChannel socketChannel = (SocketChannel) selectionKey.channel();
        ByteBuffer byteBuffer = ByteBuffer.allocate(100);
        int num = socketChannel.read(byteBuffer);
        if(num == -1){ // 连接已断开
            System.out.println("client "+socketChannel.getLocalAddress() + " disconnection");
            socketChannel.close();
            return;
        }
        byteBuffer.flip();
        while (byteBuffer.hasRemaining()) {
            byte b = byteBuffer.get();
            System.out.println((char) b);
        }
    }

    public static void main(String[] args) throws IOException {
        Server server = new Server();
        server.start();
    }

} 
```

*一个Channel不会同时有多个事件就绪，以事件为单位。

*当客户端断开连接，那么将会触发读就绪，并且channel的read()方法返回-1，表示连接已断开，服务器应该要做出处理，关闭这个连接。

**客户端**

```
/**
 * @Auther: Zhuang HaoTang
 * @Date: 2019/10/26 16:36
 * @Description:
 */
public class Client {

    public static void main(String[] args) throws IOException, InterruptedException {
        SocketChannel socketChannel = SocketChannel.open();
        socketChannel.connect(new InetSocketAddress(InetAddress.getLocalHost(),8888));

        String message = "today is sunday";
        ByteBuffer byteBuffer = ByteBuffer.allocate(message.getBytes().length);
        byteBuffer.put(message.getBytes());
        byteBuffer.flip();
        socketChannel.write(byteBuffer);
        Thread.sleep(5000);
    }

} 
```

**运行结果**

<img width="1543" height="911" src="../_resources/0bf91bed63ca432ea81913c1016e609b.png"/>

* * *

## Reactor模式

Reactor有三种模式

```
1.Reactor单线程模式
2.Reactor多线程模式
3.主从Reactor多线程模式 
```

*Reactor模式是在NIO下实现的。

## Reactor单线程模式

<img width="1543" height="652" src="../_resources/b71dfd960ebc496c80ac2fd89d01babe.png"/>

1.单线程的事件分化器，同时这个线程需要处理接收、读、写就绪事件。

```
/**
 * @Author: Zhuang HaoTang
 * @Date: 2019/10/26 16:35
 * @Description:
 */
public class ReactorSingleThreadServer {

    private void start() throws IOException {
        Selector selector = Selector.open();
        ServerSocketChannel serverSocketChannel = createNIOServerSocketChannel();
        System.out.println("start nio server and bind port 8888");
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
        int ready = selector.select();
        while (ready > 0) {
            System.out.println("ready channel count " + ready);
            Set<SelectionKey> selectionKeySet = selector.selectedKeys();
            for (Iterator<SelectionKey> iterator = selectionKeySet.iterator(); iterator.hasNext(); ) {
                SelectionKey selectionKey = iterator.next();
                if (selectionKey.isAcceptable()) {
                    System.out.println("acceptable");
                    acceptHandler(selectionKey);
                } else if (selectionKey.isReadable()) {
                    System.out.println("readable");
                    readHandler(selectionKey);
                }
                iterator.remove();
            }
            ready = selector.select();
        }
    }

    private ServerSocketChannel createNIOServerSocketChannel() throws IOException {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.bind(new InetSocketAddress(InetAddress.getLocalHost(), 8888));
        serverSocketChannel.configureBlocking(false);
        return serverSocketChannel;
    }

    private void acceptHandler(SelectionKey selectionKey) throws IOException {
        Selector selector = selectionKey.selector();
        ServerSocketChannel serverSocketChannel = (ServerSocketChannel) selectionKey.channel();
        SocketChannel socketChannel = serverSocketChannel.accept();
        socketChannel.configureBlocking(false);
        socketChannel.register(selector, SelectionKey.OP_READ);
        System.out.println("accept client connection " + socketChannel.getLocalAddress());
    }

    private void readHandler(SelectionKey selectionKey) throws IOException {
        SocketChannel socketChannel = (SocketChannel) selectionKey.channel();
        ByteBuffer byteBuffer = ByteBuffer.allocate(100);
        int num = socketChannel.read(byteBuffer);
        if (num == -1) {
            System.out.println("client " + socketChannel.getLocalAddress() + " disconnection");
            socketChannel.close();
            return;
        }
        byteBuffer.flip();
        while (byteBuffer.hasRemaining()) {
            byte b = byteBuffer.get();
            System.out.println((char) b);
        }
    }

    public static void main(String[] args) throws IOException {
        ReactorSingleThreadServer server = new ReactorSingleThreadServer();
        server.start();
    }

} 
```

## Reactor多线程模式

![](../_resources/bd7cf56d2f3f49aeb7d480c112444f28.png)

1.单线程的事件分发器。

2.具体事件类型的Handler线程池（针对读写就绪事件）

3.业务线程池。

```
/**
 * @Author: Zhuang HaoTang
 * @Date: 2019-10-28 17:00
 * @Description:
 */
public class ReactorMultiThreadServer {

    private ThreadPoolExecutor eventHandlerPool = new ThreadPoolExecutor(10, 50, 2, TimeUnit.MINUTES, new ArrayBlockingQueue<Runnable>(200), new ThreadPoolExecutor.CallerRunsPolicy());

    private void start() throws IOException {
        Selector selector = Selector.open();
        ServerSocketChannel serverSocketChannel = createNIOServerSocketChannel();
        System.out.println("start nio server and bind port 8888");
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
        selector.select();
        for (;;) {
            Set<SelectionKey> selectionKeySet = selector.selectedKeys();
            for (Iterator<SelectionKey> iterator = selectionKeySet.iterator(); iterator.hasNext(); ) {
                final SelectionKey selectionKey = iterator.next();
                if (selectionKey.isAcceptable()) {
                    System.out.println("acceptable");
                    acceptHandler(selectionKey); // 单线程同步处理接收就绪
                } else if (selectionKey.isReadable()) {
                    System.out.println("readable");
                    eventHandlerPool.submit(new Runnable() {
                        @Override
                        public void run() {
                            readHandler(selectionKey);
                        }
                    });
                }
                iterator.remove();
            }
            selector.select();
        }
    }

    private ServerSocketChannel createNIOServerSocketChannel() throws IOException {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.bind(new InetSocketAddress(InetAddress.getLocalHost(), 8888));
        serverSocketChannel.configureBlocking(false);
        return serverSocketChannel;
    }

    private void acceptHandler(SelectionKey selectionKey) throws IOException {
        Selector selector = selectionKey.selector();
        ServerSocketChannel serverSocketChannel = (ServerSocketChannel) selectionKey.channel();
        SocketChannel socketChannel = serverSocketChannel.accept();
        if (socketChannel != null) {
            socketChannel.configureBlocking(false);
            socketChannel.register(selector, SelectionKey.OP_READ);
            System.out.println("accept client connection " + socketChannel.getLocalAddress());
        }
    }

    private void readHandler(SelectionKey selectionKey) {
        SocketChannel socketChannel = (SocketChannel) selectionKey.channel();
        ByteBuffer byteBuffer = ByteBuffer.allocate(100);
        try {
            int num = socketChannel.read(byteBuffer);
            if (num == -1) {
                System.out.println("client " + socketChannel.getLocalAddress() + " disconnection");
                socketChannel.close(); // 底层有些逻辑
                return;
            }
            byteBuffer.flip();
            while (byteBuffer.hasRemaining()) {
                byte b = byteBuffer.get();
                System.out.println((char) b);
            }
        } catch (Exception e) {
            System.out.println("由于连接关闭导致并发线程读取异常");
        }
    }

    public static void main(String[] args) throws IOException {
        ReactorMultiThreadServer reactorServer = new ReactorMultiThreadServer();
        reactorServer.start();
    }

} 
```

## 主从Reactor多线程模式

![](../_resources/fa4e8202eafa4cd79111194e2f0acdbc.png)

1.使用两个单线程的事件分发器。

```
第一个事件分发器只负责监听ServerSocketChannel的接收就绪事件，同时ServerSocketChannel接收到的连接要注册到第二个事件分发器中。
第二个事件分发器只负责监听SocketChannel的读、写就绪事件。 
```

2.具体事件类型的Handler线程池（针对读写就绪事件）

3.业务线程池。

```
/**
 * @Author: Zhuang HaoTang
 * @Date: 2019-10-28 17:00
 * @Description:
 */
public class MainSubReactorMultiThreadServer {

    private ThreadPoolExecutor eventHandlerPool = new ThreadPoolExecutor(10, 50, 2, TimeUnit.MINUTES, new ArrayBlockingQueue<Runnable>(200), new ThreadPoolExecutor.CallerRunsPolicy());

    private void start() throws IOException {
        final Selector mainSelector = Selector.open();
        final Selector subSelector = Selector.open();

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    startMainSelector(mainSelector, subSelector);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }).start();

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    startSubSelector(subSelector);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }).start();

    }

    /**
     * 第一个事件分发器,用于监听ServerSocketChannel的接收就绪事件
     */
    private void startMainSelector(Selector mainSelector, final Selector subSelector) throws IOException {
        ServerSocketChannel serverSocketChannel = createNIOServerSocketChannel();
        System.out.println("start nio server and bind port 8888");
        serverSocketChannel.register(mainSelector, SelectionKey.OP_ACCEPT);
        mainSelector.select();
        for (; ; ) {
            Set<SelectionKey> selectionKeySet = mainSelector.selectedKeys();
            SelectionKey selectionKey = Iterables.getOnlyElement(selectionKeySet);
            if (selectionKey.isAcceptable()) {
                System.out.println("acceptable");
                acceptHandler(selectionKey, subSelector); // 单线程同步处理接收就绪
                selectionKeySet.clear();
            }
            mainSelector.select();
        }
    }

    /**
     * 第二个事件分发器,用于监听SockChannel的读写就绪事件
     */
    private void startSubSelector(Selector subSelector) throws IOException {
        subSelector.select();
        for (; ; ) {
            Set<SelectionKey> selectionKeySet = subSelector.selectedKeys();
            for (Iterator<SelectionKey> iterator = selectionKeySet.iterator(); iterator.hasNext(); ) {
                final SelectionKey selectionKey = iterator.next();
                if (selectionKey.isReadable()) {
                    System.out.println("readable");
                    eventHandlerPool.submit(new Runnable() {
                        @Override
                        public void run() {
                            readHandler(selectionKey);
                        }
                    });
                    iterator.remove();
                }
            }
            subSelector.select();
        }
    }

    private ServerSocketChannel createNIOServerSocketChannel() throws IOException {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.bind(new InetSocketAddress(InetAddress.getLocalHost(), 8888));
        serverSocketChannel.configureBlocking(false);
        return serverSocketChannel;
    }

    private void acceptHandler(SelectionKey selectionKey, Selector subSelector) throws IOException {
        ServerSocketChannel serverSocketChannel = (ServerSocketChannel) selectionKey.channel();
        SocketChannel socketChannel = serverSocketChannel.accept();
        if (socketChannel != null) {
            socketChannel.configureBlocking(false);
            subSelector.wakeup(); // 往Selector注册Channel时,Selector要处于非阻塞状态
            socketChannel.register(subSelector, SelectionKey.OP_READ);
            System.out.println("accept client connection " + socketChannel.getLocalAddress() + " and register to subSelector");
        }
    }

    private void readHandler(SelectionKey selectionKey) {
        SocketChannel socketChannel = (SocketChannel) selectionKey.channel();
        ByteBuffer byteBuffer = ByteBuffer.allocate(100);
        try {
            int num = socketChannel.read(byteBuffer);
            if (num == -1) {
                System.out.println("client " + socketChannel.getLocalAddress() + " disconnection");
                socketChannel.close(); // 底层有些逻辑
                return;
            }
            byteBuffer.flip();
            while (byteBuffer.hasRemaining()) {
                byte b = byteBuffer.get();
                System.out.println((char) b);
            }
        } catch (Exception e) {
            System.out.println("由于连接关闭导致并发线程读取异常");
        }
    }

    public static void main(String[] args) throws IOException {
        MainSubReactorMultiThreadServer reactorServer = new MainSubReactorMultiThreadServer();
        reactorServer.start();
    }

} 
```

**通用客户端**

```
/**
 * @Author: Zhuang HaoTang
 * @Date: 2019/10/26 16:36
 * @Description:
 */
public class Client {

    public static void main(String[] args) throws IOException, InterruptedException {
        SocketChannel socketChannel = SocketChannel.open();
        socketChannel.connect(new InetSocketAddress(InetAddress.getLocalHost(), 8888));
        String message = "today is sunday";
        ByteBuffer byteBuffer = ByteBuffer.allocate(message.getBytes().length);
        byteBuffer.put(message.getBytes());
        byteBuffer.flip();
        socketChannel.write(byteBuffer);
        Thread.sleep(5000);
        ByteBuffer byteBuffer1 = ByteBuffer.allocate("wo".getBytes().length).put("wo".getBytes());
        byteBuffer1.flip();
        socketChannel.write(byteBuffer1);

        ByteBuffer receiveBuffer = ByteBuffer.allocate(1024);
        while (true) {
            socketChannel.read(receiveBuffer);
            receiveBuffer.flip();
            while (receiveBuffer.hasRemaining()) {
                System.out.println((char)receiveBuffer.get());
            }
            receiveBuffer.clear();
        }
    }

} 
```

*主线程不需要等待具体事件类型的Handler处理完毕，直接异步返回，那么将会导致事件重复就绪，程序做出相应的控制即可。

*当channel有数据可读时，将会触发读就绪，那么主线程将会不停的向线程池提交任务，直到某个线程读取完毕，此时将会停止读就绪，其他线程读取到的个数为0。

*当客户端断开连接时，将会触发读就绪，那么主线程将会不停的向线程池提交任务，直到某个线程关闭连接，此时将会停止读就绪

**一般不会直接去使用JAVA NIO，只是通过JAVA NIO学习他的设计思想，如果要想搭建NIO服务器那么应该使用Netty等NIO框架。**

* * *

## 关于BIO和NIO的选择

BIO即同步并阻塞，线程会进入阻塞状态，如果并发连接数只有几百，那么创建几百个线程去处理是没有任何问题的，这种方式更加简单高效。

但是如果并发连接数达到几万，那么显然创建几万个线程去处理是不可行的，系统承受不了这个负荷，此时应该使用NIO，即同步非阻塞，利用更少的线程去做更多的事情。

JAVA NIO就是使用NIO（同步非阻塞），使用IO多路复用的Select模型。

![](../_resources/a99081e86d614cf89a11e74f42ec9679.png)

*不管客户端有多少个并发连接和请求，服务端总是可以利用更少的线程去处理（单线程事件分发器 和 具体事件类型的Handler线程池）