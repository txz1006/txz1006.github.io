#### 什么是字节码工具

我们都知道Java代码需要运行起来，首先要将java代码编译成class文件，然后使用jre环境命令行读取运行class文件，将之转化为内存class对象，然后寻找到程序入口main方法，一行行的执行业务代码，直到所有代码执行完成。

这个Java程序运行过程中，如果我们想动态的操作java类对象，比如new一个新实例，那么就可以用到java的动态特性【反射】，依靠静态的class对象就能动态的实现这些功能，而且可以动态的修改这些实例的存储内容。

虽然【反射】功能确实非常强大，能满足非常多的应用场景，比如动态代理，但是【反射】特性的API存在两个明显问题：

- 反射调用成本过高，也就是调用耗时较长，性能上没有任何优势
- 反射调用破坏了类型对象的安全性，如果反射特性面向用户开放相关功能（尽管并不会），那么很可能出现各种的安全校验问题

所以我们需要一种更安全、更快速的【超级反射】来解决这些问题，而真正解决这些问题的对象就是字节码技术。

字节码技术拥有能直接动态创造class文件、修改class对象的能力，直接对应代码实现的就是asm.jar相关工具包，asm包提供了一套近似操作底层指令码的API来操作class对象，所以需要使用者对于class文件构成，汇编语言相关内容比较熟悉，由于学习成本较高，所以就出现对于asmAPI进一步封装、简化使用成本的jar，常见的有两种，一种是Javassist 系列jar，另一种是ByteBuddy系列jar，这两种工具都可以非常简单的操作class对象，下面会进行相关内容的讲解。



### 一个helloworld案例：

```java
String helloWorld = new ByteBuddy()
            .subclass(Object.class)
    		.name("com.test.DEMOServer")
            .method(named("toString"))
            .intercept(FixedValue.value("Hello World!"))
            .make()
            .load(getClass().getClassLoader())
            .getLoaded()
            .newInstance()
            .toString();    

System.out.println(helloWorld);  // Hello World!

```

- new ByteBuddy()  //代表创建一个操作字节码的ByteBuddy对象
- subclass(Object.class)  //代表创建的这个对象会继承Object类
- name("com.test.DEMOServer")  //代表创建的这个新类处于com.test包下，类名为DEMOServer（如果不写，ByteBuddy会自定义类名）
- method(named("toString"))  //代表筛选出一个名称叫做toString的方法对象，用于扩展
- intercept(FixedValue.value("Hello World!"))  //代表拦截之前的method方法对象，将返回值改为【Hello World!】。思考：如果方法的返回类型是void，则这个拦截的作用是什么？答：会变成局部变量
- make()   //创建一个DynamicType.Unloaded实例，这个实例包含上述描述的新类的字节码信息
- load(getClass().getClassLoader())  //选择用什么classloader对象来加载这个新类到JVM
- getLoaded()   //使用选定的classloader对象加载这个新类到JVM中，该方法返回的是新类的class对象了
- .newInstance()   //使用反射，实例化一个新类的对象
- toString()  //调用新类的toString()方法



### 生成字节码创建新类的class文件

```java
//使用Unloaded对象的saveIn方法，将新类的class文件输出到，当前目录的ByteBuddy文件夹中
DynamicType.Unloaded.saveIn(new File("ByteBuddy"))
```

或者可以将生成的class文件注入到某个jar包中

```java
DynamicType.Unloaded.inject(new File("ByteBuddy/test.jar"))
```

### 三种字节码增加方式

-  ByteBuddy.subclass() ，对目标方式进行继承，生成一个子类，子类中进行功能增强
- ByteBuddy.redefine() ，对已有的某个类的class对象进行修改，删除，新增，如果对已存在方法进行了修改删除，则原方法逻辑就会消失（谨慎操作）
- ByteBuddy.rebasing() ，和redefine()方法类似，但是对覆盖的方法变量不会删除，而是重命名保留下来

### 常见三种类加载策略

- ClassLoadingStrategy.Default.WRAPPER，ByteBuddy默认的，也是使用最多的加载策略，创建一个新的 ClassLoader 来加载动态生成的类型
- Default.CHILD_FIRST，创建一个子类优先加载的 ClassLoader，即打破了双亲委派模型。
- Default.INJECTION，使用反射, 将动态生成的类型直接注入到当前 ClassLoader 中。

### 创建新成员变量

使用defineField方法来定义一个成员变量，字符串类型，名称是name，修饰符是public static，初始值是test

