java基础

### /*一、java概念

##### **1.java特点？**

使用JVM：速度快，平台无关性好

静态语言：安全性好

`面向对象`

`多线程开发`

##### **2.JVM和JDK、JRE的关系？**

JVM(Java virtual mechine)是解析java字节码文件(.class文件)的虚拟机环境，能直接读取字节码文件，并转换成机器码。

JRE(Java runtime environment)包含有JVM和java文件执行的所有组件，也就是执行java代码需要配置JRE环境就足够了

JDK(java development kit)包含了JRE的全部组件，同时包含有创建、编译java文件等做java开发的组件。就是如果要进行java开发，就必须要配置JDK开发环境

![image-20210412095114340](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210812110524.png)

##### **3.Java和C++的区别？**

java没有c++中能直接操作内存的指针概论

关于类的继承，java是单继承，c++是多继承；但是java接口可以多继承

`java内存由JVM自动管理，c++需要手动管理`

##### **4.java程序主类和应用程序的主类？**

一个类中只能有一个public class存在，类入口已办为main方法

应用程序主类一般指继承了Applet类的类

##### **5.import java和javax的区别？**

两者都是javaAPI的一部分，区别是javax最早是作为java扩展包API，之后由于java核心内容的丰富，javax也成为了基本核心代码，由于使用过多，修改麻烦，就保留下来。两种方式作用相同

##### **6.java语言编译和解释共存？**

一般来说，程序的执行需要将代码翻译成cpu能读懂的机器码，这个过程就是编译。而java的编译会将代码编译成字节码文件，由中间对象JVM将字节码解释成机器码后执行

==============================

### 二、java基础

##### **7.字符型常量和字符串常量的区别？**

字符型常量：由单引号括住某个字符，类型是char，可以直接作为ASCII码进行算术逻辑处理，

字符串常量：由双引号括住的多个字符，类型是String，是一个引用对象

##### **8.标识符和关键字区别？**

对于类、方法、变量的命名字符串就是标识符，但是系统指定了一些标识符

作为特殊的关键字，这些关键字代表特殊的作用。

public private protected extend implement等

##### **9.自增自减运算符**

对于int类型变量进行加一、减一操作

int a = 1;

a++;指先使用a进行逻辑运算，之后对变量a进行加一

++a;指先对变量a进行加一，之后使用a进行逻辑运算

##### **10.return、break和continue区别？**

continue：结束本次循环

break：跳出循环

return：结束方法，返回结果

##### **11.java泛型和类型擦除？**

泛型是java中用于限制参数类型的结构，表现为<>，主要有类泛型、方法泛型、变量泛型。

泛型变量只能进行最基础的赋值等操作

类型擦除指泛型在java代码在编译后会被去掉：

```java
List<String> s = new ArrayList<>();  //直接调用add只能添加String元素

//但是通过反射可以添加其他类型元素

Class clazz = s.getClass();

Method me = clazz.getDeclaredMethod("add", Obejct.class);

me.invoke(s, 123);
```

##### 11.1Object类中的方法由哪些？

获取Class对象：getClass()

获取该对象的哈希值：hashCode()

比较、克隆和打印字符串：equals()、clone()、toString()

线程相关：wait()、notify()、notifyAll()

##### **12.==和equals()的区别？**

如果是引用对象，==对比两个对象的引用地址是否相同；

如果是基础类型，==对比两个对象的值(范围：-128~127);

equals()方法位于Object.class中，默认的equals()的逻辑和==相同，所以之后的类型需求重写equals()，例如String的equals()会先判断引用地址是否相同，之后在判断字符串是否相同。

##### **13.hashCode()和equals()?**

重写equals()必须要重写hashCode()，why？因为两个对象相同则hashCode()一定相等，反之hashCode()相同而对象则可能不同；实际上每个对象的的hashCode()都是本地方法根据堆数据产生的独特值，即使两个内容相同的对象，hashCode()也不会相同，所以需要被重写(参考下面的hashSet示例)。

hashCode()返回一个int类型的hash散列值，用来表示当前对象在哈希表中的位置，也仅在哈希表中起作用，其他地方没用。

所以hashCode()一般用于集合对象中判断元素是否已存在，来看实例：

