springCloud-1(五大组件入门)

#### 一、springCloud基础学习

随着项目复杂度的不断增加，集中式的单体应用已经不太适用于这些大用户量、高复杂度的项目构建，于是在14年开始，微服务架构方案被提了出来，他的核心观点是将一个项目拆分成多个子服务项目，每个子服务独立部署且只需要负责一个业务模块，并搭建集群使服务高可用化，子服务之间可以通过rest或rpc进行服务调用，整个子服务群对外提供统一的访问方式，这样虽然增加开发工作量和后期维护难度，但是系统的扩展容易度和可用性得到很大的提高；

由于微服务的探索还在继续，且没有统一的标准，所以各大公司都或多或是有自己的解决方案；而springcloud是一套开源且成熟落地的分布式服务管控与治理的解决方案，他包含多个组件，用于解决分布式应用上的各种问题。

一般来说，简单的springcloud应用有5大组件：

1.服务注册发现管理组件(eureka、zookeeper)

2.服务调用与负载均衡组件(ribbon、dubbo)

3.服务可用性管理组件(Hystrix)

4.统一路由访问组件(zuul、gateway)

5.统一配置信息组件(config)

微服务应用组件图：

![image-20201118120050980](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118120059.png)

============

需要知道的其他东西：

**CAP理论**：

C：强一致性，指各服务的数据都是最新一致的

A：可用性，指用户访问系统都要有反馈回应，集群中的节点挂了，其他节点可以正常工作

P：分区容错性，指各节点通过网络进行数据通信，但是当网络故障无法通信时，节点会形成多个分区，若短时间内无法恢复通信，就会导致分区之间的数据不一致。

一般来说P是无法避免的，而C、A是不太可能共存，所以在系统设计时，一般要在AP或CP中选择一种设计原则，即要么为了保证一致性降低可用性的要求，或是为了可用性降低数据一致性的要求。

**分布式与集群的区别**：

两者都有对外提供统一的访问途径，但实际上项目都分成了多个服务节点的意思。但集群偏向于同一应用的多个部署服务节点，对外提供一个地址做负载均衡；分布式偏向于一个项目由不同模块的服务节点组成。

##### 1.注册发现中心Eureka

各服务节点需要保证能互相访问通信，就需要有一个统一登记的容器，其他节点可以通过这个容器找到要访问的应用；又因为需要服务都会集群部署，所以需要指定服务的对外名称。

spring cloud Eureka就是这样这样一个登记容器角色，他会记录指向此容器的服务，为彼此提供通信依据。

使用实例参考：eureka组件篇

##### 2.负载均衡Ribbon

服务都注册到Eureka中后，各服务就可以通过注册信息的application.name来访问其他服务的web接口，更关键的是，若是访问的web接口服务部署成集群了，通过application.name访问时还要完成负载均衡的功能，而解决这个问题的就ribbon组件。

通过spring cloud Ribbon和restTemplate，可以完成负载均衡和远程服务访问的功能。

使用实例参考：Ribbon组件篇

##### 3.服务熔断Hystrix

通过ribbon可以访问其他服务集群的web接口，但是若集群中的某个节点故障了，当ribbon的轮询访问时，很可能会访问到这个故障节点，这会导致服务时可用时不可用；所以需要这样一个机制，若若集群中出现故障节点时，需要将这个节点排除在负载列表外，这个逻辑称为熔断；更极端一点，若是整个集群全部故障(雪崩)，需要能返回一个正常的结果，告诉调用者，被调用服务出现问题。

完成这个熔断逻辑的角色就是Hystrix组件。

使用实例参考：Hystrix组件篇

##### 3.5.远程服务通信Feign

feign组件是一个模板化的http请求客户端，他的底层封装了httpclient和okhttp，我们可以通过非常简单调用就可以访问其他服务接口，而在springcloud中，feign组件还集成了ribbon和hystrx，通过简单的几个注解和配置就能实现了ribbon和hystrx的注意功能

使用实例参考：Feign组件篇

##### 3.网关路由管理zuul

当我们已经部署了多个服务节点后，就需要考虑将这些服务的请求URL统一起来，对外提供格式一致的访问路径，这样整个服务群对外就是一个整体了；所以需要一个网关角色，负责将用户请求转发到各个服务节点中，这是最基本的功能，此外，这个网关角色还可以完成一些请求过滤、安全权限验证等功能。

springCloud中解决这个问题就是组件zuul

使用实例参考：Zuul组件篇

##### 4.统一配置管理config

为了使微服务的开发管理更方便，设计者们想到了将所有的配置文件整合到一起统一管理，于是就有了config这样一个组件，他的主要功能是将配置文件和项目进行了分离，想要读取配置文件可以通过config组件中的git地址，从git仓库中读取。

使用实例参考：Config组件篇





##### 5.动态加载配置bus

