经过一系列的学习理解，我们现在对于Netty的API对象使用已经有一个大概的认知了，下面我们来详细学习下其中一些关键对象。

### 1.数据载体ByteBuf

首先，ByteBuf对象是一个字节容器，用来存储各种数据对象，和java内置的字节对象ByteBuffer类似，有多个指针索引对象，具体的内容结构如下图所示：

![image-20211219144912969](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112191449235.png)

可以简单认为ByteBuf对象内部是一个字节数组，这个数组分为两个部分，前一部分存储了一些内置字节数据，和业务没有关系，也就是上图的废弃字节部分。然后，紧接着的是一部分可用的空间，这一部分可以用来写入数据，在没有写入数据前，有两个指针索引会指向可用部分的第一个字节位置，一个是写指针(writeIndex)，会随着不停的写入字节向前移动；另一个是读指针(readIndex)，这两个索引可以通过`readerIndex() 和writeIndex()` 方法获取到，也可以通过`readerIndex(int) 和writeIndex(int)`来设置两个指针的索引位置。

关于ByteBuf对象的容量，初次创建后会有一个默认容量值，这个大小一般是2^N，通过方法**capacity()**可以获取到这个容量值，也就是上图中的废弃字节+已写字节+未写字节三个部分组成。其中通过`readableBytes()`可以获取已写字节数，也就是writeIndex - readIndex，通过`isReadable()`可以知道是否可以进行读取，当writeIndex == readIndex时返回false。同理，与读对应的还有**writableBytes()** 可以获取未写字节部分的长度，也就是capacity - writeIndex ，当两者相同时**isWritable()**返回false。

当写入数据达到capacity上限时，会触发对象的扩容，而扩容的上限可通过`maxCapacity()`获取到，也可以通过`maxWritableBytes()`获取到当前ByteBuf对象的最大写入容量,也就是maxCapacity - writeIndex 。

---------

除了容量相关的API，还有一些其他常用方法常用，如，读索引的重置方法对：

```
markReaderIndex() 与 resetReaderIndex()
```

用法就是，通过`markReaderIndex()`标记当前读索引的位置，而读取数据之后，如果想再重新读取一遍当前数据，需要手动把读索引重置到最开始的位置，就可以通过`resetReaderIndex()`把读索引设置到原理标记的位置；与之对应的写方法也有对应API：

```
markWriterIndex() 与 resetWriterIndex()
```

本质上，关于 ByteBuf 的读写都可以看作从指针开始的地方开始读写数据

```
writeBytes(byte[] src) 与 buffer.readBytes(byte[] dst)
```

writeBytes() 表示把字节数组 src 里面的数据全部写到 ByteBuf，而 readBytes() 指的是把 ByteBuf 里面的数据全部读取到 dst，这里 dst 字节数组的大小通常等于 readableBytes()，而 src 字节数组大小的长度通常小于等于 writableBytes()

```
writeByte(byte b) 与 buffer.readByte()
```

writeByte() 表示往 ByteBuf 中写一个字节，而 buffer.readByte() 表示从 ByteBuf 中读取一个字节，类似的 API 还有 

```java
writeBoolean()、writeChar()、writeShort()、writeInt()、writeLong()、writeFloat()、writeDouble() 与 readBoolean()、readChar()、readShort()、readInt()、readLong()、readFloat()、readDouble() 
```

这里就不一一赘述了，相信读者应该很容易理解这些 API。

----------

还有一点要注意，就是ByteBuf对象在创建后，需要手动释放，不然会容易造成内存泄露。关于这一点我们来进行仔细学习下：

```
refCnt()、release() 与 retain()
```

netty会使用引用计数法来判断ByteBuf对象的存活状态，在创建一个ByteBuf对象对象后，我们可以使用refCnt()获取到当前对象的引用计数值，值是1，,在后续的使用过程中如果被其他地方引用了则需要使用retain()方法让引用计数+1，在使用完后需要手动使用release()将引用计数-1，当引用计数为0时，会回收当前ByteBuf对象。