```
.defineField("name", String.class, Modifier.PUBLIC+Modifier.STATIC)
.value("test")
```



### 创建新成员方法

- defineMethod("main", String.class, Modifier.PUBLIC + Modifier.STATIC)，定义方法；名称、返回类型、属性*public static void*

- withParameter(String[].class, "args") 定义入参，类型和名称

- intercept(FixedValue.value("Hello World!"))，定义拦截返回数据们这里是简单的返回Hello World!，复制的可以定义拦截类，自行设置方法体逻辑，比如：MethodDelegation.to(TestInterceptor.class)

  

### 实现接口

```
implement(DemoInterface.class)
```

### 委托代理方法结果

```java
//代理目标方法返回Hello World!字符串
.intercept(FixedValue.value("Hello World!"))
//代理目标方法返回字符串变量name
.intercept(FieldAccessor.ofField("name"))
//代理目标方法由DelegateClazz类来处理
.intercept(MethodDelegation.to(DelegateClazz.class))    
```

委托到静态方法：

执行MethodDelegation.to(DelegateClazz.class)后，在执行新类的拦截method时，会优先匹配DelegateClazz类中和新类method方法的参数、返回类型和名称相同的方法，例如：

```java
class Source {
  public String hello(String name) { return null; }
}
 
class Target {
  public static String hello(String name) {
    return "Hello " + name + "!";
  }
}
 
String helloWorld = new ByteBuddy()
  .subclass(Source.class)
  .method(named("hello")).intercept(MethodDelegation.to(Target.class))
  .make()
  .load(getClass().getClassLoader())
  .getLoaded()
  .newInstance()
  .hello("World");
```

上述新类执行hello方法时，会代理请求到Target.hello静态方法中。

当然ByteBuddy的代理类匹配规则可以配置的非常复杂，不一定要求必须和原被代理方法完全相同，例如，当Target类的结构是这样的

```java
class Target {
  public static String intercept(String name) { return "Hello " + name + "!"; }
  public static String intercept(int i) { return Integer.toString(i); }
  public static String intercept(Object o) { return o.toString(); }
}
```

上述代理方法就会匹配上 String intercept(String name)方法，也就是说拦截对象并不一定要方法名称相同。

委托到动态方法：

```java
.intercept(MethodDelegation.to(new DelegateClazz()))    
```

### 常用注解使用

我们可以使用@SuperCall配合Callable接口获取原始被代理方法，实例：

```java
.intercept(MethodDelegation.to(MonitorDemo.class))

public class MonitorDemo {

    @RuntimeType
    public static Object intercept(@SuperCall Callable<?> callable) throws Exception {
        long start = System.currentTimeMillis();
        try {
            //调用原始方法
            return callable.call();
        } finally {
            System.out.println("方法耗时：" + (System.currentTimeMillis() - start) + "ms");
        }
    }

}
```

其中`@RuntimeType`：定义运行时的目标方法。`@SuperCall`：用于调用父类版本的方法，`callable.call();` 这个方法是调用原方法的内容，返回结果。而在调用前后，我们可以进行功能增强，这里就是简单的记录了原方法的耗时。

我们可以看下生成的新类代码：

```java
public class DemoService1 implements bsacs.web.test.ByteTest.DemoInterface {

    public DemoService1() {
    }

    public String test() {
        //调用拦截类MonitorDemo的intercept方法
        return (String)bsacs.web.test.ByteTest.MonitorDemo.intercept(new VIeaONAJ(this));
    }
}

// $FF: synthetic class
class DemoService1$auxiliary$VIeaONAJ implements Runnable, Callable {
    private DemoService1 argument0;

    public Object call() throws Exception {
        //调用被代理目标方法（方法名称由于被覆盖，所以原被代理方法被重命名）
        return this.argument0.test$original$Mj6BIDIu$accessor$p2FizIoU();
    }

    public void run() {
        this.argument0.test$original$Mj6BIDIu$accessor$p2FizIoU();
    }

    DemoService1$auxiliary$VIeaONAJ(DemoService1 var1) {
        this.argument0 = var1;
    }
}
```

获取新类被拦截目标方法Method对象，使用@Origin注解获取：

```java
@RuntimeType
public static Object intercept(@Origin Method method, @SuperCall Callable<?> callable) throws Exception {
    long start = System.currentTimeMillis();
    Object resObj = null;
    try {
        resObj = callable.call();
        return resObj;
    } finally {
        System.out.println("方法名称：" + method.getName());
        System.out.println("入参个数：" + method.getParameterCount());
        System.out.println("入参类型：" + method.getParameterTypes()[0].getTypeName() + "、" + method.getParameterTypes()[1].getTypeName());
        System.out.println("出参类型：" + method.getReturnType().getName());
        System.out.println("出参结果：" + resObj);
        System.out.println("方法耗时：" + (System.currentTimeMillis() - start) + "ms");
    }
}
```

