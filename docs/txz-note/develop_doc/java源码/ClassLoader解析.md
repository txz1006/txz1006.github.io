## ClassLoader解析

在Java中，启动项目时底层代码会使用双亲委派机制来加载所有的class文件，而这个加载工作主要由三个ClassLoader对象来完成。

在分析ClassLoader前，我们需要知道，jre是java程序的运行环境基础，jdk是java程序的开发环境基础，而jdk是包含jre存在的，在安装jdk时，我们一般需要在操作系统环境变量中配置3个环境变量：JAVA_HOME、CLASSPATH、PATH来指向jdk的安装路径，这样java程序在启动时就可以通过这些系统变量提前加载好java环境来运行具体的代码。我们可以先输出下这几个参数：

![image-20220817135714653](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208171357888.png)

其中CLASSPATH是java配置的扫描jar、class文件路径的配置，开头的.指的是当前路径目录。我们可以使用通过java的classpath命令来搜索执行某个class文件

```java
//在f://目录下，搜索并执行hello.jar中名称路径为abc.xyz.Hello的类的main方法
java -cp f://hello.jar abc.xyz.Hello

//如果系统classpath路径中有设置了f://根目录为资源路径，那么可以不用jar或class的绝对路径，java会自动搜索classpath下的资源和要执行的jar或class名称来匹配
java -cp hello.jar abc.xyz.Hello
```

下面我们以Java入口类sun.misc.Launcher来分析说明java程序的类加载逻辑：

#### ExtentionClassLoader，扩展类加载器

在sun.misc.Launcher.ExtClassLoader静态类中，该类加载器加载数据来源是System.getProperty("java.ext.dirs")，我们可以先打印下看看有哪些东西：

```java
System.out.println(System.getProperty("java.ext.dirs"));
//D:\jdk8u302-b08\jre\lib\ext;C:\WINDOWS\Sun\Java\lib\ext
```

也就是说**Extention ClassLoader** 扩展的类加载器，加载目录%JRE_HOME%\lib\ext目录下的jar包和class文件。还可以加载`-D java.ext.dirs`选项指定的目录。

#### ApplicationClassLoader，应用类加载器

在sun.misc.Launcher.AppClassLoader静态类中，该类加载器加载数据来源是System.getProperty("java.class.path")，我们同样打印出来

```java
System.out.println(System.getProperty("java.class.path"));
//D:\jdk8u302-b08\bin\java.exe "-javaagent:D:\Program Files\JetBrains\IntelliJ IDEA 2021.2.1\lib\idea_rt.jar=65174:D:\Program Files\JetBrains\IntelliJ IDEA 2021.2.1\bin" -Dfile.encoding=UTF-8 -classpath "D:\jdk8u302-b08\jre\lib\charsets.jar;D:\jdk8u302-b08\jre\lib\ext\access-bridge-64.jar;.....等等...D:\campus-bsacs(0808)\target\classes;F:\.m2\repository\org\javassist\javassist\3.18.1-GA\javassist-3.18.1-GA.jar;D:\campus-bsacs(0808)\src\main\webapp\WEB-INF\lib\ly-uap.3.2.0.jar;
```

代码是在idea中运行的main方法，可以发现java.class.path获取到了很多jar、class文件的路径，主要有这几个方面的，一个是jre/lib目录下的jar路径，一个是idea编辑器需要的一些jar路径，还有就是当前项目的编译jar和class的文件路径，以及maven项目实际使用到的仓库中的jar路径。

换句话说ApplicationClassLoader加载的是当前应用的classpath的所有类

#### BootStrapClassLoader，启动类加载器

Bootstrap ClassLoader 是最顶层的加载类，主要加载核心类库，%JRE_HOME%\lib下的rt.jar、resources.jar、charsets.jar和class等。另外需要注意的是可以通过启动jvm时指定-Xbootclasspath和路径来改变Bootstrap ClassLoader的加载目录。比如java -Xbootclasspath/a:path被指定的文件追加到默认的bootstrap路径中。我们可以打开我的电脑，在上面的目录下查看，看看这些jar包是不是存在于这个目录。