```java
Person p1 = new Person(1);
Person p2 = new Person(1);
Set<Person> set = new HashSet<>();
set.add(p1);
set.add(p2);
//输出set
```

创建两个属性相同的Person对象，将两个对象放入一个set集合中，得到set集合还是p1和p2两个元素，为什么出现这种情况呢？因为set集合就是使用hashCode()判断加入元素是否已存在列表中的，p1和p2的hashCode()值是不同的，所以被判断成了两个不同的元素。

想要判断p1和p2相同，就要重写hashCode()方法，用某个属性的hashCode()值代替。

```java
@Override
public int hashCode(){
    //使用Person类中的personId属性的哈希值作为整个对象的哈希值
    return this.personId.hashCode();
}
```

##### **14.基础类型与装箱拆箱**

基础类型:字节数：boolean:1、byte:1、char:2、short:2、int:4、float:4、long:8、double:8

包装类型:Boolean、Byte、Character、Short、Integer、Float、Long、Double

区别：包装类型没有默认值，基础类型有默认值；基础类型存在栈中，包装类型对象存在堆中，基础类型执行效率高，包装类型执行效率低

为什么要有包装类呢？因为java是面向对象的语言，基础类型不具有对象的特性，方便将这些基础类型作为对象来使用(例如集合的元素类型必须使用包装类型，不能使用基础类型)

java中对于类型相同的基础类型和包装类型可以自动转化，称为装箱和拆箱

装箱：基础类型转包装类型

Integer i = 10000 ===>等价于Integer i = new Integer(10000)

拆箱：包装类型转基础类型

int i = new Integer(10000) ====>等价于int i = new Integer(10000).intValue()

```
注意：Integer对象中的valueif(int)方法，如果参数范围在-128~127之间，会使用Integer的内置缓存值，此时==和equals()d都返回true
当参数不在-128~127之间时，Integer会将对象转换为新的Integer对象，此时==比较引用地址返回false，equals()返回true
```

##### 14.1 switch条件语句支持哪些数据类型

jdk1.7前只支持byte、char、short、int四种继承类型，jdk1.7开始支持者四种类型的包装类型和String类型，其中String类型是通过其hashCode实现的,，如果产生哈希冲突则会通过比较String的内容来区分

```java
        String c = "1231";
        switch(c){
            case "1": System.out.println("..."); break;
            case "2": System.out.println("..."); break;
            case "3": System.out.println("..."); break;
            case "4": System.out.println("..."); break;
            default: System.out.println("...");
        }
```

##### **15.包装类型与常量池**

因为包装类型对象经常要被使用，所以java中对于一些类型常用的范围做了常量缓存池：

Byte、Short、Integer、Long: \[-128~127\]，这个范围内直接使用常量值，范围之外会new成包装对象(所以这些类型判断相等时要仔细一些)

```java
Integer a = new Integer(40);
Integer b = 40;
int c = 40;
System.out.println(b == a);  //true
System.out.println(b == a.intern()); //true
System.out.println(b == c);  //true
System.out.println(a == c);  //true(拆箱成int)

Integer c = new Integer(200);
Integer d = 200;  //等同于Integer.valueOf(obj)
int e = 200;
System.out.println(d == c);  //false
System.out.println(d == c.intValue());  //true(int和Integer的比较)
System.out.println(c == e);  //true(拆箱成int)
System.out.println(d == e);  //true
```

Character:\[0~127\]

以String常量池为例：

String.intern()会返回常量池中的对象，若常量池中无该对象，则先创建后指向该对象：

```java
String a1 = "a";
String a2 = "b";
String a3 = a1+a2;
String a4 = new String("ab");
String a5 = "a"+"b";
System.out.println(a3 == a4.intern());
System.out.println(a5 == a4.intern());

//结果
false
true
//解析：首先a4.intern()返回常量池中的"ab"对象，a5中进行静态字符串拼接会直接查找常量池是否有结果值(没有就创建)，所以返回的也是常量池中的"ab"对象；而拼接中使用了变量a1+a2，带变量的拼接会创建新String对象，不会创建常量池对象
如果是使用final修饰的变量，会在编译后为其创建字符串常量    
```

final关键字对String的影响：final修饰的对象在被使用时会被翻译成对应的常量值(编译后)

