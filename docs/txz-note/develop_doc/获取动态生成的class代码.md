#### 1.JDK动态代理的class代码

```java
public class JdkTest {
    public static void main(String[] args) {
         //开启生成$Proxy0的class文件 
         //System.getProperties().put("sun.misc.ProxyGenerator.saveGeneratedFiles", "true");
        JdkStudent student = new JdkStudent();
        Person p = (Person) Proxy.newProxyInstance(student.getClass().getClassLoader(),
                student.getClass().getInterfaces(), new JdkProxy(student));
        System.out.println(p);
        p.say();
    }
}
```

注：JDK动态代理生成的文件默认在sun/proxy下，如果没有该目录会报Exception in thread “main” java.lang.InternalError: I/O exception saving generated file: java.io.FileNotFoundException: sun\proxy$Proxy0.class (系统找不到指定的路径。)

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