获取入参类型，使用@AllArguments` 、`@Argument(0)获取，后者获取第一个参数类型：

```java
@RuntimeType
public static Object intercept(@Origin Method method, @AllArguments Object[] args, @Argument(0) Object arg0, @SuperCall Callable<?> callable) throws Exception {
    long start = System.currentTimeMillis();
    Object resObj = null;
    try {
        resObj = callable.call();
        return resObj;
    } finally {
        System.out.println("方法名称：" + method.getName());
        System.out.println("入参个数：" + method.getParameterCount());
        System.out.println("入参类型：" + method.getParameterTypes()[0].getTypeName() + "、" + method.getParameterTypes()[1].getTypeName());
        System.out.println("入参内容：" + arg0 + "、" + args[1]);
    }
}
```

其他常用注解：

| 注解          | 说明                                                         |
| ------------- | ------------------------------------------------------------ |
| @Argument     | 用于拦截类中的方法参数列表，绑定单个参数                     |
| @AllArguments | 绑定所有参数的数组                                           |
| @This         | 当前被拦截的、动态生成的那个对象                             |
| @Super        | 当前被拦截的、动态生成的那个对象的父类对象                   |
| @Origin       | 可以绑定到以下类型的参数：Method 被调用的原始方法 Constructor 被调用的原始构造器 Class 当前动态创建的类 MethodHandle MethodType String 动态类的toString()的返回值 int 动态方法的修饰符 |
| @DefaultCall  | 调用默认方法而非super的方法                                  |
| @SuperCall    | 用于调用父类版本的方法                                       |
| @Super        | 注入父类型对象，可以是接口，从而调用它的任何方法             |
| @RuntimeType  | 可以用在返回值、参数上，提示ByteBuddy禁用严格的类型检查      |
| @Empty        | 注入参数的类型的默认值                                       |
| @StubValue    | 注入一个存根值。对于返回引用、void的方法，注入null；对于返回原始类型的方法，注入0 |
| @FieldValue   | 注入被拦截对象的一个字段的值                                 |
| @Morph        | 类似于@SuperCall，但是允许指定调用参数                       |

参考：https://www.cnblogs.com/crazymakercircle/p/16635330.html#autoid-h3-9-0-0

https://bugstack.cn/md/bytecode/byte-buddy/2020-05-12-%E5%AD%97%E8%8A%82%E7%A0%81%E7%BC%96%E7%A8%8B%EF%BC%8CByte-buddy%E7%AF%87%E4%BA%8C%E3%80%8A%E7%9B%91%E6%8E%A7%E6%96%B9%E6%B3%95%E6%89%A7%E8%A1%8C%E8%80%97%E6%97%B6%E5%8A%A8%E6%80%81%E8%8E%B7%E5%8F%96%E5%87%BA%E5%85%A5%E5%8F%82%E7%B1%BB%E5%9E%8B%E5%92%8C%E5%80%BC%E3%80%8B.html

### JavaAgent技术

java在升到jdk1.6支持了一个代理机制功能，这个功能可以让开发者在JVM加载class文件之前修改类的字节码信息，并以此来动态修改类的方法，实现AOP功能，由于这种技术不需要直接修改代码，属于非代码侵入方式。所以常用的场景有：提供监控服务，如方法调用时长，内存等等指标。

使用方式：

java提供了两个入口方法，来拦截处理要被加载的class信息：

```java
// 用于JVM刚启动时调用，其执行时应用类文件还未加载到JVM
public static void premain(String agentArgs, Instrumentation inst);
public static void premain(String agentArgs);
// 用于JVM启动后，在运行时刻加载
public static void agentmain(String agentArgs, Instrumentation inst);
public static void agentmain(String agentArgs);
```

这两个方法作用如下：

- 加载时刻增强（**JVM 启动时加载**），类字节码文件在JVM加载的时候进行增强。
- 动态增强（**JVM 运行时加载**），已经被JVM加载的class字节码文件，当被修改或更新时进行增强，从JDK 1.6开始支持。

当然，在上面的方法列表中，每个方法有两个同名不同参数的方法，这是一种保险机制，JVM在加载一个class时会优先加载premain(String agentArgs, Instrumentation inst)，如果没有发现这个方法，就会调用premain(String agentArgs)方法；同理agentmain方法也是同样的调用规则。