```java
public static void main(String[] args) {
    String a = "a";
    String b = "b";
    final String a0 = "a";
    final String a1 = "a" + b;
    final String b1 = a + b;

    String c = "a" + "b";
    String d = a + "b";
    String e = a0 + "b";
    String f = a + b;
    String h = a0 + b;
    String g = "ab";
    System.out.println(a1 == g);  //false  {在运行时才确定b变量，此时会创建一个新String对象"ab"}
    System.out.println(b1 == g);  //false {同上}
    System.out.println(c == g);   //true {编译时确定常量拼接，直接引用指向常量池的值}
    System.out.println(d == g);   //false {在运行时才确定a变量，此时会创建一个新String对象"ab"}
    System.out.println(e == g);   //true {final修饰变量在编译时，会将a0翻译成"a",等同于常量拼接}
    System.out.println(f == g);   //false {涉及变量引用，会创建新的String对象}
    System.out.println(h == g);   //false {涉及变量引用，会创建新的String对象}
}

```

此处参考：https://www.cnblogs.com/naliyixin/p/8984077.html

```java
        //1
        String s = new String("ABC");
        s.intern();
        String s1 = "ABC";
        System.out.println(s1 == s);

        //2
        String a1 = "2" + new String("2");
        a1.intern();
        String a2 = "22";
        System.out.println(a2 == a1);

        //3
        String b1 = new StringBuilder("2").append("2").toString();
        String b2 = "22";
        b1.intern();
        System.out.println(b2 == b1);


        /**
         * 3个答案依次是false,true,false
         * 先来分析第一段代码：String s = new String("ABC")这行代码会创建2个对象，一个是String对象，一个是ABC对象，而且ABC的引用会被
         * 存储到字符串常量池中(如果ABC这个常量在字符串常量池中已经有了，那么就只会创建String一个对象)，所以s引用指向的是String对象，s1指向的是常量池中的ABC对象引用
         *
         * 第二段代码：String a1 = "2" + new String("2")这行代码最终会创建2个对象(一个是字符串常量池中的2对象，另一个是a1指向的22对象，
         * 中间过程还会生成一个new String("2")的中间对象)，a1指向的22对象是拼接成的，在字符串常量池中没有这个常量，所以当执行a1.intern()时，
         * 需要创建一份22的常量对象，然后将其引用放入字符串常量池中。但是，由于字符串常量池和对象实例都在同一个堆空间中(jdk1.7后字符串常量池由方法区移到了堆中)，
         * 已经存在一个a1指向的22字符串对象，尽管这个对象是拼接的，那么就没有必要再创建一个22对象了，JVM会直接将a1指向的22字符串对象的地址引用放入字符串常量池中，
         * 这样后面的a2引用指向的对象实际就是a1指向的对象了，所以两者相同
         *
         * 第三段代码：调换了一下intern()的位置，在intern()之前执行了String b2 = "22"，这行代码会在字符串常量池中创建一个22对象，并返回其地址。
         * 再执行b1.intern()时发现常量池中已经存在22对象了，所以两者是不同的。
         *
         *
         */
```

参考：https://tech.meituan.com/2014/03/06/in-depth-understanding-string-intern.html

##### 15.5 String、StringBuffer、StringBuilder区别

**String**内部是一个常量的char数组，每进行一次改变操作，都是创建一个新的对象，所以适合在字符串操作少的场景使用

下面两个对象会动态修改char数组进行动态扩容(和map类似，默认大小是16或初始化长度+16)，每次扩容会变为原来大小的的2倍+2大小。

**StringBuffer**内部是一个动态的char数组，在改变操作上开销较小，由于多数方法使用了同步锁synchronized，虽然是线程安全操作对象，但是效率较低，适用于多线程字符串操作场景

**StringBuilder**内部也是一个动态的char数组，他和StringBuffer的区别是去掉了同步锁，效率得到了20%作用的提示，但是也成了线程不安全对象，适用于大量字符串操作的场景

```java
String内部是一个被final修饰的char[],无法进行修改，在多个String进行拼接时，效率机器的低下。
StringBuffer/Stringbuilder内部是一个没有final修饰的char[]，可以调用append()方法进行字符串修改，当追加的字符串小于char[]的上限时调用System.arraycop()将追加的字符串写入到char[]中，当追加的字符串长度已经大于了char[]的上限，那么就会调用Arrays.copyOf(),创建一个原来数组*2+2大小的新数组来容纳追加的字符串。
```

