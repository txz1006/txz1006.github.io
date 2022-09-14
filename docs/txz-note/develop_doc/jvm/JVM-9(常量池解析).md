### JVM中有哪些常量池

在JVM中为了保证内存的高可用性，所以对使用频率较高的常量设计出了一系列池化容器。在JVM中主要有以下三个常量池：Class文件常量池、运行时常量池、字符串常量池。

### Class文件常量池

Class文件常量池也称为静态常量池，java文件编程成.class文件后，每个class文件内都包含了一个常量池，因为class文件是静态文件，所以这个常量池内容也是固定的，所以称为静态常量池。

例如我们来反编译一个测试Java类：

```java
public class Test {
    public static Object instance = new Object();
    public static final int num = 1;

    public static void main(String[] args) {
        Test test = new Test();
        int a = 4;
        int b = 5;
        int c = test.compute(a,b);
        System.out.println(c);
    }

    public int compute(int a,int b){
        return a * b - num;
    }
}
```

我们使用命令`javap -v Test.class`来反编译这个类，带到的文件内容如下：

```
Classfile /D:/campus-bsacs(0808)/target/test-classes/bsacs/web/test/Test.class
  Last modified 2022-9-1; size 878 bytes
  MD5 checksum d15ba0fc4a20835a0a2248ebb7eec133
  Compiled from "Test.java"
public class bsacs.web.test.Test
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Methodref          #7.#35         // java/lang/Object."<init>":()V
   #2 = Class              #36            // bsacs/web/test/Test
   #3 = Methodref          #2.#35         // bsacs/web/test/Test."<init>":()V
   #4 = Methodref          #2.#37         // bsacs/web/test/Test.compute:(II)I
   #5 = Fieldref           #38.#39        // java/lang/System.out:Ljava/io/PrintStream;
   #6 = Methodref          #40.#41        // java/io/PrintStream.println:(I)V
   #7 = Class              #42            // java/lang/Object
   #8 = Fieldref           #2.#43         // bsacs/web/test/Test.instance:Ljava/lang/Object;
   #9 = Utf8               instance
  #10 = Utf8               Ljava/lang/Object;
  #11 = Utf8               num
  #12 = Utf8               I
  #13 = Utf8               ConstantValue
  #14 = Integer            1
  #15 = Utf8               <init>
  #16 = Utf8               ()V
  #17 = Utf8               Code
  #18 = Utf8               LineNumberTable
  #19 = Utf8               LocalVariableTable
  #20 = Utf8               this
  #21 = Utf8               Lbsacs/web/test/Test;
  #22 = Utf8               main
  #23 = Utf8               ([Ljava/lang/String;)V
  #24 = Utf8               args
  #25 = Utf8               [Ljava/lang/String;
  #26 = Utf8               test
  #27 = Utf8               a
  #28 = Utf8               b
  #29 = Utf8               c
  #30 = Utf8               compute
  #31 = Utf8               (II)I
  #32 = Utf8               <clinit>
  #33 = Utf8               SourceFile
  #34 = Utf8               Test.java
  #35 = NameAndType        #15:#16        // "<init>":()V
  #36 = Utf8               bsacs/web/test/Test
  #37 = NameAndType        #30:#31        // compute:(II)I
  #38 = Class              #44            // java/lang/System
  #39 = NameAndType        #45:#46        // out:Ljava/io/PrintStream;
  #40 = Class              #47            // java/io/PrintStream
  #41 = NameAndType        #48:#49        // println:(I)V
  #42 = Utf8               java/lang/Object
  #43 = NameAndType        #9:#10         // instance:Ljava/lang/Object;
  #44 = Utf8               java/lang/System
  #45 = Utf8               out
  #46 = Utf8               Ljava/io/PrintStream;
  #47 = Utf8               java/io/PrintStream
  #48 = Utf8               println
  #49 = Utf8               (I)V
```

转换为可读信息后，我们可以看到其中包含了一个Constant pool容器存放着各种类信息和变量的常量信息，比如静态常量num为1，第一行#1的Methodref代表这是一个方法的引用，#7.#35代表由这两个需要的对应的常量组成，结果是第一行后的注释，也就是第一行代表Object类的wait()方法引用。而#4第四行代表的是Test.compute方法，I是int类型的描述符，(II)I符号则意味两个int类型的入参，出参也是int类型（关于class文件的解读可以参见https://www.jianshu.com/p/f6a3d26f939f）

这些常量信息可以分为两类，字面量和符号引用

##### 字面量

由字母、数字构成的字符串或常量，通常指由8中基础类型声明定义的变量值，比如上面Test类中num=1中的1就是一个字面量。还有其他的例子如下：

