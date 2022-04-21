ServerSocketChannel 简析| 并发编程网

[原文链接](http://tutorials.jenkov.com/java-nio/server-socket-channel.html "原文链接")     **作者：**Jakob Jenkov     **译者：**郑玉婷      **校对：**丁一

Java NIO中的 ServerSocketChannel 是一个可以监听新进来的TCP连接的通道, 就像标准IO中的ServerSocket一样。ServerSocketChannel类在 java.nio.channels包中。

这里有个例子：

[view source](#viewSource "view source")

[print](#printSource "print")[?](#about "?")

|     |     |
| --- | --- |
| `01` | `ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();` |

|     |     |
| --- | --- |
| `02` |     |

|     |     |
| --- | --- |
| `03` | `serverSocketChannel.socket().bind(``new` `InetSocketAddress(``9999``));` |

|     |     |
| --- | --- |
| `04` |     |

|     |     |
| --- | --- |
| `05` | `while``(``true``){` |

|     |     |
| --- | --- |
| `06` | `SocketChannel socketChannel =` |

|     |     |
| --- | --- |
| `07` | `serverSocketChannel.accept();` |

|     |     |
| --- | --- |
| `08` |     |

|     |     |
| --- | --- |
| `09` | `//do something with socketChannel...` |

|     |     |
| --- | --- |
| `10` | `}` |

### 打开 ServerSocketChannel

通过调用 ServerSocketChannel.open() 方法来打开ServerSocketChannel.如：

[view source](#viewSource "view source")

[print](#printSource "print")[?](#about "?")

|     |     |
| --- | --- |
| `1` | `ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();` |

### 关闭 ServerSocketChannel

通过调用ServerSocketChannel.close() 方法来关闭ServerSocketChannel. 如：

[view source](#viewSource "view source")

[print](#printSource "print")[?](#about "?")

|     |     |
| --- | --- |
| `1` | `serverSocketChannel.close();` |

### 监听新进来的连接

通过 ServerSocketChannel.accept() 方法监听新进来的连接。当 accept()方法返回的时候,它返回一个包含新进来的连接的 SocketChannel。因此, accept()方法会一直阻塞到有新连接到达。

通常不会仅仅只监听一个连接,在while循环中调用 accept()方法. 如下面的例子：

[view source](#viewSource "view source")

[print](#printSource "print")[?](#about "?")

|     |     |
| --- | --- |
| `1` | `while``(``true``){` |

|     |     |
| --- | --- |
| `2` | `SocketChannel socketChannel =` |

|     |     |
| --- | --- |
| `3` | `serverSocketChannel.accept();` |

|     |     |
| --- | --- |
| `4` |     |

|     |     |
| --- | --- |
| `5` | `//do something with socketChannel...` |

|     |     |
| --- | --- |
| `6` | `}` |

当然,也可以在while循环中使用除了true以外的其它退出准则。

### 非阻塞模式

ServerSocketChannel可以设置成非阻塞模式。在非阻塞模式下，accept() 方法会立刻返回，如果还没有新进来的连接,返回的将是null。 因此，需要检查返回的SocketChannel是否是null.如：

[view source](#viewSource "view source")

[print](#printSource "print")[?](#about "?")

|     |     |
| --- | --- |
| `01` | `ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();` |

|     |     |
| --- | --- |
| `02` |     |

|     |     |
| --- | --- |
| `03` | `serverSocketChannel.socket().bind(``new` `InetSocketAddress(``9999``));` |

|     |     |
| --- | --- |
| `04` | `serverSocketChannel.configureBlocking(``false``);` |

|     |     |
| --- | --- |
| `05` |     |

|     |     |
| --- | --- |
| `06` | `while``(``true``){` |

|     |     |
| --- | --- |
| `07` | `SocketChannel socketChannel =` |

|     |     |
| --- | --- |
| `08` | `serverSocketChannel.accept();` |

|     |     |
| --- | --- |
| `09` |     |

|     |     |
| --- | --- |
| `10` | `if``(socketChannel !=` `null``){` |

|     |     |
| --- | --- |
| `11` | `//do something with socketChannel...` |

|     |     |
| --- | --- |
| `12` | `}` |

|     |     |
| --- | --- |
| `13` | `}` |

**原创文章，转载请注明：** 转载自[并发编程网 – ifeve.com](http://ifeve.com/)**本文链接地址:** [Java NIO系列教程（九） ServerSocketChannel](http://ifeve.com/server-socket-channel/)

[![](../_resources/2add825c4e1448e6ae48591dfa2d1dff.png)](http://ads.cachekit.com/)

![Favorite](../_resources/03997451df6a4ab897e78cbc25ec9237.png "Favorite")![Loading](../_resources/28caa2a0f4734118ab3e3449717bc86a.gif "Loading")[添加本文到我的收藏](http://ifeve.com/server-socket-channel/?wpfpaction=add&postid=5356 "添加本文到我的收藏")

### Related posts:

1.  [Java NIO系列教程（十二） Java NIO与IO](http://ifeve.com/java-nio-vs-io/ "Java NIO系列教程（十二） Java NIO与IO")
2.  [Java NIO系列教程（十） Java NIO DatagramChannel](http://ifeve.com/datagram-channel/ "Java NIO系列教程（十） Java NIO DatagramChannel")
3.  [Java NIO系列教程（二） Channel](http://ifeve.com/channels/ "Java NIO系列教程（二） Channel")
4.  [Java NIO系列教程（三） Buffer](http://ifeve.com/buffers/ "Java NIO系列教程（三） Buffer")
5.  [Java NIO系列教程（七） FileChannel](http://ifeve.com/file-channel/ "Java NIO系列教程（七） FileChannel")
6.  [Java NIO系列教程（十一） Pipe](http://ifeve.com/pipe/ "Java NIO系列教程（十一） Pipe")
7.  [Java NIO系列教程（八） SocketChannel](http://ifeve.com/socket-channel/ "Java NIO系列教程（八） SocketChannel")
8.  [Java NIO系列教程（六） Selector](http://ifeve.com/selectors/ "Java NIO系列教程（六） Selector")
9.  [Java NIO系列教程（四） Scatter/Gather](http://ifeve.com/java-nio-scattergather/ "Java NIO系列教程（四） Scatter/Gather")
10. [Java NIO系列教程（十 五）Java NIO Path](http://ifeve.com/java-nio-path-2/ "Java NIO系列教程（十 五）Java NIO Path")
11. [Java NIO系列教程（五） 通道之间的数据传输](http://ifeve.com/java-nio-channel-to-channel/ "Java NIO系列教程（五） 通道之间的数据传输")
12. [Java NIO系列教程（一） Java NIO 概述](http://ifeve.com/overview/ "Java NIO系列教程（一） Java NIO 概述")
13. [Java 网络教程: ServerSocket](http://ifeve.com/java-network-serversocket-2/ "Java 网络教程: ServerSocket")
14. [Java NIO 系列教程](http://ifeve.com/java-nio-all/ "Java NIO 系列教程")
15. [《Java NIO教程》Java NIO Path](http://ifeve.com/java-nio-path/ "《Java NIO教程》Java NIO Path")