##### **16.重载与重写**

重载指一个类中存在多个方法名称相同但参数个数、类型、顺序不同的方法(注意：仅返回值不同，或修饰范围不同不能算重载)

重写指子类覆盖实现父类对外公开的方法，父类中private/static/final方法无法被重写。

##### **17.java方法参数是值传递还是引用传递？**

严格来说，java中只有值传递，没有引用传递，所有的实参都是入参来源对象的拷贝值，如果入参是引用对象，则对应的实参就是引用地址的拷贝。

解析：swap方法中调用StringBuilder的append()属于使用拷贝的引用地址去修改引用指向的对象值；而之后的直接赋值是修改拷贝的引用地址的指向，对方法外的a对象无任何影响，同理，b也不会发生变化

##### **18.浅拷贝与深拷贝的区别？**

**浅拷贝**常使当前类实现Cloneable接口，通过显示clone方法实现类对象的拷贝逻辑，但是若类中存在引用对象属性，则拷贝后的引用对象属性和被拷贝对象属性指向同一个引用对象(浅拷贝无法拷贝引用对象属性)

**深拷贝**就是连带引用对象属性都会拷贝的操作，常使用序列化、反序列化操作来实现

```java
public class xxx implements Cloneable, Serializable{
    private static final long serializableUID = 1L;
    private String msg;
    //浅拷贝
    public xxx clone() throws CloneNotSupportedException{
        xxx instance = (xxx)super.clone();
        return instance;
    }
    
    //深拷贝
    public xxx deepClone(){
        //序列化，写入二进制流
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        //FileOutputStream out = new FileOutputStream("/tmp/xxx.ser");
        ObjectOutputStream oos = new ObjectOutputStream(out);
        oos.writeObject(this);
        //反序列化，输出二进制流
        //FileInputStream in = new FileInputStream("/tmp/xxx.ser");
        ByteArrayInputStream in = new ByteArrayInputStream(out.toByteArray());
        ObjecInputStream ois = new ObjecInputStream(in);
        return (xxx)ois.readObject();
    }
}

序列化知识点：
0.序列化通过实现Serializable接口，生成一个serialVersionUID版本号来实现序列化(可以自定义序列化方法：readObject、writeObject、readResolve)
1.序列化实质就是将一个对象转换为一个字节数组，可以进行存储和网络传输
2.反序列化就是将字节反向生成一个java对象的过程(注意：普通反序列化不会执行构造方法)    
3.java内中被static修饰、被@transient标注的属性不会参与序列化
4.java对象中存在其他引用对象成员变量时，该成员变量也必须是序列化的
5.如果想自定义序列化规则，可以通过实现Exterializable接口来实现(该接口反序列化时会执行构造方法)    
6.序列化工具：xml/json/protobuf等    
```

### 三、面向对象和核心要点

##### 19.面向对象与面向过程区别

**面向对象语言**以抽象出逻辑对象为基本操作单位，用对象之间的行为动作进行逻辑处理，有很好的复用性和扩展性，但是对象的创建封装会消耗一部分资源，所以效率会有损失

**面向过程语言**以逻辑顺序为核心，进行代码编写，所以执行效率会很高，但是代码的复用性和扩展性会差一些

##### **20.构造方法的作用？能否被重写重载？**

构造方法是没有返回类型，名称和类名相同的的方法；作用是初始化实例对象，一个类中若不存在任何构造方法，则在编译时，会为类补上无参构造方法，其中无参构造方法常和new关键字用于创建类的实例化对象；构造方法可以被重载，但是不能被子类重写；子类可在构造方法中使用super关键字调用父类的构造方法

##### 21.成员变量和局部变量区别？

**成员变量**：属于类实例变量，生命周期和类实例对象相同，只能被类实例对象调用，可以被public范围/static/final修饰符修饰，在栈空间存放对象的引用，成员变量和类实例在对空间中

**静态成员变量**：当被static修饰时，成员变量属于类变量，能直接通过类名调用该属性，静态成员和类一起在堆中创建