```java
//变量值都是字面量
int a = 2;
float b = 9.0;
String c = "Hello World";
cahr d = 'i';
```

##### 符号引用

符号引用是相对于内存对象的内存引用地址而言的，符号引用是静态的，直接引用是动态的，当class文件被JVM加载到内存时，会将符号引用转为内存的直接引用。记录方法之间的静态调用关系和直接引用就形成了动态链接，而符号引用主要有三种类型：

- 类和接口的全限定名
- 字段的名称和描述符
- 方法的名称和描述符

比如上面Test类中的instance、name都是字段名称，这就是符号引用；还有就是#36第三十六行的bsacs/web/test/Test就是类的全限定名，main、test和compute是方法名，`()V`是一种UTF8格式的描述符，这些统统都是符号引用。

例如，`test()`这个符号引用在运行时就会被转变为`test()`方法具体代码在内存中的地址，主要通过对象头里的类型指针去转换直接引用。

### 运行时常量池

运行时常量池存在方法区中，JVM在加载某个class文件时，会进行如下步骤操作：

- 根据类的全限定名将class文件转为字节流，读取到运行时常量池中构建成运行时数据结构(保存符号引用和直接引用的对应关系)
- 根据方法区类的信息创建一个单例Class对象实例放到堆内存空间中

要注意的是，运行时常量池中保存的“常量”依然是`字面量`和`符号引用`。比如字符串，这里放的仍然是单纯的文本字符串，而不是String对象。

### 字符串常量池

字符串常量池和静态变量在jdk1.7时被从方法区移到了堆内存空间中，作为字符串常量的存储空间。

字符串常量池的常用创建方式有两种。

```text
String a="Hello";
String b=new String("Mic");
```

1. `a`这个变量，是在编译期间就已经确定的，会进入到字符串常量池。
2. `b`这个变量，是通过`new`关键字实例化，`new`是创建一个对象实例并初始化该实例，因此这个字符串对象是在运行时才能确定的，创建的实例在堆空间上。

字符串常量池存储在堆内存空间中，创建形式如下图所示。



