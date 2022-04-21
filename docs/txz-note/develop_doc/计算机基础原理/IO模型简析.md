IO模型简析

#### 进程资源调度关系

1.操作系统为了限制外部软件无限制的使用系统资源，从而导致系统崩溃；故将软件的进程分为两类：

- 内核态：该状态的进程异步都属于操作系统本身，可以无限制的使用cpu指令，全部内存，访问权限等资源(如文件系统进程、调度系统进程、软中断进程等)
- 用户态：该状态下的进程一般会被限制使用系统各种资源(cpu指令、内存等)

![image-20210728100009658](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728100358.png)

如果需要使用这些资源的话，就需要将用户态陷入到内核态中(系统调用)，即向内核态发起资源申请，从而才能进一步的获取调度资源的权限

![image-20210728100353008](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728100353.png)


知识扩展：
零拷贝技术就是用户态进程直接将磁盘、网络的数据加载到用户态缓冲区的技术，不需要经过CPU将数据从内核态缓冲区写入用户态缓冲区的过程。

常见的零拷贝技术有mmap(即用户态、内核态空间共享)、sendfile函数等


#### IO通信模型

在很早的IO通信模型中，一台机器向另一台机器发送请求时，一般会通过网卡接受，然后在内核态的文件列表中维护一个socket连接，等待数据的传输完成。

当通信完成后会将完整的请求写入到一个接受队列中，用户态的进程获取这个请求就需要通过socket编号来进行系统方法调用(recvfrom())来陷入内核态中，访问接受队列读取完整请求。

![image-20210728102612647](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728102612.png)

如果访问接受队列时网络传输未完成，那么就读不到请求，此时进程调度就会让该线程阻塞挂起，让出CPU执行权。等到传输完成后，才会由软中断唤醒线程到接受队列读取完整请求。

![image-20210728104504018](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728104504.png)

上述通信方式一般只能单条单条的处理TCP连接，而且因为会阻塞线程，效率会很低。后来，经过一次优化，将阻塞连接改为了非阻塞。

即在内核态中通过对所有socket连接的接受队列进行无线循环读取，直到读取某个socket将请求写入接受队列时，会及那个这个请求返回给用户态进程。

![image-20210728105635167](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728105635.png)

#### IO多路复用模型

在经过多次优化后，产生一个epoll对象模型来处理多个IO请求。简单的说就是epoll对象中维护了一个select对象，一个就绪列表，以及一个红黑树结构的socket列表。

如果有新的socket连接创建，那么就会挂到红黑树中，select对象会对所有的socket进行监控，发现某个socket传输完成后，会将这个socket请求标记到就绪队列中，用户态进程只需要到内核态中访问这个就绪队列就了。整个过程就相当于有一个一个快递中转站会帮你监控所有快递的动态，当有快递到了，就会帮你放到待取点，你只需要经常去待取点看看就行了。

需要注意的是，如果就绪队列是空的，没有请求来，那么用户态线程在内核态读取这个就绪队列还是会被阻塞挂起。

![image-20210728111324432](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210728111324.png)

java中nio的实现：

步骤1：客户端创建SocketChannel对象，指定好服务器IP端口，将数据写入到通道对象中
`        SocketChannel socketChannel = SocketChannel.open();
        socketChannel.connect(new InetSocketAddress(InetAddress.getLocalHost(),8888));

        String message = "today is sunday";
        ByteBuffer byteBuffer = ByteBuffer.allocate(message.getBytes().length);
        byteBuffer.put(message.getBytes());
        byteBuffer.flip();
        socketChannel.write(byteBuffer);
        Thread.sleep(5000);`

步骤2：服务端创建ServerSocketChannel对象，设置好监听端口，等待客户端的连接

```java
ServerSocketChannel serverSocketChannel = createNIOServerSocketChannel();
System.out.println("start nio server and bind port 8888");
serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
```

​		
步骤3：创建选择器Selector对象，与ServerSocketChannel对象绑定，即让Selector管理所有的Channel连接行为

```java
serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
```

步骤4：Selector对象会不停的遍历所有的Channel，当有连接就绪后，就会创建一个SelectorKey对象，这个对包含有Selector对象和已经就绪的ServerSocketChannel对象；此时，我们就可以通过ServerSocketChannel获取客户端发送的数据了。

```java
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
```

步骤5：我们只需要设置一个无限循环一直通过selector.select()来检查Selector对象是否已经有已经就绪的通道对象就可以了，其中，还要注意socket连接的状态问题，根据不同的状态，做不同的逻辑。

```java
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
                    //线程池并发处理客户端请求
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
```

补充：在获取到客户端发送的请求后，我们可以用一个异步的方式来处理这些请求，比如设置一个队列，将请求封装成对象后丢入队列中，再由其他线程处理。或者直接设置一个线程池，将请求丢入其中，并发处理。