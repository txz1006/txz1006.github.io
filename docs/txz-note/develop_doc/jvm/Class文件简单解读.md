# class文件详解之class中的特殊字符串

特殊字符串包括三种:类的全限定名，字段和方法的描述符，特殊方法的方法名。

# 类的全限定名

比如Object类，在源文件中的全限定名是java . lang . object。而class文件中 的全限定名是将点号替换成“/”，也就是java/ lang/object。源文件中一个类的名字，在class文 件中是用全限定名表述的。

# 描述符

各类型的描述符
对于字段的数据类型，其描述符主要有以下几种
●8种基本数据类型:除long和boolean，其他都用对应单词的大写首字母表示。long 用J表示，boolean用Z表示。
●void: 描述符是V。
●对象类型:描述符用字符L加上对象的全限定名表示，如String类型的描述符为Ljava/ lang/String。
●数组类型:每增加一个维度则在对应的字段描述符前增加-一个[，如一-维数组int[ ]的描述符为[I，二维数组String[][]的描述符为[[Ljava/lang/String。



![img](https://upload-images.jianshu.io/upload_images/16966221-f6d8270b748292f4.png?imageMogr2/auto-orient/strip|imageView2/2/w/1128/format/webp)

描述符

# 字段描述符

字段的描述符就是字段的类型所对应的字符或字符串。
如:
int i中，字段i的描述符就是 I
object o中，字段o的描述符就是 Ljava/lang/object ;
double[][] d中，字段d的描述符就是 [[D

# 方法描述符

方法的描述符比较复杂，包括所有参数的类型列表和方法返回值。它的格式是这样的(参数1类型参数2类型参数3类型... )返回值类型



![img](https://upload-images.jianshu.io/upload_images/16966221-52d4dea502809c35.png?imageMogr2/auto-orient/strip|imageView2/2/w/1122/format/webp)

描述符符号举例说明

# 特殊方法的方法名

类的构造方法和类型初始化方法。
构造方法就不用多说了，至于类型的初始化方法，对应到源码中就是静态初始化块。也就是说，静态初始化块，在class文件中 是以一一个方法表述的，这个方法同样有方法描述符和方法名，具体如下:
●类的构造方法的方法名使用字符串<init>表示
●静态初始化方法的方法名使用字符串<clinit>表示。
galles
●除了这两种特殊的方法外，其他普通方法的方法名，和源文件中的方法名相同。