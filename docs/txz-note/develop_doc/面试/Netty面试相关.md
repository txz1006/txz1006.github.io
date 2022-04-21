Netty面试相关

Netty面试相关

Netty是一个网络编码工具包、支持很多的网络协议，能很容易的帮我们搭建一个高健壮性的IO出入口。

1.为什么要用Netty？直接用NIO不行吗？

直接使用NIO会有过多的细节需要处理，稍有不慎就核能导致请求出现问题。而直接使用Netty不仅可以简化编码内容，而且能够避免多数的网络编码问题(如：断连重试、包丢失、粘包等问题)

2.Netty的应用场景有哪些？

实现一个RPC框架、实现一个Http服务器、实现一个即时消息通信系统等等

如dubbo、rocketMQ都是用的Netty

3.Netty的主要组件有哪些？

Bootstrap、和ServerBootstrap（客户端和服务端的引导对象）

Channel  (通过对象，一个通道对于一个请求连接)

EventLoop(事件循环)