![img](https://pic1.zhimg.com/80/v2-c357d351a7957dc1c32479816f671d74_720w.jpg)



当使用`String a=“Hello”`这种方式创建字符串对象时，JVM首先会先检查该字符串对象是否存在与字符串常量池中，如果存在，则直接返回常量池中该字符串的引用，不会新创建对象。否则，会在常量池中创建一个新的字符串对象，并返回常量池中该字符串的引用。这种字符串直接赋值会创建0个或1个对象（这种方式可以减少同一个字符串被重复创建，节约内存，这也是享元模式的体现）。

> 如下图所示，如果再通过`String c=“Hello”`创建一个字符串，发现常量池已经存在了`Hello`这个字符串，则直接把该字符串的引用返回即可。（String里面的享元模式设计）



![img](https://pic4.zhimg.com/80/v2-54f541da92abdcc6d80696b4b03e752b_720w.jpg)



当使用`String b=new String(“Mic”)`这种方式创建字符串对象时，由于String本身的不可变性（后续分析），因此在JVM编译过程中，会把`Mic`放入到Class文件的常量池中，在类加载时，会在字符串常量池中创建`Mic`这个字符串。接着使用`new`关键字，在堆内存中创建一个`String`对象并指向常量池中`Mic`字符串的引用，当然要注意如果字符串常量池中已经存在了Mic对象，则字符串不会再创建一个Mic对象，所以new String会创建1个或2个对象。

> 如下图所示，如果再通过d =`new String(“Mic”)`创建一个字符串对象，此时由于字符串常量池已经存在`Mic`，所以只需要在堆内存中创建一个`String`对象即可。



![img](https://pic4.zhimg.com/80/v2-456ef5d65ac434e49e2e96433f55846b_720w.jpg)



为什么JVM会需要单独设计字符串常量池？

1. String对象作为`Java`语言中重要的数据类型，是内存中占据空间最大的一个对象。高效地使用字符串，可以提升系统的整体性能。
2. 创建字符串常量时，首先检查字符串常量池是否存在该字符串，如果有，则直接返回该引用实例，不存在，则实例化该字符串放入常量池中。
3. 如果字符串字面量在Class常量池中就存在，则只有在该字符串被调用时，才会将运行时常量池中复制一份创建到字符串常量池中

对应判断两个字符串引用地址是否相等存在以下规则：

- 直接使用字面量赋值会直接返回字符串常量池中的引用地址(String a = "你好啊")
- 使用new String创建的对象一定是一个新的堆内存对象
- 有+的字符串拼接，且只要存在new String或者非final定义的变量，一定是会创建新的堆内存对象
- String.intern()返回的是字符串常量池中的引用地址，如果该字符串在池中不存在则新建

```java
 String aa = "a";
 String bb = "b";
 final String cc = "b";
 String dd = new String("a") + new String("b");
 String ee = new String("a") + "b";
 String ff = aa + "b";
 String gg = "a" + cc;
 String jj = aa + bb;
 String kk = "ab";
 String yy = "a" + "b";
//jdk1.8下测试
 System.out.println( kk == dd); //false
 System.out.println( kk == ee); //false
 System.out.println( kk == ff); //false
 System.out.println( kk == gg); //true
 System.out.println( kk == jj); //false
 System.out.println( kk == dd.intern()); //true
 System.out.println( kk == ee.intern()); //true
 System.out.println( kk == yy); //true
 System.out.println( ff == gg); //false
 System.out.println( ff.intern() == gg); //true
 System.out.println( jj.intern() == jj); //false
 System.out.println( gg.intern() == gg); //true
```
来理解下下面这个实例，看看执行结果会是什么：

```java
public static void main(String[] args) {
  String a =new String(new char[]{'a','b','c'});
  String b = a.intern();
  System.out.println(a == b);

  String x =new String("def");
  String y = x.intern();
  String z = "def"; 
  System.out.println(x == y);
  System.out.println(z == y);  
}
```

正确答案是：

```text
true
false
true
```

第三个true可以理解为，前面创建String x =new String("def");对象时，已经在字符串常量池中创建好了，所以在String z = "def"; 时会直接指向常量池之前创建好的def对象。

第二个输出为`false`也可以理解，因为`new String(“def”)`会做两件事：

1. 在字符串常量池中创建一个字符串`def`，如果def已经存在则不会再创建。
2. `new`关键字在堆空间创建一个实例对象`string`，并指向字符串常量池`def`的引用。

而`x.intern()`，是从字符串常量池获取`def`的引用，堆空间String引用地址和字符串常量池中的字符串对象引用地址是不同的。

```java
//第二个输出可以这么理解
//String x =new String("def");可以理解为下面两句
String temp = "def";  //在字符串常量池创建一个def对象def对象
String x = new String(temp); //堆中创建一个String对象指向字符串常量池中的对象

String y = x.intern();   //获取字符串常量池中def对象def对象的引用地址(如果常量池中没有这个字符串则会新建)
System.out.println(x == y);  //堆String地址肯定不等于字符串常量池中def对象地址
System.out.println(temp == y); //这个是等于true的
```

第一个输出结果为`true`是为啥捏？

在构建`String a`的时候，使用`new char[]{‘a’,’b’,’c’}`初始化字符串时对创建堆对象，而又创建了一个new String对象指向的这个字符数组对象，并没有在字符串常量池中构建`abc`这个字符串实例，所以当调用`a.intern()`方法时，会将变量a指向的String对象地址写到字符串常量池中，这样堆内存和常量池中的引用就是相同的。

简单总结下就是：

如果字符串先被直接定义，那么会在字符串常量池中创建这个String对象，之后新建的String对象都会指向常量池中的这个对象，这种情况下取常量池中的对象引用地址和对内存中的对象引用地址并不相同。

```java
String c = "zzz";
String d = new String(c);
System.out.println(d.intern() == d);  //false
System.out.println(d.intern() == c); //true
System.out.println(c == d); //false
```

如果字符串是先由一些newString用+加号拼接而成，那么字符串常量池中并没有这个组合字符串对象，只有堆内存中存在的组合String对象，在这种情况下如果执行了intern()方法，则字符串常量池中会存储堆内存中String对象的引用地址，这种情况下取常量池中的对象引用地址和对内存中的对象引用地址是相同的。

```java
String a = new String(new char[]{'a','b','c'});
System.out.println(a.intern() == a); //true
String b = "abc";
System.out.println(b == a); //true
//或者
String s3 = new String("3") + "3";// 在堆里创建3个对象,s3指向拼接后的对象
s3.intern();// 在字符串池里创建引用指向堆里的字面量对象"33"
String s4 = "33";// 字符串池里已经存在字面量对象"33"的引用,不再重复创建,s4指向已经存在的引用
System.out.println(s3.intern() == s3); //true
System.out.println(s4 == s3); //true
```

参考：

https://blog.csdn.net/lotusPlant/article/details/125804308

[JVM知识梳理之二_JVM的常量池 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/351226127)

[详解JVM的常量池_sermonlizhi的博客-CSDN博客_jvm常量池](https://blog.csdn.net/sermonlizhi/article/details/124945205)

[超过1W字深度剖析JVM常量池（全网最详细最有深度） - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/431237260)
