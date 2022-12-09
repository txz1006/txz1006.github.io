## Arthas（阿尔萨斯）能为你做什么？

`Arthas` 是 Alibaba 开源的 Java 诊断工具，深受开发者喜爱。

当你遇到以下类似问题而束手无策时，`Arthas`可以帮助你解决：

1. 这个类从哪个 jar 包加载的？为什么会报各种类相关的 Exception？
2. 我改的代码为什么没有执行到？难道是我没 commit？分支搞错了？
3. 遇到问题无法在线上 debug，难道只能通过加日志再重新发布吗？
4. 线上遇到某个用户的数据处理有问题，但线上同样无法 debug，线下无法重现！
5. 是否有一个全局视角来查看系统的运行状况？
6. 有什么办法可以监控到 JVM 的实时运行状态？
7. 怎么快速定位应用的热点，生成火焰图？
8. 怎样直接从 JVM 内查找某个类的实例？

### 开始使用Arthas

第一步，下载Arthas，并使用Arthas进入java进程模式

```sh
#下载Arthas，需联外网
curl -O https://arthas.aliyun.com/arthas-boot.jar
#启动Arthas
java -jar arthas-boot.jar
#执行上面的语句后，arthas会列举出可以监控的java进程，比如下面这样
* [1]: 35542
  [2]: 71560 math-game.jar
#我们根据pid选择目标java进程后，输入前面的序号然后回车就可以进入Arthas工作模式了
```

退出Arthas

```sh
#退出当前连接可以使用quit或exit
[arthas@29929]$ quit

#完成退出arthas进程，使用stop命令
[arthas@29929]$ stop

#####需要注意的是，不要在系统高峰期使用arthas，使用完后一定要退出arthas！！！！！！！！！！！！！！！！！！！！！！！！！
```

进程整体监控信息，使用dashboard命令来查看

```sh
[arthas@29929]$ dashboard
```

输入命令回车后，我们会得到这样一个进程监控信息表：

![image-20220906180753746](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202209061807816.png)

按照不同菜单分为三大块，最上面部分是各线程的CPU使用排行，中间一部分是jvm的内存占用情况，最下面的部分是操作系统等依赖环境情况。

```
线程区域
ID： Java级别的县城ID，这个ID不能跟jstack中的nativeID一一对应
NAME: 线程名
GROUP: 线程组名
PRIORITY: 线程优先级，只是JAVA给操作系统建议的一种优先级
STATE:线程的状态
CPU%:线程CPU的使用率。比如采样间隔为1000ms，某个线程的增量cpu时间为100ms，则CPU的使用率=100/1000 = 10%
DELTA_TIME:上次采样之后线程运行增量CPU的时间，单位为秒
TIME:线程运行总CPU时间，数据格式为分:秒
INTERRUPTED:线程当前是否出去中断的状态
DAEMON:是否为守护线程
内存区域
heap：堆内存信息
eden_space：新生代中的eden区占用内存信息
survivor_space：新生代中survivor区占用内存信息
tenured_gen：老年代的内存占用信息
nonheap：非堆的内存占用信息（非堆就是JVM留给自己用的，所以方法区、JVM内部处理或优化所需的内存(如JIT编译后的代码缓存)、每个类结构(如运行时常数池、字段和方法数据)以及方法和构造方法的代码都在非堆内存中）
code_cache：JIT缓存区域占用内存信息
metaspace：元数据区占用内存信息（受操作系统内存大小的限制）
compressed_class_space：指针压缩 用32位的offset代表64位的classpointer
direct：直接内存
mapped：内存映射缓冲区（一般来说频繁读写文件可能导致此区域偏高）
系统信息区域
os.name：操作系统名称
os.version：操作系统版本
java.version：JAVA版本
java.home：JDK路径
systemload.average：平均负载（这个参数的意义暂时未知）
processors：处理器个数
timestamp/uptime：当前时间戳/当前系统启动时间-现在
```

其他命令参数解析：https://blog.csdn.net/lydms/article/details/125238249

### 常用排查的命令

#### jad反编译java类

```sh
##格式
[arthas@29929]$ jad net.newcapec.bsacs.register.impl.CiticBankBsacsService
```

使用jad工具+类的全限定路径名称可以将线上的class文件反编译出来，比如上面的执行结果如下：