在Netty中对于内存管理是有一个内存池的概念的，也就是创建一个ByteBuf对象，可能是从内存池获取的复用对象，也可能是直接在堆外内存中创建的。而主流的ByteBuf对象有四种：

- UnpooledHeapByteBuf ，该对象可以依赖于JVM的GC进行对象回收
- UnpooledDirectByteBuf，该对象会使用堆外内存创建对象，底层是DirectByteBuffer，所以也依赖于JVM的GC回收
- PooledHeapByteBuf 和PooledDirectByteBuf，这俩个对象是netty的内存池中复用对象，需要我们手动对内存回收管理

### 2.ChannelHandler的生命周期

我们通过`ch.pipeline().addLast()`将ChannelHandler加入到请求处理链中，如果是接收数据请求，则ChannelHandler的回调方法执行顺序如下：

```
handlerAdded() -> channelRegistered() -> channelActive() -> channelRead() -> channelReadComplete()
```

- handlerAdded()是将当前ChannelHandler成功加入到请求处理链中后进行回调
- channelRegistered()是将ChannelHandler和netty线程池线程进行绑定后进行回调
- channelActive()是当前请求处理链中的全部ChannelHandler都注册完成后，完成TCP连接后，才会触发当前方法的回调
- channelRead()是接收到请求数据后，会回调此方法进行处理
- channelReadComplete()是接收到请求数据处理完成后，回调该方法，可以作为批量数据发送ctx.channel().flush()

如果客户端关闭时，会触发如下关闭方法：

```
channelInactive() -> channelUnregistered() -> handlerRemoved()
```

- channelInactive()表面这条TCP 连接已经被关闭了，会触发此方法
- channelUnregistered()表示当前ChannelHandler已经和NIO 线程接触绑定关系后触发回调
- handlerRemoved()表示将当前请求处理链中的所有ChannelHandler移除后触发回调

### 3.对于ChannelHandler的优化

1.使用单例模式共享ChannelHandler，对于一些没有成员变量(无状态)的ChannelHandler而言是可以创建单例模式，让多个线程共享同一个实例，这样可以节省对象创建的时间。共享的ChannelHandler实例需要使用@Sharable进行标注，另外要注意一些ChannelHandler是无法共享的，比如处理拆包的LengthFieldBasedFrameDecoder对象。

2.对于并联的业务处理ChannelHandler，可以使用工厂模式选择不同的Handler来处理不同的业务：

```java
@ChannelHandler.Sharable
public class IMHandler extends SimpleChannelInboundHandler<Packet> {
    public static final IMHandler INSTANCE = new IMHandler();

    private Map<Byte, SimpleChannelInboundHandler<? extends Packet>> handlerMap;

    private IMHandler() {
        handlerMap = new HashMap<>();

        handlerMap.put(MESSAGE_REQUEST, MessageRequestHandler.INSTANCE);
        handlerMap.put(CREATE_GROUP_REQUEST, CreateGroupRequestHandler.INSTANCE);
        handlerMap.put(JOIN_GROUP_REQUEST, JoinGroupRequestHandler.INSTANCE);
        handlerMap.put(QUIT_GROUP_REQUEST, QuitGroupRequestHandler.INSTANCE);
        handlerMap.put(LIST_GROUP_MEMBERS_REQUEST, ListGroupMembersRequestHandler.INSTANCE);
        handlerMap.put(GROUP_MESSAGE_REQUEST, GroupMessageRequestHandler.INSTANCE);
        handlerMap.put(LOGOUT_REQUEST, LogoutRequestHandler.INSTANCE);
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, Packet packet) throws Exception {
        handlerMap.get(packet.getCommand()).channelRead(ctx, packet);
    }
}
```

3.合并编码解码对象，使用ByteToMessageCodec或MessageToMessageCodec来实现编码与解码工作：

