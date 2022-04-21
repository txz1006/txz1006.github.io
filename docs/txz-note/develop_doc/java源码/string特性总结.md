string特性总结

#### 一、String特点与常用构造方法

- String是我们常用的字符串操作对象，它的主要属性由一个char数组和一个hashCode数值组成，且都被final关键字修饰；所以直接地看String具备可遍历和哈希查找的功能。

- 在String的诸多构造方法中，有几个需要注意的：String可以将char数组、StringBuffer对象、StringBuilder对象都转换成String类型对象。



#### 二、equals()与compareTo()解析

- equals()方法源于Object对象，String类中重写了equals()，在Object中equals()仅仅判断了两个对象的引用值是否相同；而在String中，equals()方法主要判断两个char数组的长度和是否存在不同的值。

  ```java
  boolean equals(Object anoObject){
      if(this == anoObject){
          return true;
      }
      String anoString = (String)anoObject;
      if(this.value.length == anoString.value.length){
          int valIndex = this.value.length;
          int i = 0;
          while(valIndex-- > 0){
              if(this.value[i] != anoString.value[i]){
                  return false;
              }
              i++;
          }
          return true;
      }else{
      	return false;
      }
  }
  ```

- compareTo()方法用于比较两个对象是否相同，返回两个对象的差值；String中存在A.compareTo(B)，若A小于B则返回负值，若A大于B则返回正值，相等则返回0；

  ```java
  int cpmapreTo(String obj){
      int m1 = this.value.length;
      int m2 = obj.value.length;
      int min = Math.min(m1, m2);
      int k = 0;
      while(k < min){
          if(this.value[k] != obj.value[k]){
              return this.value[k] - obj.value[k];
          }
          k++;
      }
      return m1 - m2; 
  }
  ```

  

  String中，equals()和compareTo()两个都是比较方法，需要注意的是equals()可接受参数为object类型，返回boolean值；compareTo()只接受String参数，返回int值。

- 其他常用方法

  indexOf()=>某子字符第一次出现的索引下标

  lastIndexOf()=>某子字符最后一次出现的索引下标

  length()=>当前字符串的长度

  split()=>按某个子字符将当前字符串截取为数组

  join()=>以某个子字符为分割字符，将字符串数组拼接成字符串

  toLowerCase()=>全字符转小写

  toUpperCase()=>全字符转大写

  replace()=>替换某个子字符

  trim()=>清除字符串首尾的空格

#### 三、string相关问答题

1. String为什么要用final修饰？
2. ==和equals()区别？
3. string的intern方法作用？
4. string与stringBuffer、stringBuilder的区别？

请先思考问题，答案在下方：









==========================================================

1. String被final修饰会使对象无法继承扩展，属性被final修饰会无法修改，目的都是使String保持不变性，保持不变由两个好处：一是安全，定义后都无法修改；二是可缓存，将固定值加入缓存提升性能。

2. 一般情况下，两个对象的引用相同则值也相同，两个对象的值相同而引用不一定相同，==是对比两个对象的引用是否相同，equals()是比较两个对象的值是否相同。

3. String有两种定义方式，一种是直接赋值，另一种是new String()，直接赋值会先去字符串常量池查找是否有相同的值，若有则将引用地址直接指向这个值，若没有则会创建一个常量值，并把引用指向这个值。new String()会先在堆中创建String对象，然后去字符串常量池查找字符串是否有相同的值，若有则将String对象的引用地址直接指向这个值，若没有则会创建一个常量值，并把引用指向这个值。而String的intern方法会获取当前字符串在常量池中的引用。

   ```java
   String a = new String ("hello");
   String b = "hello";
   System.out.printLn(a == b);  //false
   System.out.printLn(a.intern() == b);  //true
   System.out.printLn(a.intern() == a);  //false
   System.out.printLn(b.intern() == b);  //true
   ```
   ![image-20200713172131073](F:\个人\srpingIOC\images\image-20200713172131073.png)


4. 由于String不可变，所以进行字符串操作会降低效率。所以就有了StringBuffer，StringBuffer是内容可变的，通过append()方法可以进行字符串拼接，但是它是线程同步的(方法都被synchronized修饰)，所以效率也不高。之后在JDK1.5后有了StringBuilder，它去掉了synchronized修饰，所以效率会高一些，在非并发的情况下多使用StringBuilder来进行字符串拼接。