```sh
ClassLoader:





  +-java.net.URLClassLoader@2f7c7260
    +-sun.misc.Launcher$AppClassLoader@18b4aac2
      +-sun.misc.Launcher$ExtClassLoader@4c12331b

Location:
/server/apache-tomcat-8.5.5/webapps/b-server/WEB-INF/lib/campus-bsacs-2.4.8-SNAPSHOT-v3.jar

       /*
        * Decompiled with CFR.
        *
        * Could not load the following classes:
        *  com.alibaba.fastjson.JSONObject
        *  javax.servlet.http.HttpServletRequest
        *  net.newcapec.bsacs.register.AbstractBsacsServices
        *  net.newcapec.bsacs.utils.ToolsUtils
        *  org.apache.commons.lang3.StringUtils
        */
       package net.newcapec.bsacs.register.impl;

       import com.alibaba.fastjson.JSONObject;
       import java.net.URLDecoder;
       import java.util.Date;
       import javax.servlet.http.HttpServletRequest;
       import net.newcapec.bsacs.register.AbstractBsacsServices;
       import net.newcapec.bsacs.utils.ToolsUtils;
       import org.apache.commons.lang3.StringUtils;

       public class CiticBankBsacsService
       extends AbstractBsacsServices {
           protected String setPage() {
/*21*/         return "basic";
           }

           protected String getSuZhuConfig() {
/*26*/         return "citicBankApp";
           }

           protected JSONObject doObtainUniqueThirdUserId(JSONObject userDataJson, JSONObject suZhuJson, HttpServletRequest request, Date currentTime) {
/*31*/         JSONObject retjson = ToolsUtils.buildSuccessObj();
               String uid = userDataJson.getString("uid");
/*33*/         if (StringUtils.isBlank((CharSequence)uid)) {
/*34*/             return ToolsUtils.buildErrorObj((String)"用户信息入参uid为空!");
               }
               String sign = userDataJson.getString("sign");
/*37*/         if (StringUtils.isBlank((CharSequence)sign)) {
/*38*/             return ToolsUtils.buildErrorObj((String)"用户信息入参sign为空!");
               }
               Long timeStamp = userDataJson.getLong("timestamp");
/*41*/         if (timeStamp == null) {
/*42*/             return ToolsUtils.buildErrorObj((String)"时间戳参数为空!");
               }
/*44*/         Long interval = Math.abs(System.currentTimeMillis() - timeStamp * 1000L);
               Boolean isTimeOut = interval > this.getPreferenceUtils().getRequestTimeOut() * 1000L;
/*46*/         if (isTimeOut.booleanValue()) {
/*47*/             return ToolsUtils.buildErrorObj((String)"访问超时，或时间已过期!");
               }
               try {
/*51*/             String userInfoId = URLDecoder.decode(uid.replaceAll("MARK", "%"));
/*52*/             String aesKey = suZhuJson.getString("aesKey");
/*53*/             if (StringUtils.isNotBlank((CharSequence)aesKey)) {
                       // empty if block
                   }
/*56*/             this.accessLogManager.save("", Long.valueOf(currentTime.getTime()), Long.valueOf(System.currentTimeMillis()), suZhuJson.getString("flag"), "获取中信银行用户信息：" + uid, "得到用户数据：" + userInfoId, "", "");
/*58*/             String outid = userInfoId;
/*59*/             if (StringUtils.isBlank((CharSequence)outid)) {
/*60*/                 return ToolsUtils.buildErrorObj((String)"获取中信银行用户信息为空!");
                   }
/*62*/             retjson.put("userId", (Object)outid);
               }
               catch (Exception e) {
/*64*/             this.log.error("解析中信银行用户信息异常，uid：" + uid + "报错:{}", (Throwable)e);
                   String error = e.toString() + ":" + e.getStackTrace()[0].toString() + ":" + e.getStackTrace()[1].toString();
/*66*/             this.accessLogManager.save("", Long.valueOf(currentTime.getTime()), Long.valueOf(System.currentTimeMillis()), suZhuJson.getString("flag"), "解析中信银行用户信息异常：" + userDataJson.toJSONString(), "返回报错信息：" + error, "", "");
               }
/*70*/         return retjson;
           }

           protected void setOpenReditectParams(JSONObject userDataJson, JSONObject suZhuJson, String wanxiaoToken) {
/*75*/         super.setOpenReditectParams(userDataJson, suZhuJson, wanxiaoToken);
/*76*/         userDataJson.remove((Object)"uid");
/*77*/         userDataJson.remove((Object)"sign");
/*78*/         userDataJson.remove((Object)"timestamp");
           }
       }


```

#### watch动态监控

watch命令可以动态的打印出指定方法的调用情况，包括入参、返回值、抛出异常和当前实例。

