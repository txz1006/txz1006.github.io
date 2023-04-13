### Broker启动流程

在前面的学习中我们知道了，NameServer启动的主要流程就是根据配置信息启动了一个Netty服务端，创建了多个不同的线程池，来处理不同场景的业务，大致的结构图如下：

![image-20230413111847170](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131118537.png)

了解了NameServer大致的构成后，下面我们来学习一下BrokerServer的启动流程。

### BrokerStartup入口源码分析

在开始之前，我们先要有一个认知，就是MQ的源码是一帮人写的，那么代码的风格结构肯定是类似的，我们可以不以按照NameServer的解析流程来探索BrokerServer呢？

答案肯定是可以的，如果一套源码的风格过于多变，无论是对于开发者、还是对于使用者来说这都是一个灾难，所以一般而言，只要一个开源框架使用的人不在少数，那么开发规范一定会对代码风格结构有比较严格的要求。

之前我们探索学习NameServer是从**mqnamesrv**脚本开始的，这里我们在BrokerServer的启动流程中肯定也有一个类似的脚本。

我们在**mqnamesrv**脚本所在的distribution模块中进行搜索，发现了一个**mqbroker**的脚本，打开一看，就能看到同样格式的入口信息了：

```
sh ${ROCKETMQ_HOME}/bin/runbroker.sh org.apache.rocketmq.broker.BrokerStartup $@
```

根据mqnamesrv的启动经历，我们看都不用看，runbroker.sh脚本肯定是组织java进程启动命令行的脚本，最后会触发**apache.rocketmq.broker.BrokerStartup**入口类的执行。

我们进入到BrokerStartup类中，就会看到入口的main方法：

![image-20230413113759030](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131137066.png)

和NameServer启动的代码结构几乎一模一样。先通过createBrokerController(args)方法创建一个BrokerController组件，然后在start方法中启动这个组件。

所以这个BrokerController就是BrokerServer服务的最核心类了，我们后面的学习也是围绕的这个对象来进行的。

### BrokerController是如何创建和初始化的

根据之前的经验，我们可以直接去createBrokerController(args)方法看BrokerController组件的创建过程。

