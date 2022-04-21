

### 1.什么是Netty

netty是一个用Java语言编写的网络编程工具包，我们可以用Netty构建自己项目的网络传输规则，例如自定义通讯协议、自定义数据包的拆包规则，自定义不同请求的处理方式等等。总之，我们可以用Netty在项目和网络之间搭建一个数据传输通道，让不同的项目之间完成数据交互，现在的很多中间件如Dubbo、RocketMQ等中间件的底层的网络通信都是用netty完成的。

### 2.通过实例认识Netty

下面先来了解一个Netty简单实例，主要逻辑是，客户端连接服务端后发送一条信息，服务端收到数据后给客户端返回一条信息。

首先是服务端：

```java
public static void main(String[] args) {
    //创建两个事件循环
    NioEventLoopGroup bossGroup = new NioEventLoopGroup();
    NioEventLoopGroup workerGroup = new NioEventLoopGroup();

    //服务主体
    ServerBootstrap serverBootstrap = new ServerBootstrap();
    //设置线程模型：主从异步
    serverBootstrap.group(workerGroup, workerGroup)
            //设置IO模型(NIO)
            .channel(NioServerSocketChannel.class)
            //设置每个连接的读写等事件的处理对象
            .childHandler(new ChannelInitializer<NioSocketChannel>() {
                @Override
                protected void initChannel(NioSocketChannel channel) throws Exception {
                    //在收到或发送数据时，会依次执行pipeline链的处理对象
                    channel.pipeline().addLast(new FirstServerHandler());
                }
            });
    //设置绑定端口
    serverBootstrap.bind(8000);
    System.out.println("服务启动成功");
}
```

服务端的主体对象是ServerBootstrap，使用group方法绑定两个NioEventLoopGroup事件循环对象，走主从线程模型。然后通过channel方法指定IO模式是NIO的方式，最后设置了一个childHandler方法，这个方法是给每个TCP连接设置请求的处理pipeline链(处理发送/接收数据)。

下面是FirstServerHandler类，用来接收客户端发送的请求。

```java
//ChannelInboundHandlerAdapter的channelRead方法来接收客户端请求
public class FirstServerHandler extends ChannelInboundHandlerAdapter {

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        //接收数据
        ByteBuf byteBuf = (ByteBuf) msg;
        System.out.println("服务器收到请求数据"+ byteBuf.toString(Charset.defaultCharset()));

        //回复数据
        String msg1 = "我是服务器管理员，我现在收到你的数据了，欢迎使用！";
        ByteBuf byteBuf1 = ctx.alloc().buffer();
        byteBuf1.writeBytes(msg1.getBytes());
        //发送数据
        ctx.channel().writeAndFlush(byteBuf1);
    }
}
```

然后是客户端：

```java
public static void main(String[] args) {
    NioEventLoopGroup workerGroup = new NioEventLoopGroup();

    Bootstrap bootstrap = new Bootstrap();
    //设置线程模型
    bootstrap.group(workerGroup)
            //设置IO模型
            .channel(NioSocketChannel.class)
            //给客户端连接设置处理器
            .handler(new ChannelInitializer<SocketChannel>() {
                @Override
                protected void initChannel(SocketChannel socketChannel) throws Exception {
                    socketChannel.pipeline().addLast(new FirstClientHander());
                }
            });

    //连接服务器,并设置监听
    bootstrap.connect("127.0.0.1", 8000).addListener(future -> {
        //监听是否创建连接成功
        if (future.isSuccess()) {
            System.out.println("连接成功!");
        } else {
            System.err.println("连接失败!");
        }
    });
}
```

客户端的连接主体对象是Bootstrap，同样需要绑定一个事件循环NioEventLoopGroup，以及指定IO模型为NIO，同时也要设置一个pipeline处理链。

这里对应的FirstClientHander请求处理类如下：

```java
public class FirstClientHander extends ChannelInboundHandlerAdapter {

    /**
     * 客户端连接成功时触发
     * @param ctx
     * @throws Exception
     */
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        String msg = "我是用户张三，我现在要请求你的数据！";
        ByteBuf byteBuf = ctx.alloc().buffer();
        byteBuf.writeBytes(msg.getBytes());
        ctx.channel().writeAndFlush(byteBuf);
    }

    /**
     * 收到服务端返回数据时触发
     * @param ctx
     * @param msg
     * @throws Exception
     */
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        ByteBuf byteBuf = (ByteBuf) msg;
        System.out.println("客户端收到返回数据"+ byteBuf.toString(Charset.defaultCharset()));
    }
}
```

那么当bootstrap.connect()和服务端完成TCP连接时会触发socketChannel.pipeline()链中第一个ChannelInboundHandlerAdapter.channelActive()方法，当然也可以使用ctx.fireChannelActive()触发下一个pipeline()链ChannelInboundHandlerAdapter.channelActive()的元素。

在FirstClientHander.channelActive()方法中，我们定义了一个字符串，并转成字节ByteBuf对象后，使用ctx.channel().writeAndFlush(byteBuf)将信息发送给服务端。

