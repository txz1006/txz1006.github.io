本节我们来学习ChannelOutboundHandler对象和ChannelInboundHandler对象具体如何使用。

### 1.编码与解码

在数据通信中，我们通常会使用一些具体的协议来保证数据传输的安全性、可读性等特性。如http、ftp、smtp协议等等，他们都是约定了一套规则来控制数据的传输格式，这样才可以通过具体的协议规则将二进制数据包转换为可读的数据。

在netty中常见的编码解码对象有很多，如上一节看到的StringEncoder和StringDecoder，这两个对象可以实现字符串和字节数组之间的互相转换；当然他们本质上也是ChannelOutboundHandler对象和ChannelInboundHandler对象的子类实现。

下面我们来使用下这两个对象，在上一节中，我们有一个实例是直接将字符串手动转成ByteBuf对象，然后接收方会将ByteBuf对象手动转为字符串打印出来，但是如果我们使用了StringEncoder和StringDecoder，那么就可以忽略中间的转换过程，直接进行字符串传输。

服务器端：

```java
public static void main(String[] args) {
    NioEventLoopGroup bossGroup = new NioEventLoopGroup();
    NioEventLoopGroup workerGroup = new NioEventLoopGroup();

    ServerBootstrap serverBootstrap = new ServerBootstrap();
    serverBootstrap.group(workerGroup, workerGroup)
            .channel(NioServerSocketChannel.class)
            .childHandler(new ChannelInitializer<NioSocketChannel>() {
                @Override
                protected void initChannel(NioSocketChannel channel) throws Exception {
                    //增加编码解码对象
                    socketChannel.pipeline().addLast(new StringEncoder());
                    socketChannel.pipeline().addLast(new StringDecoder());
                    
                    channel.pipeline().addLast(new FirstServerHandler());
                }
            });
    serverBootstrap.bind(8000);
    System.out.println("服务启动成功");
}
```

在FirstServerHandler处理对象中直接使用字符串传输：

```java
public class FirstServerHandler extends ChannelInboundHandlerAdapter {

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        //接收数据
        System.out.println("服务器收到请求数据"+ msg);
        //回复数据
        String msg1 = "我是服务器管理员，我现在收到你的数据了，欢迎使用！";
        ctx.channel().writeAndFlush(msg1);
    }
}
```

客户端：

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
                    //增加编码解码对象
                    socketChannel.pipeline().addLast(new StringEncoder());
                    socketChannel.pipeline().addLast(new StringDecoder());
                    
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

在FirstClientHander处理对象中直接使用字符串传输：

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
        ctx.channel().writeAndFlush(msg);
    }

    /**
     * 收到服务端返回数据时触发
     * @param ctx
     * @param msg
     * @throws Exception
     */
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        System.out.println("客户端收到返回数据："+ msg);
    }
}
```

整个流转图如下所示：

![image-20211217145144463](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112171451162.png)

### 2.自定义通讯协议

在上一节中中使用到了StringEncoder和StringDecoder作为编码解码对象，以StringEncoder为例，我们来看看他是怎么实现的：

```java
@Sharable
public class StringEncoder extends MessageToMessageEncoder<CharSequence> {
    private final Charset charset;

    public StringEncoder() {
        this(Charset.defaultCharset());
    }
	//完成数据的转为字节数组对象
    protected void encode(ChannelHandlerContext ctx, CharSequence msg, List<Object> out) throws Exception {
        if (msg.length() != 0) {
            out.add(ByteBufUtil.encodeString(ctx.alloc(), CharBuffer.wrap(msg), this.charset));
        }
    }
}
```

而父类MessageToMessageEncoder是这样的：

```java
public abstract class MessageToMessageEncoder<I> extends ChannelOutboundHandlerAdapter {

    public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
        CodecOutputList out = null;
        boolean var29 = false;