下面是一个含有JavaAgent代理方法的实例：

```java
package com.crazymaker.agent.javassist.demo;
import java.lang.instrument.Instrumentation;

public class AgentDemo {
    /**
     * JVM 首先尝试在代理类上调用以下方法
     * 该方法在main方法之前运行，
     * 与main方法运行在同一个JVM中
     */
    public static void premain(String agentArgs, Instrumentation inst) {
        System.out.println("=========premain方法执行 1========");
        System.out.println("agentArgs:="+agentArgs);

    }
 
    /**
     * 候选的、兜底 方法：
     * 如果不存在 premain(String agentArgs, Instrumentation inst)
     * 则会执行 premain(String agentArgs)
     */
    public static void premain(String agentArgs) {
        System.out.println("=========premain 方法执行 2========");
        System.out.println("agentArgs:="+agentArgs);
    }
}
```

然后，需要让JVM知道有这么一个代理拦截类才行，类似于SPI中确定接口实现类一样，javaAgent需要创建`resources/META-INF.MANIFEST.MF` 文件，当 jar包打包时将文件一并打包，文件内容如下：

```
Manifest-Version: 1.0
Can-Redefine-Classes: true   # true表示能重定义此代理所需的类，默认值为 false（可选）
Can-Retransform-Classes: true    # true 表示能重转换此代理所需的类，默认值为 false （可选）
Premain-Class:  com.crazymaker.agent.javassist.demo.AgentDemo #premain方法所在类的位置
```

通过Premain-Class属性指定代理拦截类路径。最后需要配置JVM参数，提醒JVM在加载时运行这个代理拦截类：

```java
# VM options
-javaagent:D:\dev\SuperAPM\apm-agent\target\javassist-demo.jar=testargs
```

接着我们随便运行一个main方法，就会发现premain(String agentArgs, Instrumentation inst)方法中的内容被打印出来了。

### 使用ClassFileTransformer 修改字节码进行执行监控

在上述javaAgent代码中第二个参数是Instrumentation实例，如果我们想修改制定类的字节码，就要在这对象上做文章。

用到的主要方法是Instrumentation.addTransformer：

```java
// 说明：添加ClassFileTransformer
// 第一个参数：transformer，类转换器
// 第二个参数：canRetransform，经过transformer转换过的类是否允许再次转换
void Instrumentation.addTransformer(ClassFileTransformer transformer, boolean canRetransform)
```

