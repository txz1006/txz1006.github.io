Tomcat源码解析(01)-tomcat架构总览



### 一、Tomcat源码解析：

**章一**

- EndPoint组件进行Socket通信，处理TCP/IP协议

- Processor组件进行Http报文解析，处理Http协议

- 上面两个组件合在一起叫做ProtocolHandler组件做Http解析

- Catalina组件嵌套运行多个servlet应用和ProtocolHandler组件做来回的交互

- 一个tomcat实例也可以称为一个catailina实例

  ![image-20200620202305098](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103620.png)

**章二**

- lifeCycle接口是tomcat中的生命周期管理接口，有init、start、destory等接口方法

  ![image-20200712151839325](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103624.png)

  lifeCycle的调用图：

  ![image-20200712151933197](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103628.png)

- tomcat所有组件的生命周期通过继承lifeCycle接口实现生命周期的管控

- tomcat通过脚本运行Bootstrap.java中的main方法来启动tomcat

- Bootstrap类会通过反射创建一个Catalina对象保存在Bootstrap对象中，并开始引导启动

- Catalina对象创建完成后会调用类中的load()->start()方法开始启动tomcat

- CataLina.load()步骤解析(通过读取server.xml配置初始化各个组件主要是Socket通信相关组件service->Connector)

  ![image-20200620201455565](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103631.png)

- CataLina.start()初始化engine对象，engine会开多个线程作为host对象，在每个host中进行读取部署应用(context)信息，context会加载servlet信息；大致步骤解析(service->container->host->context(部署的应用))

![image-20200620205952826](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103636.png)

endpoint启动NIO通信组件

![image-20200712151204434](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103640.png)

- servlet请求顺序

  org.apache.tomcat.util.net.NioEndpoint.Poller#run(监听请求)
  
  ![image-20200706192136807](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103643.png)
  
  org.apache.tomcat.util.net.NioEndpoint.SocketProcessor#doRun(初步处理监听到的请求)



![image-20200712162453942](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103647.png)

处理请求的mapper机制

![image-20200712162959222](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103651.png)