```java
public class PacketCodecHander extends ByteToMessageCodec<Packet> {

    public static final PacketCodecHander INSTANCE = new PacketCodecHander();

    @Override
    protected void encode(ChannelHandlerContext channelHandlerContext, Packet packet, ByteBuf byteBuf) throws Exception {
        //把 packet对象序列化，写入到byteBuf中，等待流转发送，本质是一个ChannelOutboundHandlerAdapter
        PacketCode.encode(byteBuf, packet);
        System.out.println("已完成packet对象序列化");
    }

    @Override
    protected void decode(ChannelHandlerContext channelHandlerContext, ByteBuf byteBuf, List<Object> list) throws Exception {
        list.add(PacketCode.decode(byteBuf));
        System.out.println("已完成packet对象反序列化");
    }
}
```

4.合理配置请求链中ChannelHandler的顺序，优先使用ctx.writeAndFlush()代替ctx.channel().writeAndFlush()。

5.对于一些计算时间比较长的channelRead()任务，可以在其中引入线程池来进行异步处理。



### 4.心跳与空闲检测

由于服务器资源是有限的，如果一些客户端假死了还占用着连接会空耗资源，所以需要对各种连接进行空闲检查，发现假死的连接后就直接干掉连接就行。

在netty中我们可以使用使用IdleStateHandler来实现空闲检查的功能，下面是代码示例：

```java
public class IMIdleStateHandler extends IdleStateHandler {

    private static final int READER_IDLE_TIME = 15;

    public IMIdleStateHandler() {
        super(READER_IDLE_TIME, 0, 0, TimeUnit.SECONDS);
    }

    @Override
    protected void channelIdle(ChannelHandlerContext ctx, IdleStateEvent evt) {
        System.out.println(READER_IDLE_TIME + "秒内未读到数据，关闭连接");
        ctx.channel().close();
    }
}
```

IdleStateHandler的构造方法有四个参数，第一个表示读空闲时间，指的是在这段时间内如果没有数据读到，就表示连接假死；第二个是写空闲时间，指的是在这段时间如果没有写数据，就表示连接假死；第三个参数是读写空闲时间，表示在这段时间内如果没有产生数据读或者写，就表示连接假死。写空闲和读写空闲为0，表示我们不关心者两类条件；最后一个参数表示时间单位。

如果任何一个空闲检查达到条件就会触发channelIdle()方法的执行，这里我们可以关掉假死的连接。此外，这对象应该放在pipeline请求链中的最前面，这样接收到数据就可以第一时间判断。

-------

然后是心跳检测，我们需要在客户端中使用线程池定期的发送数据到服务器端，这样就可以让服务器知道哪些连接是存活的。

```java
public class HeartBeatTimerHandler extends ChannelInboundHandlerAdapter {

    private static final int HEARTBEAT_INTERVAL = 5;

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        scheduleSendHeartBeat(ctx);

        super.channelActive(ctx);
    }

    private void scheduleSendHeartBeat(ChannelHandlerContext ctx) {
        ctx.executor().schedule(() -> {

            if (ctx.channel().isActive()) {
                ctx.writeAndFlush(new HeartBeatRequestPacket());
                scheduleSendHeartBeat(ctx);
            }

        }, HEARTBEAT_INTERVAL, TimeUnit.SECONDS);
    }
}
```

`ctx.executor()` 返回的是当前的 channel 绑定的 NIO 线程，不理解没关系，只要记住就行，然后，NIO 线程有一个方法，`schedule()`，类似 jdk 的延时任务机制，可以隔一段时间之后执行一个任务，而我们这边是实现了每隔 5 秒，向服务端发送一个心跳数据包，这个时间段通常要比服务端的空闲检测时间的一半要短一些，我们这里直接定义为空闲检测时间的三分之一，主要是为了排除公网偶发的秒级抖动。

实际在生产环境中，我们的发送心跳间隔时间和空闲检测时间可以略长一些，可以设置为几分钟级别，具体应用可以具体对待，没有强制的规定。