        try {
            var29 = true;
            //判断收到的数据是否属于泛型I类型
            if (this.acceptOutboundMessage(msg)) {
                out = CodecOutputList.newInstance();
                Object cast = msg;

                try {
                    //抽象方法，在子类实现
                    this.encode(ctx, cast, out);
                } finally {
                    ReferenceCountUtil.release(msg);
                }
			   //.......  
            } else {
                //发送数据
                ctx.write(msg, promise);
                var29 = false;
            }
            
        } 
        //.......  发送数据
        ctx.write(out.getUnsafe(0), promise);    
    }
    //.......  
}
```

总的来说，StringEncoder是一个ChannelOutboundHandlerAdapter对象，如果收到String类型的数据，则会执行encode将字符串转为字节数组，然后发送出去。同理StringDecoder也是类似的对象，不过是ChannelInboundHandlerAdapter对象，大家自行了解。

这里要注意一下这个父类对象MessageToMessageEncoder，简单来说就是将一个信息主体转为字节数组，同样还有一个MessageToMessageDecoder对象，会将字节数组转为信息主体；我们可以自行继承这两个对象，完成自定义的数据载体和字节数组的互相转换。

下面我们来自定义一种数据通信协议来完成数据通信。

一般而言，一种通信协议由下面几个部分组成，如下图所示：

![image-20211217161156300](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202112171611422.png)

- **魔数**，一般是4个字节长度，一个int数值，用来标识自定义协议的唯一性。比如，服务端收到了各种各样的协议数据，那么如何判断哪些数据的协议请求是自己自定义的呢，就是通过魔数进行分辨的。
- **版本号**，1个字节长度，是一个预留字段，用来标识当前协议版本号，后期可以进行升级，并通过这个版本号来区别不同的处理方式。
- **序列化方式**，1个字节长度，是用来区别字节数组的序列化方式的，常见的序列化方式有 Java 自带的序列化，json，hessian 等等方式，通过这个字段，我们可以知道如果把数据反序列化回来。
- **处理指令**，1个字节长度，是用来说明这个数据的处理方式，或者这个数据在反序列化后要被哪些对象处理。
- **数据长度**，4个字节长度，一个int数值，用来记录存储数据的字节数组长度。
- **数据**，被某种方式序列化后产生的字节数组。

了解这些后我们就可以定制自己项目的通讯协议。

首先，我们选择一种序列化方式，具体使用fastjson的方式。然后，我们就可以形成这样一个自定义协议创建对象：

抽象一个序列化主体解：

```java
public interface Serializer {

    byte getSerializeAlgorithm();

    byte[] serialize(Object obj);

    <T> T deserialize(Class<T> clazz, byte[] bytes);

}
```

然后可以使用JSON实现一种序列化方式，也可以使用其他的方式实现序列化：

```java
public class JSONSerializer implements Serializer{

    @Override
    public byte getSerializeAlgorithm() {
        return SerializeAlgorithm.JSON;
    }

    @Override
    public byte[] serialize(Object obj) {
        return JSON.toJSONBytes(obj);
    }

    @Override
    public <T> T deserialize(Class<T> clazz, byte[] bytes) {
        return JSON.parseObject(bytes, clazz);
    }
}
```

然后使用工厂模式创建一个序列化集合，可以通过协议中的序列化1字节来执行不同序列化、反序列化方式。

```java
public interface SerializeAlgorithm{
    byte JSON = 1;

    static Serializer getRequestType(byte serializeAlgorithm) {
        if(serializeAlgorithm == 1){
            return new JSONSerializer();
        }
        return null;
    };
}
```

最后，我们来构建一个协议主体对象：

```java
public class PacketCode {

    public static int MAGIC_NUM = 0x12345678;

    private static JSONSerializer jsonSerializer = new JSONSerializer();

    public static ByteBuf encode(Packet obj){
        //将对象序列化为字节数组
        byte[] bytes = jsonSerializer.serialize(obj);
        //按照传输协议，组织传输字节对象
        ByteBuf byteBuf = ByteBufAllocator.DEFAULT.buffer();
        //设置魔数。一般用于服务器和客户端解辨别协议
        byteBuf.writeInt(MAGIC_NUM);
        //设置版本号
        byteBuf.writeByte(obj.getVersion());
        //设置序列化算法
        byteBuf.writeByte(jsonSerializer.getSerializeAlgorithm());
        //设置指令，说明如何处理数据
        byteBuf.writeByte(obj.getCommand());
        //设置数据的长度
        byteBuf.writeInt(bytes.length);
        //最后放入数据
        byteBuf.writeBytes(bytes);
        return byteBuf;
    }
    
    public static <T> T decode(ByteBuf byteBuf){
        //忽略前4个字节的魔数
        byteBuf.skipBytes(4);
        //忽略1个字节的版本号
        byteBuf.skipBytes(1);

        //读取第6个字节的序列化算法值
        byte serializeAlgorithm = byteBuf.readByte();
        Serializer serializer = SerializeAlgorithm.getRequestType(serializeAlgorithm);
        //读取第7个字节的指令
        byte command = byteBuf.readByte();
        Class<? extends Packet> clazz = Command.getRequestType(command);

        //读取第8到11的字节的数据长度
        int length = byteBuf.readInt();

        //读取出数据内容
        byte[] bytes = new byte[length];
        byteBuf.readBytes(bytes);

        //根据命令和序列化算法值获取对应的反序列化类型和对象
        return (T) serializer.deserialize(clazz, bytes);
    }
}
```

有了这样一个协议的正反转换对象后，我们就可以把这种方式加到netty中的pipeline双链表中做数据对象的编码解码了。

具体内容如下：

```java
@Sharable
public class PacketEncoder extends MessageToMessageEncoder<Packet> {
    protected void encode(ChannelHandlerContext ctx, Packet obj, List<Object> out) throws Exception {
        if (msg.length() != 0) {
            out.add(PacketCode.encode(obj));
        }
    }
}