**局部变量**：在方法中定义和使用的变量，只有在方法被调用时才会进行创建，只能被final修饰，栈中创建

##### **22.对象相同和对象引用的关系？**

对象相同指内存空间的内容相同，对象引用相同指指向内存的地址相同

一个对象引用可以指向0个和1个对象，一个对象可以被多个引用同时指向。

##### **23.面向对象特征？**

**封装**，指将一些内容(方法)与行为(属性)写入一个对象(类)中的过程，只有通过对象才能获取到内部的内容和方法

**继承**，指可以将一些对象中相同的部分提取出来，作为一个父对象，其他对象通过继承这个父对象来获取那些共用的内容，这样可以提高代码复用性和扩张性，但是会降低可读性

**多态**，指类可以有多种表示形态存在，通常指继承和接口实现的应用，不同子类继承同一个父类和不同类实现同一个接口，每个子类可以实现各种不同的业务逻辑，但是都对应着父类或接口的相同方法。

##### 24.static、final、this、super关键字

**static**可修饰成员变量、成员方法、代码块、内部类，被static修饰的内容在JVM中会创建在方法区(元空间)的内存中，属于类变量、类方法；能直接通过{类名.xxx}的结构进行调用

**final**可修饰变量、方法、类，被修饰的类不能被继承，被修饰的变量不能被修改，被修饰的方法不能重写

**this**关键字代表当前类的对象实例，不能用于static方法中

**super**关键字代表子类继承父类后，在子类中使用super代表父类对象实例；如果是在子类构造方法中使用super，则super必须在第一行，不能用于static方法

24.1 private/default/protected/public访问权限

| 类型  | private | default | protected | public |
| --- | --- | --- | --- | --- |
| 同一类 | √   | √   | √   | √   |
| 同一包 |     | √   | √   | √   |
| 子类  |     | (父子类同一包下可以，非同一包下不可以) | √   | √   |
| 全部范围 |     |     |     | √   |

##### 25.代码块、静态代码块的执行顺序

代码块是用{}括住的内容，不能被外部访问，通常用于赋值和初始化

第一顺序列：静态变量-->静态代码块按从上到下顺序执行(不能先使用后声明)

第二顺序列：代码块-->构造方法(非静态代码块会在构造方法之前执行)

```java
public class Test {
    static{
        System.out.println("静态代码块1");
    }
    {
        System.out.println("代码块1");
    }
    public static final int a =1;
    static{
        System.out.println("静态代码块2");
    }
    public Test(){
        System.out.println("构造方法");
    }
    {
        System.out.println("代码块2");
    }

    public static void main(String[] args) {
        Test test = new Test();
    }
}

//执行结果：
静态代码块1
静态代码块2
代码块1
代码块2
构造方法
```

##### 26.接口和抽象类区别？

接口可以简单理解为纯粹的抽象类

接口中只能存在静态常量和方法的声明，抽象类除此外还能有非抽象的变量和方法存在

接口通过implements关键字被实现，且可以实现多个接口；抽象类通过extends被继承，只能是单继承

`从设计上讲，抽象类是是一种模板设计，而接口是一种行为的规范`

```
java如何实现多继承？
1.通过多个内部类继承不同父类实现
2.单子类多次嵌套继承不同父类
```

##### **27.异常与错误？**

java中使用了Exception和Error来处理程序中出现的问题，其中Exception是程序运行中出现代码逻辑错误，可以通过异常处理进行兼容修正，如常见的NPE；而Error是程序出现无法处理的问题，无法通过程序进行处理，如内存溢出、超出栈深度等错误。

![image-20200925163149021](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103043.png)

对于可处理的Exception，可以分为两类：一类是可检异常，无论是否出现异常都必须显式做好处理异常操作；还有一类是不可检测异常(RuntimeException)，只有在代码执行过程中才会出现的异常，不需要显式做异常处理

![image-20210413145222743](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210413145231.png)

异常的处理也有两种方式：一是在方法名称后使用`throws XXXException`将异常抛给调用对象去处理；二是使用`try{...}catch(XXXException e){...}finally{...}`结构来处理可能发生异常的代码，其中的catch代码块可以有多个，用于区分不同异常的处理，catch代码块的顺序按子类->父类的顺序排连。无论catch代码块是否触发，都会执行最后的finally代码块，finally块中的代码会在方法return前执行完

