### 一、背景

Struts框架由于发现了新的ognl表达式漏洞，需要升级到最新的2.5.30版本，所以版本变化为2.3.32------>2.5.30。

但是升级后应发一些Struts语法和安全性的兼容问题。

### 二、问题现象1

在Struts框架升级到2.5.30版本后，出现了部分请求不通，返回404页面的情况：

![image-20220520175028896](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202205201752040.png)

这个请求接口的主要业务是这样的：

有业务拦截器Filter截取到对应url请求后，对请求进行改造后直接进行forward跳转。

![image-20220520175115361](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202205201751618.png)

#### **解决方法**

由于Struts2.5对forward跳转进行了严格限制，需要在对应的web FIlter配置中增加如下配置：

![image-20220520175546042](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202205201755145.png)

增加上面的配置后接口请求就可以正常进行forward跳转了。

参考：https://blog.csdn.net/misssprite/article/details/7947103

### 三、问题现象2

在请求后又出现另外一个问题，就是Struts的action配置中，如果使用了通配符{*}来动态访问具体请求，在升级到2.5版本后就不生效了。

![image-20220520180207523](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202205201802604.png)

原因是Struts2.5版本更加严格的限制了动态方法调用，需要进行相关配置，再次开启动态通配符请求地址。

#### **解决方法**

一般有两种做法：

一是在strus.xml中增加相关配置：

```
启用DMI动态方法调用 <constant name="struts.enable.DynamicMethodInvocation" value="true" />
添加SMI严格方法调用中的可用通配符 <constant name="struts.strictMethodInvocation.methodRegex" value="([A-Za-z0-9_$]*)" />
禁用SMI严格方法调用 <package name="default" namespace="/" extends="struts-default" strict-method-invocation="false">
```

二是手动给package和action配置允许动态访问的接口方法

在 struts.xml 的package标签内添加了这个属性：

```
<global-allowed-methods>regex:.*</global-allowed-methods>
```

但是由于v3框架对于struts进行了配置封装，第一种方式进过尝试后发现并无作用，第二种方式无法在v3框架封装的标签中使用，所以最后使用了最直接的方式来解决：

就是不使用通配符，将每个action罗列到请求配置文件中。

![image-20220520181643321](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202205201816393.png)

参考：https://blog.csdn.net/zhixiandianji/article/details/52576742和https://blog.csdn.net/qq_34023135/article/details/78154700