而服务器端也会使用pipeline()链中的ChannelInboundHandlerAdapter对象，从上到下依次执行每个ChannelInboundHandlerAdapter对象的channelRead()方法。这里在FirstServerHandler.channelRead()中，将客户端发送的数据从字节ByteBuf对象转成字符串后打印出来，然后也使用ctx.channel().writeAndFlush(byteBuf)将回复信息发回给客户端。

而客户端在FirstClientHander.channelRead()中进行了进行字符串转换打印。

整个流程图如下：

![image-20211216162501031](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112161625295.png)

### 3.连接中的pipeline双链表

在上述事例汇总我们知道了处理每个连接的对象是pipeline双链表中的ChannelHandler对象，而这些ChannelHandler对象是作为一个个元素放在pipeline双链表中的，通过代码`socketChannel.pipeline().addLast(new FirstClientHander())`可以把新的ChannelHandler对象加入到pipeline链表中。

而ChannelHandler对象分为`ChannelInboundHandler`和`ChannelOutboundHandler`两种，通过名称我们可以知道前者是管理数据读取的，后者是管理数据输出的。在上面的实例中，不管是FirstClientHander或是FirstServerHandler他们都是ChannelInboundHandler子类实现对象，可以通过channelRead()方法接收对方用ctx.channel().writeAndFlush(byteBuf)发送的数据。

如果对一个连接设置多个pipeline元素，如：

```java
//接收信息时从上到下，依次执行元素
//下面是ChannelInboundHandler对象
socketChannel.pipeline().addLast(new StringDecoder());
socketChannel.pipeline().addLast(new FirstClientHander());
socketChannel.pipeline().addLast(new SecondClientHander());

//发送数据时从下向上依次执行
//下面是ChannelOutboundHandler对象
socketChannel.pipeline().addLast(new StringEncoder());
socketChannel.pipeline().addLast(new FirstOutClientHander());
socketChannel.pipeline().addLast(new SecondOutClientHander());
```

如上图所示，形成的pipeline链表如下所示：

![image-20211216182037809](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112161820855.png)

现在在`FirstClientHander.channelActive()`方法中执行`ctx.channel().writeAndFlush(byteBuf)`会向服务端发送数据，但是由于当前pipeline链存在ChannelOutboundHandler对象，所以，会向右找到最后一个ChannelOutboundHandler对象即SecondOutClientHander，并执行其write方法，执行完成，会依次向左寻找下一个ChannelOutboundHandler对象执行其write方法；例如，图中最后一个ChannelOutboundHandler对象是StringEncoder，也就是最后会编码数据，然后发送出去。

但是要注意，如果执行的是`ctx.writeAndFlush(byteBuf)`，则会从当前pipeline链中的位置开始往左寻找，依次向左寻找下一个OutboundHandler对象执行其write方法；在上图中如果`FirstClientHander.channelActive()`执行了`ctx.writeAndFlush(byteBuf)`方法会直接将数据发送给服务端，因为在左边已经没有一个ChannelOutboundHandler对象了；

如果将三个ChannelOutboundHandler对象放到StringDecoder前面，如下图所示：

![image-20211217090658610](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112170926610.png)

则`ctx.writeAndFlush(byteBuf)`和`ctx.channel().writeAndFlush(byteBuf)`没有区别，都会依次执行SecondOutClientHander-->FirstOutClientHander-->StringEncoder的write方法，然后再把数据发送出去。

最后总结一下，ChannelOutboundHandler对象在pipeline链中的执行顺序是逆向的(从右向左)，也就是最后加入链表中的对象反而会优先执行；而且会自动触发每一个ChannelOutboundHandler对象的执行，但是如果是`ctx.writeAndFlush(byteBuf)`，则会在pipeline链中从当前ChannelHandler对象的位置开始往前(左)依次遍历执行每一个ChannelOutboundHandler对象。

-----------

学习了ChannelOutboundHandler对象的执行逻辑后，下面我们了解下InboundHandler对象的执行逻辑，如果客户端或服务端收到一个请求，那么就会使用ChannelInboundHandler对象来接收处理这些请求；执行的顺序和ChannelOutboundHandler恰恰相反，Netty会从左向右寻找发现的第一个ChannelInboundHandler对象，然后执行他的channelRead方法，然后就结束了；要注意，这里不会触发下一个ChannelInboundHandler对象的执行，需要我们使用ctx.fireChannelRead(obj)方法手动触发才行。

当然Netty也贴心的给我们提供了一些方便的ChannelInboundHandler对象，这些对象会自动触发下一个ChannelInboundHandler对象的执行，如SimpleChannelInboundHandler：

```java
public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
    boolean release = true;
    try {
        //判断是否应该执行当前ChannelHandlerContext对象
        if (this.acceptInboundMessage(msg)) {
            //是，则执行子类读取方法
            this.channelRead0(ctx, msg);
        } else {
            //否，则触发下一个ChannelInboundHandler对象执行
            release = false;
            ctx.fireChannelRead(msg);
        }
    } finally {
        if (this.autoRelease && release) {
            ReferenceCountUtil.release(msg);
        }
    }
}
protected abstract void channelRead0(ChannelHandlerContext var1, I var2) throws Exception;
```

在了解了pipeline链中的ChannelOutboundHandler对象和ChannelInboundHandler对象后，下面我们来学习下两种对象的实际使用。