@Sharable
public class PacketDecoder extends MessageToMessageDecoder<Packet> {
    protected void decode(ChannelHandlerContext ctx, ByteBuf msg, List<Object> out) throws Exception {
        out.add(PacketCode.decode(msg));
    }
}
```

### 3.处理拆包沾包问题

我们知道数据在传输时最小以字节为实际使用单位，如果每次请求都要读取，那么就会产生大量的IO时间，为了减少IO次数多半会使用一个缓冲池来存储多个请求的字节数据包，然后把这些数据包一次性发发送出去，一旦请求过于频繁，那么就很有可能在字节数据反序列化的过程中，读取到相邻请求包的字节数据，一旦发生这种情况，就会导致两个请求数据包均无法正常解析了，这就是沾包问题。

处理这种问题一般而言有三种方式：

一种是固定请求数据包的长度，比如每个请求长度固定为500字节，那么在解析时也会每次读取500字节进行解析。

另一种是设置分隔符号，每个数据包中在结尾放入一个分隔字符，那么在读取解析时可以按照这个分隔符进行解析。

还一种是指定数据长度，就是在数据包说明数据的具体长度，那么就可以精确解析每个包中的数据，和上面的自定义协议一样。

在Netty中，这几种处理方式都是封装好了的，我们可以直接拿来用的：

**1. 固定长度的拆包器 FixedLengthFrameDecoder**

如果你的应用层协议非常简单，每个数据包的长度都是固定的，比如 100，那么只需要把这个拆包器加到 pipeline 中，Netty 会把一个个长度为 100 的数据包 (ByteBuf) 传递到下一个 channelHandler。

**2. 行拆包器 LineBasedFrameDecoder**

从字面意思来看，发送端发送数据包的时候，每个数据包之间以换行符作为分隔，接收端通过 LineBasedFrameDecoder 将粘过的 ByteBuf 拆分成一个个完整的应用层数据包。

**3. 分隔符拆包器 DelimiterBasedFrameDecoder**

DelimiterBasedFrameDecoder 是行拆包器的通用版本，只不过我们可以自定义分隔符。

**4. 基于长度域拆包器 LengthFieldBasedFrameDecoder**

最后一种拆包器是最通用的一种拆包器，只要你的自定义协议中包含长度域字段，均可以使用这个拆包器来实现应用层拆包。由于上面三种拆包器比较简单，读者可以自行写出 demo，接下来，我们来学习一下如何使用基于长度域的拆包器来拆解我们的数据包。

LengthFieldBasedFrameDecoder构造方法有3个参数，第一个是书包的最大长度，第二个参数是协议中长度域的偏移量，第三个参数是长度域的字节数，这样就可以知道一个数据包的长度，并按照这个长度来解析数据包了。

```java
public class Spliter extends LengthFieldBasedFrameDecoder {

    public static final Spliter INSTANCE = new Spliter();

    //通讯协议包中，每个包中数据长度和内容前的偏移量(字节)
    public static final int lengthFieldOffset = 7;
    //包长度的字节数
    public static final int lengthFieldLength = 4;

    public Spliter() {
        //这样让客户端、服务器在解析收到的数据时不会出现拆包沾包等问题
        //3个参数，数据包最大长度为Integer.MAX_VALUE，前7个字节需要忽略掉，数据包的长度是4个字节
        super(Integer.MAX_VALUE, lengthFieldOffset, lengthFieldLength);
    }

    //进行通讯协议的过滤，只解析自己定义的协议，其他协议的连接直接拒绝
    //第二个参数会直接获取协议的前4个字节，也就是魔数，可以用来识别是否是自定义的协议
    @Override
    protected Object decode(ChannelHandlerContext ctx, ByteBuf in) throws Exception {
        Integer magic_num = in.getInt(in.readerIndex());
        //非本协议直接关闭
        if(!magic_num.equals(PacketCode.MAGIC_NUM)){
            ctx.channel().close();
            return null;
        }
        System.out.println("自定义协议检测通过");
        return super.decode(ctx, in);
    }

}
```

在上述方法中，需要注意到在decode方法中进行了协议的判断，在LengthFieldBasedFrameDecoder拆包对象中，第二个参数ByteBuf会读取协议的前几个字节，也就是我们可以直接读取前4个字节为一个int魔数，并通过魔数来判断这个协议可否进行解析，不能解析的直接关掉连接。