```sh
#常规格式
[arthas@29929]$ watch net.newcapec.bsacs.register.BsacsRegister registerAndBindCardNopwd -x 4
#复杂筛选格式
[arthas@29929]$ watch net.newcapec.bsacs.register.BsacsRegister registerAndBindCardNopwd "{params,returnObj,target,throwExp}" 'params[1]=="100003"' -x 4
#params是指入参数组，可以用params代表第一个入参
#returnObj代表方法返回对象
#target代表当前对象实例
#throwExp代表抛出的异常信息
#params[1]=="100003"代表第二个入参等于100003时才打印日志
# -x 4代表遍历对象深度为4
#开启监控后我们使用100003的入参进行访问就能打印出入参和返回值
method=net.newcapec.bsacs.register.BsacsRegister.registerAndBindCardNopwd location=AtExit
ts=2022-09-07 15:06:06; [cost=287.830668ms] result=@ArrayList[
	##下面是入参
    @Object[][
        @Integer[110],
        @String[100003],
        null,
        @String[100003],
        @String[{"ecardFunc":"index","flag":"basicopengroupautobindecard_ylpayTest","sign":"BD7354A460DABD6D9BD71AAE2A880C19","time":"1662534295355","userid":"100003"}],
        @String[485_100003_bbc8fadf498a4b36b7a7e9cb34037460],
        @String[485],
        @String[bbc8fadf498a4b36b7a7e9cb34037460],
        @String[6D2AA132168045E685B5B6FED0BF9BEC],
        @String[lxh_lhf_zzy],
        @Date[2022-09-07 15:06:05,495],
        @String[basicopengroupautobindecard_ylpayTest_485],
        @Boolean[false],
        @String[basicopengroupautobindecard_ylpayTest],
    ],
    ##下面是方法返回值
    @JSONObject[
        @String[registerSchId]:@Integer[3117],
        @String[customerCode]:@String[485],
        @String[result_]:@Boolean[true],
        @String[error]:@Boolean[false],
        @String[deviceId]:@String[],
        @String[idNo]:@String[100003],
        @String[message_]:@String[成功],
        @String[ecard_customerid]:@String[143],
        @String[customPic]:@String[https://opentest.17wanxiao.com/campus/~/userPic/view/40.jpg],
        @String[nickname]:@String[嫣红认真的白度仪],
        @String[customerId]:@Integer[485],
        @String[ecard_campus]:@String[0],
        @String[stuNo]:@String[100003],
        @String[bindEcard]:@Boolean[true],
        @String[openid]:@String[],
        @String[sex]:@String[女],
        @String[mobile]:@String[bbc8fadf498a4b36b7a7e9cb34037460_485_100003],
        @String[userId]:@Integer[16136629],
        @String[customerName]:@String[中原农业大学公测],
        @String[token]:@String[fb372a3d-9c96-4db8-92a3-7823b219fe2e],
        @String[bindMobile]:@Boolean[false],
        @String[code_]:@Integer[0],
        @String[lastModifyTime]:@Long[1662534296000],
        @String[name]:@String[十万三],
        @String[outid]:@String[100003],
        @String[bindStu]:@Boolean[false],
    ],
    null,
]


```

上面的语法格式是监控XXXClass累的xxxMethod方法，监控打印内容包括入参params、返回值returnObj、抛出异常throwExp，筛选条件是当第一个入参是abc的时候打印数据，-x 3指结果属性遍历深度，默认是1，如果打印结果不够详细，可以增大该参数。

watch支持ognl表达式，如果入参是List<pojo>一类的集合对象，则可以使用下面的格式来设置打印数据

```sh
params[0].get(0).age或者params[0][0].age
#示例
watch Test test params[0].get(0).age -n 1
watch Test test 'params[0][0]["age"]' -n 1
#参数-n 1代表打印的次数
```

也可以只打印几个中的某个一个属性

```sh
params[0].{name}
#示例
watch Test test params[0].{name} -n 1
#打印list集合中所有po的name属性
```

按照某个规则进行过滤

```sh
#按照异常类型进行筛选打印请求日志
#将throwExp对象转为字符串，然后判断字符串是否包含IllegalArgumentException关键词，满足条件才打印
watch demo.MathGame primeFactors '{params, throwExp}' '#msg=throwExp.toString(),#msg.contains("IllegalArgumentException")' -e -x 2

#按照耗时筛选打印日志
watch demo.MathGame primeFactors '{params, returnObj}' '#cost>200' -x 2
```

访问成员变量、静态变量

```sh
#访问MathGame类成员变量illegalArgumentCount
watch demo.MathGame primeFactors 'target.illegalArgumentCount'
#访问静态变量MathGame.propName
getstatic demo.MathGame propName
```

#### 获取方法调用耗时分布

使用trace命令来获取某个方法的执行堆栈和耗时信息

