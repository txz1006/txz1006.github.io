#### 1.JDK动态代理的class代码

中间增强类：

```java
public class JdkProxy implements InvocationHandler {
    // 代理中的目标对象
    private Object target;

    public JdkProxy(Object target) {
        this.target = target;
    }

    /**
     *
     * @param proxy 代理目标对象的代理对象，它是真实的代理对象。
     * @param method 方法执行目标类的方法
     * @param args 执行目标类的方法的args参数
     * @return
     * @throws Throwable
     */
    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("jdk agent before invocation");　　// 执行切入的逻辑
        Object result = method.invoke(target, args);　　// 执行原有的逻辑
        System.out.println("jdk agent after invocation");
        return result;
    }
    
    public static Object getProxyObj(Object obj){
        return Proxy.newProxyInstance(obj.getClass().getClassLoader(), obj.getClass().getInterfaces(), new JdkProxy(obj));
    }
}
```

调用实例：

```java
public class JdkTest {
    public static void main(String[] args) {
         //开启生成$Proxy0的class文件 
         //System.getProperties().put("sun.misc.ProxyGenerator.saveGeneratedFiles", "true");
        JdkStudent student = new JdkStudent();
        //JdkProxy代理类实现了InvocationHandler接口
        Person p = (Person) Proxy.newProxyInstance(student.getClass().getClassLoader(),
                student.getClass().getInterfaces(), new JdkProxy(student));
        System.out.println(p);
        p.say();
    }
}
//jdk动态代理会动态生成一个继承了Proxy类并实现了被代理目标接口的中间类，中间类通过反射调用目标方法
```

注：JDK动态代理生成的文件默认在sun/proxy下，如果没有该目录会报Exception in thread “main” java.lang.InternalError: I/O exception saving generated file: java.io.FileNotFoundException: sun\proxy$Proxy0.class (系统找不到指定的路径。)

中间增强对象是JdkProxy类，实现了InvocationHandler接口

```java
public interface InvocationHandler {
	//proxy参数是动态生成的代理对象，method是执行目标方法对象，args是执行目标方法参数列表
    public Object invoke(Object proxy, Method method, Object[] args)
        throws Throwable;
}
```



#### 2.cglib动态代理的class代码

```java
public class CglibProxyTest {

    public static void main(String[] args) throws NoSuchFieldException, SecurityException, IllegalArgumentException, IllegalAccessException {
        // 生成class类的路径
        //System.setProperty(DebuggingClassWriter.DEBUG_LOCATION_PROPERTY, "E://tmp");   
        Enhancer enhancer = new Enhancer();
        enhancer.setSuperclass(Student.class);
        enhancer.setCallback(new CglibProxy());
		
        Student student = (Student) enhancer.create();
        student.say();
    }
}
//cglib会动态生成一个继承了被代理目标的子类中间对象，并通过实现了MethodInterceptor的拦截器，来实现动态代理
```

其中的拦截器是实现类MethodInterceptor的CglibProxy类

```java
public interface MethodInterceptor extends Callback {
	//subObj参数是生成的继承了目标的子类对象，method是要执行的目标method对象
    //args是目标方法参数列表，proxy是目标method的代理对象
    //一般通过proxy.invokeSuper(subObj, args)来通过fastClass机制调用目标方法
    Object intercept(Object subObj, Method method, Object[] args, MethodProxy proxy) throws Throwable;
}
```



#### 3.Javassist生成的class代码

Javassist是一个可以直接在内存中编辑java字节码的工具包，我们通常可以用它来修改或者生成class对象，具体的使用可以参考https://www.cnblogs.com/rickiyang/p/11336268.html

通常而言，我们在编辑class文件时会创建一个CtClass对象，这个对象可以直接将class输出成具体的文件:

```java
ClassPool pool = ClassPool.getDefault();       
// 1. 创建一个空类
CtClass cc = pool.makeClass("com.rickiyang.learn.javassist.Person");
//2. 修改已经存在的类
//CtClass cc = pool.get("com.rickiyang.learn.javassist.PersonService");

//一系列修改...

//获取修改后的class
Class clazz = cc.toClass()

//这里会将这个创建的类对象编译为.class文件
cc.writeFile("D:\\mnt");
```

#### 4.使用HSDB工具

HSDB是jdk提供的一个可以动态查看class对象的GUI工具，我们可以通过下面的命令打开这个工具：

```
java -cp %JAVA_HOME%/lib/sa-jdi.jar sun.jvm.hotspot.HSDB
```

打开后我们可以通过下面的步骤来监控我们的java进程， 可以看到下面可以读取到具体的class列表信息。

![image-20211029101756319](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110291018104.png)

注意：在HSDB查看class信息时，java进程是会被暂停的，如果想要继续运行，可以在HSDB中的菜单栏选择File--->Detach关闭进程检查即可。



**动态代理的本质是通过代理中间对象实现对调用的目标方法的业务能力增强(AOP)，或者屏蔽目标对象的底层实现。比如before、after之类的业务点，另外也可以不调用目标方法(method.invoke)；使用另类扩展点来获取数据，比如mybaits使用动态代理来包装Mapper接口实现对象，在InvocationHandler接口实现类中实际操作的是jdbc对象获取数据库数据；还比如rpc调用可以使用动态代理屏蔽底层的netty网络通信**

下面是一个rpc代理对象实例：

```java
public class RPCClient<T> {
    public static <T> T getRemoteProxyObj(final Class<?> serviceInterface, final InetSocketAddress addr) {
        // 1.将本地的接口调用转换成JDK的动态代理，在动态代理中实现接口的远程调用
        return (T) Proxy.newProxyInstance(serviceInterface.getClassLoader(), new Class<?>[]{serviceInterface},
                new InvocationHandler() {
                    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                        Socket socket = null;
                        ObjectOutputStream output = null;
                        ObjectInputStream input = null;
                        try {
                            // 2.创建Socket客户端，根据指定地址连接远程服务提供者
                            socket = new Socket();
                            socket.connect(addr);
 
                            // 3.将远程服务调用所需的接口类、方法名、参数列表等编码后发送给服务提供者
                            output = new ObjectOutputStream(socket.getOutputStream());
                            output.writeUTF(serviceInterface.getName());
                            output.writeUTF(method.getName());
                            output.writeObject(method.getParameterTypes());
                            output.writeObject(args);
 
                            // 4.同步阻塞等待服务器返回应答，获取应答后返回
                            input = new ObjectInputStream(socket.getInputStream());
                            return input.readObject();
                        } finally {
                            if (socket != null) socket.close();
                            if (output != null) output.close();
                            if (input != null) input.close();
                        }
                    }
                });
    }
}

public class RPCTest {
 
    public static void main(String[] args) throws IOException {
        new Thread(new Runnable() {
            public void run() {
                try {
                    Server serviceServer = new ServiceCenter(8088);
                    serviceServer.register(HelloService.class, HelloServiceImpl.class);
                    serviceServer.start();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }).start();
        //创建代理对象
        HelloService service = RPCClient.getRemoteProxyObj(HelloService.class, 
                                                           new InetSocketAddress("localhost", 8088));
        //调用方法时触发InvocationHandler.invoke方法完成远程方法访问
        System.out.println(service.sayHi("test"));
    }
}
```