Bootstrap ClassLoader是由C/C++编写的，它本身是虚拟机的一部分，所以它并不是一个JAVA类，也就是无法在java代码中获取它的引用，[JVM](https://so.csdn.net/so/search?q=JVM&spm=1001.2101.3001.7020)启动时通过Bootstrap类加载器加载rt.jar等核心jar包中的class文件，之前的int.class,String.class都是由它加载。然后呢，我们前面已经分析了，JVM初始化sun.misc.Launcher并创建Extension ClassLoader和AppClassLoader实例。并将ExtClassLoader设置为AppClassLoader的父加载器。Bootstrap没有父加载器，但是它却可以作用一个ClassLoader的父加载器。比如ExtClassLoader。这也可以解释之前通过ExtClassLoader的getParent方法获取为Null的现象

#### 双亲委派机制

了解到三个类加载器后，我们简单说下所谓的双亲委派机制和这些类加载器的加载顺序。

双亲委派机制，简单的说就是一个类加载器要加载一个类时，会先委托为自己的父类加载器ExtClassLoader来加载，如果父类加载器也有父类加载器同样会向上委托，就这样一层一层的递归直到BootStrapClassLoader，如果某个父类加载器扫描到自己加载的类列表中刚好有这个类，就会直接返回当前父类加载出来的Class对象；反之，如果没有任何一个父类加载器匹配到这个类，那么就会由AppClassLoader来加载这个类的Class对象。示意图如下：

![image-20220817173213917](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208171732235.png)

采用双亲委派机制的主要原因是，一为了避免类的重复加载，二是为了安全，保证核心的api类不被篡改。当然双亲委派也有局限性，有些场景就需要打破双亲委派，比如Java的SPI机制，tomcat容器加载机制等等


然后我来看这几个类加载器的继承关系图：

![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL2ltZy5ibG9nLmNzZG4ubmV0LzIwMTcwMjExMTEyNzU0MTk3?x-oss-process=image/format,png)

扩展类加载器和应用类加载器都继承了URI类加载器，顶端对象是ClassLoader，其中的关键方法是ClassLoader.loadClass，这个类的作用是根据类的全限定名称读取class文件的字节数组，将之读取为Class类并缓存到内存对象中。

关键代码如下：

```java
    protected Class<?> loadClass(String name, boolean resolve)
        throws ClassNotFoundException
    {
        synchronized (getClassLoadingLock(name)) {
            // 检查当前类是否已经被加载过了，是则直接返回Class对象
            Class<?> c = findLoadedClass(name);
            if (c == null) {
                long t0 = System.nanoTime();
                try {
                    //如果当前类加载器的父类加载器存在
                    if (parent != null) {
                        //使用父类加载器加载这个类
                        c = parent.loadClass(name, false);
                    } else {
                        //如果父类加载器为null,则使用BootStrapClassLoader来加载这个类
                        c = findBootstrapClassOrNull(name);
                    }
                } catch (ClassNotFoundException e) {
                    // ClassNotFoundException thrown if class not found
                    // from the non-null parent class loader
                }
                
                if (c == null) {
                    // 如果上面的一系列父类加载器都没有加载成功，则使用当前类加载器来加载
                    //当前类加载器一般指AppClassLoader
                    c = findClass(name);
                }
            }
        }
    }
```

对应上面的加载jar内容，我们可以知道

- BootStrapClassLoader负责加载jdk下lib目录下的jar和class
- ExtClassLoader负责加载jdk下lib/ext目录下的jar和class
- AppClassLoader负责加载开发者项目中的的jar和class



#### 项目中我们如何获取ClassLoader

先看一个实例：

![image-20220818153240676](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208181532892.png)

从上图的执行结果可见一般获取ClassLoader有两种方式，一是获取线程上下文的ClassLoader，二是从类的Class中获取，而且线程上下文CLassLoader和从类中获取ClassLoader是同一个AppClassLoader，AppClassLoader的父加载器是ExtClassLoader，ExtClassLoader的父加载器是null，也就是BootClassLoader。

为什么线程上下文类加载器默认的ClassLoader是AppClassLoader》因为是从ClassLoader.getSystemClassLoader()获取的，而ClassLoader是从Launcher.getClassLoader()获取的

```java
 //classLoader   
private static synchronized void initSystemClassLoader() {
        if (!sclSet) {
            if (scl != null)
                throw new IllegalStateException("recursive invocation");
            sun.misc.Launcher l = sun.misc.Launcher.getLauncher();
            if (l != null) {
                Throwable oops = null;
                scl = l.getClassLoader();
                ....
}
//Launcher
private ClassLoader loader;

public Launcher() {
    // Create the extension class loader
    ClassLoader extcl;
    try {
        extcl = ExtClassLoader.getExtClassLoader();
    } catch (IOException e) {
        throw new InternalError(
            "Could not create extension class loader", e);
    }

    // Now create the class loader to use to launch the application
    try {
        loader = AppClassLoader.getAppClassLoader(extcl);
    }
}
public ClassLoader getClassLoader() {
    return loader;
}
```



#### 如何破坏双亲委派机制

在上述的ClassLoader代码中ClassLoader.loadClass就是核心加载方法，我们可以自定义ClassLoader类继承ClassLoader，如果需要自定义加载网络、磁盘其他位置的jar或class，只需要重写findClass方法就好，而破坏双亲委派则需要重写loadClass方法，去掉[c = parent.loadClass(name, false);]()改变整个class文件加载逻辑。

前面说的java SPI，tomcat加载会破坏双亲委派，这里简单的讲下：

```java
比如DriverManager是jdk中rt.jar包的类对象，需要被BootClassLoader加载的，而DriverManager的Class类会在加载中执行其静态方法，静态方法会通过ServiceLoader<Driver> loadedDrivers = ServiceLoader.load(Driver.class);加载Driver的三方实现类，但是三方实现类需要AppClassLoader来加载，所以SPI机制这里需要在BootClassLoader里调用AppClassLoader来加载三方的Class对象，这是反双亲委派的。
public static <S> ServiceLoader<S> load(Class<S> service) {
    //获取线程上下文类加载器，一般默认是AppClassLoader
    ClassLoader cl = Thread.currentThread().getContextClassLoader();
    return ServiceLoader.load(service, cl);
}

同样，tomcat需要有隔离加载多个项目的名称相同但是不同版本jar包的能力，这些jar包中的类往往名称相同，但是内容不同，所以要被隔离加载，此时双亲委派是无法满足这种隔离加载的。
```

上讲到的Thread.currentThread().getContextClassLoader();，线程上下文类加载器，这是和线程绑定在一起的ClassLoader对象，实际上是Thread对象中的一个成员变量，可以通过get、set方法来获取设置。

```java
public class Thread implements Runnable {

/* The context ClassLoader for this thread */
   private ClassLoader contextClassLoader;
   
   public void setContextClassLoader(ClassLoader cl) {
       SecurityManager sm = System.getSecurityManager();
       if (sm != null) {
           sm.checkPermission(new RuntimePermission("setContextClassLoader"));
       }
       contextClassLoader = cl;
   }

   public ClassLoader getContextClassLoader() {
       if (contextClassLoader == null)
           return null;
       SecurityManager sm = System.getSecurityManager();
       if (sm != null) {
           ClassLoader.checkClassLoaderPermission(contextClassLoader,
                                                  Reflection.getCallerClass());
       }
       return contextClassLoader;
   }
}
```



#### 类加载器的应用

##### 1.动态加载非项目中的jar或class对象

准备一个放在某个盘的class文件

```java
public class HelloWorld {

    public static void main(String[] args) {
        System.out.println(circumference(1.6f));
    }

    public static float circumference(float r){
        float pi = 3.14f;
        float area = 2 * pi * r;
        return area;
    }
}
```

创建一个自定义CLassLoader用来加载上方的Class文件

```java
public class DiskClassLoader extends ClassLoader{

    private Path path;

    public DiskClassLoader(String path){
        this.path = Paths.get(path).toAbsolutePath();
    }

    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        try {
            Class clazz = findLoadedClass(name);
            if(clazz !=null){
                return clazz;
            }
            byte[] classByteArr = Files.readAllBytes(getAbFilePsth(name));
            return defineClass(name, classByteArr, 0 ,classByteArr.length);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return super.findClass(name);
    }

    private Path getAbFilePsth(String classPath){
        classPath = classPath.replaceAll("\\.", "/");
        return path.resolve(classPath + ".class");
    }

    public static void main(String[] args) throws ClassNotFoundException, InstantiationException, IllegalAccessException, NoSuchMethodException, InvocationTargetException {
        DiskClassLoader classLoader = new DiskClassLoader("e:");
        //自定义类加载器的父加载器是AppClassLoader
        System.out.println(classLoader.getParent());
        //使用DiskClassLoader加载HelloWorld的class
        //如果使用loadClass，依旧会使用双亲委派加载，bootClassLoader-->extClassLoader-->appClassLoader-->DiskClassLoader
        //等同于Class clazz1 = Class.forName("com.pwb.springjvmm.HelloWorld", true, classLoader);
        Class clazz1 = classLoader.loadClass("com.pwb.springjvmm.HelloWorld");
        //findClass直接使用DiskClassLoader的规则加载外部class
        Class clazz = classLoader.findClass("com.pwb.springjvmm.HelloWorld");
        System.out.println(clazz.getClassLoader());
        Object obj = clazz.newInstance();
        Method method = clazz.getDeclaredMethod("circumference", float.class);
        System.out.println(method.invoke(obj, 1.6f));
        System.out.println(ClassLoader.getSystemClassLoader());
    }

}

//执行结果
sun.misc.Launcher$AppClassLoader@18b4aac2
com.pwb.springjvmm.DiskClassLoader@448139f0
10.048
sun.misc.Launcher$AppClassLoader@18b4aac2
```

同理，将文件读取改为网络读取的方式就可以加载网络上的jar和class了

```java
ublic class Test {

    public static void main(String[] args) throws MalformedURLException, NoSuchMethodException, InvocationTargetException, IllegalAccessException, ClassNotFoundException, InstantiationException {
        URLClassLoader loader = (URLClassLoader) Test.class.getClassLoader();
        // 获取本地jar文件的URL
//        File jarFile = new File("/Users/zgy/IdeaProjects/test/target/maven-thrift-client-0.0.1-SNAPSHOT.jar");
//        URL targetUrl = jarFile.toURI().toURL();
        // 获取远程jar文件的URL
        URL targetUrl = new URL("http://localhost:8888/target/maven-thrift-client-0.0.1-SNAPSHOT.jar");

        // 这个校验是为了避免重复加载的
        boolean isLoader = false;
        for (URL url : loader.getURLs()) {
            if (url.equals(targetUrl)) {
                isLoader = true;
                break;
            }
        }

        // 如果没有加载，通过反射获取URLClassLoader.allURL方法来加载jar包
        if (!isLoader) {
            Method add = URLClassLoader.class.getDeclaredMethod("addURL", new Class[]{URL.class});
            add.setAccessible(true);
            add.invoke(loader, targetUrl);
        }

        // 加载指定的class，然后为其创建对象后执行其方法，这些操作都是用反射去做的
        Class<?> remoteClass = loader.loadClass("Remote");
        Object remoteInstance = remoteClass.newInstance();
        Method method = remoteClass.getDeclaredMethod("func");
        method.setAccessible(true);
        System.out.println(method.invoke(remoteInstance));
    }
}

```

一个动态上传jar，调用起类方法的案例：[java项目动态加载外部jar，调用其中类方法 - 风子磊 - 博客园 (cnblogs.com)](https://www.cnblogs.com/zhulei2/p/15499662.html)

##### 2.对class文件进行加密

将class文件读取成字节流，然后给字节进行加密，最后输出成classen文件

```java
public class FileUtils {
	
	public static void test(String path){
		File file = new File(path);
		try {
			FileInputStream fis = new FileInputStream(file);
			FileOutputStream fos = new FileOutputStream(path+"en");
			int b = 0;
			int b1 = 0;
			try {
				while((b = fis.read()) != -1){
					//每一个byte异或一个数字2
					fos.write(b ^ 2);
				}
				fos.close();
				fis.close();
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

}

```

在读取时，按流读取，将每个字节异或回来加载成正常的class

```java
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;


public class DeClassLoader extends ClassLoader {
	
	private String mLibPath;
	
	public DeClassLoader(String path) {
		// TODO Auto-generated constructor stub
		mLibPath = path;
	}

	@Override
	protected Class<?> findClass(String name) throws ClassNotFoundException {
		// TODO Auto-generated method stub
		
		String fileName = getFileName(name);
		
		File file = new File(mLibPath,fileName);
		
		try {
			FileInputStream is = new FileInputStream(file);
			
			ByteArrayOutputStream bos = new ByteArrayOutputStream();
			int len = 0;
			byte b = 0;
	        try {
	            while ((len = is.read()) != -1) {
	            	//将数据异或一个数字2进行解密
	            	b = (byte) (len ^ 2);
	            	bos.write(b);
	            }
	        } catch (IOException e) {
	            e.printStackTrace();
	        }
	        
	        byte[] data = bos.toByteArray();
	        is.close();
	        bos.close();
	        
	        return defineClass(name,data,0,data.length);
			
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return super.findClass(name);
	}

	//获取要加载 的class文件名
	private String getFileName(String name) {
		// TODO Auto-generated method stub
		int index = name.lastIndexOf('.');
		if(index == -1){ 
			return name+".classen";
		}else{
			return name.substring(index+1)+".classen";
		}
	}
	
}
```

参考：https://blog.csdn.net/ss810540895/article/details/124570569