```java
//若try代码块中由return语句，那么return的结果会在执行finally前就确定下来，然后再执行finally代码块，但是这并不会改变已经确定的返回值
    public static int getNum(){
        int x = 1;
        try{
            x++;
            return x;
        }finally {
            ++x;
            System.out.println("finally被执行");
        }
    }
//调用该方法打印：
finally被执行
2
//=====================================================
//若try、catch、finally代码块中都有return语句，则以finally块中的return为准
     public static int getNum(){
        int x = 1;
        try{
            x++;
            return x;
        }finally {
            ++x;
            return x;
        }
    }   
//打印3
```

在jdk1.7起后，try/catch提供了try-with-resource机制来简化一些需要关闭对象状态的代码

```java
Connection conn = null;
try{
    conn = dataSource.getConnection();
    //...
}catch(Exception e){
    
}
finally{
    conn.close();
}


//try-with-resource不需要执行close()
//括号里面可写多个资源对象
//try结构执行完成，会自动关闭括号里面的的资源对象
try(Connection conn = dataSource.getConnection();){
    //...
}catch(Exception e){
    
}
```

### 四、其他

##### 28.程序、线程、进程区别？

**程序**是一堆指令代码和数据文件的集合，能够通过对应的执行器使用操作系统的资源空间和CPU的运算完成某个固定的逻辑动作

**进程**是程序在操作系统中执行后，占用系统的资源信息的集合对象，关闭进程就是结束了程序的运行状态，一个程序可以开启多个进程对象

**线程**是进程在使用系统资源的执行单位，又称为轻量级进程，一个进程可以开启使用若干个线程，线程在占用CPU运算器执行指令期间会出现运行、等待、阻塞等状态

##### 29.线程的状态？

一个线程的生命周期是随着指令的执行动态变化的，一般有如下几个状态：

**准备状态**：线程创建好后等待被执行

**执行状态**：正在执行指令中

**等待状态**：等待其他线程释放CPU运算位

**等待超时状态**：等待时间过程导致进入超时状态

**阻塞状态**：线程获取资源中进入资源监听的死循环，等待收到资源信息后回到运行状态

**结束状态**：线程执行完指令后的状态

##### 30.IO流有哪些？

IO流通常指数据传输对象，通常用于读取资源文件、推送资源文件的工作

IO流操作在多个业务场景都有自己的对象，加起来共有好几十个，但是在名称设计上都比较好分类：

按照数据流向可分为input(输入流)、output(输出流)

按照数据流的推送单位可分为(byte stream)字节流和(char stream)字符流

所以排列组合一下可以得到四种IO流基础对象：

字节流：InputStream/OutputStream

字符流：Reader/Writer

```java
//字符流和字节流的区别？
答：按照不同的编码规则(如UTF-8、GBK等)多个字节可以组成一个字符，所以字节流和字符流程只是传输单位不同而已
//为什么有了字节流还要有字符流？
答：因为字符也是由字节组成，而且不同的编码规则类型，组成字符需要的字节也会有差异，使用字节传流输多字符文件时，若不清楚编码类型可能会出现乱码问题，所以多直接使用字符流来传输字符文件
```

在实际使用中以业务场景为区分，每种业务至少有字节流或字符流的一种实现：

**文件操作：**

FileInputStream/FileOutputStream

FileReader/FileWriter

**数组操作：**

ByteArrayInputStream/ByteArrayOutputStream

CharArrayReader/CharArrayWriter

**管道操作：**

PipedInputStream/PipedOutputStream

PipedReader/PipedWriter

**缓存操作：**

BuffedInputStream/BuffedOutputStream

BuffedReader/BuffedWriter

==========================

**对象序列化操作：**

ObjectInputStream/ObjectOutputStream

**数据基础类型操作：**

DataInputStream/DataOutputStream

**字符流/字节流转化操作：**

InputStreamReader/OutputStreamWriter

**打印操作(只有输出)：**

PrintStream/PrintWriter

##### 31.BIO、NIO、AIO？

**BIO**同步阻塞通信(少用)

**NIO**同步非阻塞通信(多用)

**AIO**异步非阻塞通信(实现的不多)