而 [ClassFileTransformer](https://docs.oracle.com/javase/8/docs/api/java/lang/instrument/ClassFileTransformer.html) 则提供了tranform()方法，用于对加载的类进行增强重定义，返回新的类字节码流

需要特别注意的是，若不进行任何增强，当前方法返回null即可，若需要增强转换，则需要先拷贝一份classfileBuffer，在拷贝上进行增强转换，然后返回拷贝。

```java
// 说明：对类字节码进行增强，返回新的类字节码定义
// 第一个参数：loader，类加载器
// 第二个参数：className，内部定义的类全路径
// 第三个参数：classBeingRedefined，待重定义/转换的类
// 第四个参数：protectionDomain，保护域
// 第五个参数：classfileBuffer，待重定义/转换的类字节码（不要直接在这个classfileBuffer对象上修改，需拷贝后进行）
// 注：若不进行任何增强，当前方法返回null即可，若需要增强转换，则需要先拷贝一份classfileBuffer，在拷贝上进行增强转换，然后返回拷贝。
byte[] ClassFileTransformer.transform(ClassLoader loader, String className, Class classBeingRedefined, ProtectionDomain protectionDomain, byte classfileBuffer)

```

一个ClassFileTransformer 示例：

![image-20230303112420735](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303031124243.png)

上述的含义如下：

- 使用Instrumentation.addTransformer()方法添加一个新的ClassFileTransformer对象，用于实现修改字节码实现业务方法功能增强
- 使用Instrumentation.getAllLoadeClasses()方法获取所有加载的class信息，然后过滤要处理的class，使用Instrumentation.retransformClasses(newClazz)重新加载修改过的class

![image-20230303112844462](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303031128545.png)

在Transformer类中，过滤了需要修改的class类信息，然后在sayHello方法前后，分别打印一句话，然后返回这个新字节码的字节数组

然后我们创建一个Helloworld类实例，并执行其sayHello方法，就会发现业务得到了增强。

补充说明：

> redefineClasses 和 retransformClasses 补充说明

- 两者区别：

redefineClasses 是自己提供字节码文件替换掉已存在的 class 文件
retransformClasses 是在已存在的字节码文件上修改后再进行替换

- 替换后生效的时机

如果一个被修改的方法已经在栈帧中存在，则栈帧中的方法会继续使用旧字节码运行，新字节码会在新栈帧中运行

### ClassFileTransformer 结合ByteBuddy使用

ByteBuddy提供一系列api，可以配合javaAgent入口方法很方便的扩展字节码对象的编辑工作。

下面是一个实例：

```java
public static void premain(String agentArgs, Instrumentation instrumentation) {
    final ByteBuddy byteBuddy = new ByteBuddy().with(TypeValidation.of(false));
    //设置要拦截的方法前缀
    AgentBuilder agentBuilder = new AgentBuilder.Default(byteBuddy).ignore(
            nameStartsWith("net.bytebuddy.")
                    .or(nameStartsWith("org.slf4j."))
                    .or(nameStartsWith("org.groovy."))
                    .or(nameContains("javassist"))
                    .or(nameContains(".asm."))
                    .or(nameContains(".reflectasm."))
                    .or(nameStartsWith("sun.reflect"))
                    .or(ElementMatchers.isSynthetic()));
    
    for (Map.Entry<String, String> aspectEntry : loadAspectContexts().entrySet()) {
        String enhanceClass = aspectEntry.getKey();
        String enhanceAspect = aspectEntry.getValue();
        ElementMatcher.Junction matcher = named(enhanceClass).and(not(isInterface()));
        agentBuilder.type(matcher)
            //指定AgentBuilder.Transformer对象，用设置DynamicType.Builder对象
                .transform(new Transformer(enhanceAspect))
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            //设置监听器
                .with(new Listener())
            //已上ByteBuddy字节码操作对象写入到instrumentation中
                .installOn(instrumentation);
    }
}
```

AgentBuilder.Transformer可以设置我们之前熟知的DynamicType对象配置：

```java
AgentBuilder.Transformer transformer = (builder, typeDescription, classLoader, javaModule) -> {
    return builder
            .method(ElementMatchers.any()) // 拦截任意方法
            .intercept(MethodDelegation.to(MethodCostTime.class)); // 委托
};
```

配置AgentBuilder.Listener监听器，使用不多，主要是字节码在重新等方法上业务的监听。

```java
private static class Listener implements AgentBuilder.Listener {
    
    @Override
    public void onDiscovery(String typeName, ClassLoader classLoader, JavaModule module, boolean loaded) {
    }
    
    @Override
    public void onTransformation(final TypeDescription typeDescription,
                                 final ClassLoader classLoader,
                                 final JavaModule module,
                                 final boolean loaded,
                                 final DynamicType dynamicType) {
        Logger.info("On Transformation class {%s}.", typeDescription.getName());
    }
    
    @Override
    public void onIgnored(final TypeDescription typeDescription,
                          final ClassLoader classLoader,
                          final JavaModule module,
                          final boolean loaded) {
    }
    
    @Override
    public void onError(final String typeName,
                        final ClassLoader classLoader,
                        final JavaModule module,
                        final boolean loaded,
                        final Throwable throwable) {
        Logger.error("Enhance class {%s} error, loaded = %s, exception msg = %s", typeName, loaded, throwable.getMessage());
    }
    
    @Override
    public void onComplete(String typeName, ClassLoader classLoader, JavaModule module, boolean loaded) {
    }
}
```

下面是委托方法：

```java
public class MethodCostTime {

    @RuntimeType
    public static Object intercept(@Origin Method method, @SuperCall Callable<?> callable) throws Exception {
        long start = System.currentTimeMillis();
        try {
            // 原有函数执行
            return callable.call();
        } finally {
            System.out.println(method + " 方法耗时： " + (System.currentTimeMillis() - start) + "ms");
        }
    }

}

```

作用是记录目标方法的执行时间。

参考：https://bugstack.cn/md/bytecode/agent/2019-07-12-%E5%9F%BA%E4%BA%8EJavaAgent%E7%9A%84%E5%85%A8%E9%93%BE%E8%B7%AF%E7%9B%91%E6%8E%A7%E4%B8%89%E3%80%8AByteBuddy%E6%93%8D%E4%BD%9C%E7%9B%91%E6%8E%A7%E6%96%B9%E6%B3%95%E5%AD%97%E8%8A%82%E7%A0%81%E3%80%8B.html