```sh
#格式
#打印一次BsacsRegister.registerAndBindCardNopwd方法的执行时长分析堆栈新
[arthas@29929]$ trace net.newcapec.bsacs.register.BsacsRegister registerAndBindCardNopwd -n 1
#打印结果如下
Affect(class count: 116 , method count: 1) cost in 35671 ms, listenerId: 13
`---ts=2022-09-07 16:16:29;thread_name=http-nio-801-exec-23;id=e3;is_daemon=true;priority=5;TCCL=org.apache.catalina.loader.ParallelWebappClassLoader@6e94cf80
    `---[156.238886ms] net.newcapec.bsacs.register.BsacsRegister:registerAndBindCardNopwd()
        +---[0.02% 0.033882ms ] com.alibaba.fastjson.JSONObject:<init>() #727
        +---[0.01% 0.0132ms ] net.newcapec.v3.extend.orm.condition.Conditions:eq() #729
        +---[3.09% 4.827745ms ] net.newcapec.bsacs.manager.AccountUniqueRecognizeManager:findByCondition() #729
        +---[0.01% 0.0173ms ] net.newcapec.bsacs.entity.AccountUniqueRecognize:getAccountPart3() #771
        +---[86.13% 134.569365ms ] net.newcapec.bsacs.register.BsacsRegister:getWanxiaoInfo() #772
        +---[0.01% 0.021965ms ] com.alibaba.fastjson.JSONObject:getBoolean() #773
        +---[0.01% 0.015833ms ] org.apache.commons.lang3.StringUtils:isBlank() #778
        +---[0.01% 0.01393ms ] net.newcapec.bsacs.entity.AccountUniqueRecognize:setUserInfo() #779
        +---[0.01% 0.010283ms ] net.newcapec.bsacs.entity.AccountUniqueRecognize:setLastUseTime() #781
        +---[0.01% 0.014967ms ] net.newcapec.bsacs.entity.AccountUniqueRecognize:setQq() #782
        +---[10.15% 15.85181ms ] net.newcapec.bsacs.manager.AccountUniqueRecognizeManager:update() #783
        +---[0.01% 0.020459ms ] com.alibaba.fastjson.JSONObject:getBoolean() #786
        +---[0.01% 0.011043ms ] com.alibaba.fastjson.JSONObject:getString() #787
        `---[0.01% 0.01097ms ] com.alibaba.fastjson.JSONObject:put() #799
```

当然我们同样可以使用一些参数来过滤耗时少的无关数据

```sh
#只打印耗时在100ms已上的堆栈信息
[arthas@29929]$ trace net.newcapec.bsacs.register.BsacsRegister registerAndBindCardNopwd '#cost > 100' -n 1
```

如果需要打印jdk中的方法，可以通过设置--skipJDKMethod false参数来显示内部方法信息

```sh
[arthas@29929]$ trace --skipJDKMethod false demo.MathGame run
```

#### 查看jvm各种配置参数信息

```sh
[arthas@29929]$ jvm
#查询内存占用信息
[arthas@29929]$ memory
```

#### 导出dump数据

arthas也内置了导出内存快照的功能，使用的是heapdump命令

```sh
[arthas@58205]$ heapdump /tmp/dump.hprof
#值导出存活对象
[arthas@58205]$ heapdump --live /tmp/dump.hprof
```

#### 动态执行Spring bean对象方法

先通过getstatic获取到SpringBeanUtil类bean中的静态对象application的hashcode值

```sh
[arthas@951]$ getstatic net.newcapec.bsacs.utils.SpringBeanUtils moduleContext
#如果获取到多个同名对象，则可以使用-c命令指定获取的SpringBeanUtils
[arthas@951]$ getstatic -c 51650186 net.newcapec.bsacs.utils.SpringBeanUtils moduleContext
```

然后使用ognl表达式来顶帖调用bean中的方法，或者获取其中的变量

```sh
#获取到redis操作bean bsacsjedisPoolUtils后执行其中的set方法
[arthas@951]$ ognl -c 51650186 '@net.newcapec.bsacs.utils.SpringBeanUtils@getBean("bsacsjedisPoolUtils").set("test0908","666", 10)' 
#获取其中的成员变量pool的内容，并展开3层
[arthas@951]$ ognl -c 51650186 '@net.newcapec.bsacs.utils.SpringBeanUtils@getBean("bsacsjedisPoolUtils").pool'  -x 3
```

如果一个类被加载了多次，则可以通过sc命令来获取其hashcode值

```sh
sc -d net.newcapec.bsacs.register.impl.ABChinaBsacsService
#打印信息的最后一行classLoaderHash就是类的hashcode
classLoaderHash   51650186
```

