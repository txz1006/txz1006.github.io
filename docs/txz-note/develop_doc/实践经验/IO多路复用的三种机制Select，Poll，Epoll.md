IO多路复用的三种机制Select，Poll，Epoll

## IO多路复用的三种机制Select，Poll，Epoll

[![](https://upload.jianshu.io/users/upload_avatars/11224747/595ff503-0e4f-4752-816b-220ef73ba80d.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/96/h/96/format/webp)](https://www.jianshu.com/u/c2f0d7b9f96b)

82018.05.14 18:22:04字数 3,513阅读 81,914

> I/O多路复用（multiplexing）的本质是通过一种机制（系统内核缓冲I/O数据），让单个进程可以监视多个文件描述符，一旦某个描述符就绪（一般是读就绪或写就绪），能够通知程序进行相应的读写操作

select、poll 和 epoll 都是 Linux API 提供的 IO 复用方式。

相信大家都了解了Unix五种IO模型，不了解的可以 => [**查看这里**](https://www.jianshu.com/p/b8203d46895c)

\[1\] blocking IO - 阻塞IO
\[2\] nonblocking IO - 非阻塞IO
\[3\] IO multiplexing - IO多路复用
\[4\] signal driven IO - 信号驱动IO
\[5\] asynchronous IO - 异步IO

其中前面4种IO都可以归类为synchronous IO - 同步IO，而select、poll、epoll本质上也都是同步I/O，因为他们都需要在读写事件就绪后自己负责进行读写，也就是说这个读写过程是阻塞的。

与多进程和多线程技术相比，I/O多路复用技术的最大优势是系统开销小，系统不必创建进程/线程，也不必维护这些进程/线程，从而大大减小了系统的开销。

在介绍select、poll、epoll之前，首先介绍一下Linux操作系统中**基础的概念**：

- **用户空间 / 内核空间**
    现在操作系统都是采用虚拟存储器，那么对32位操作系统而言，它的寻址空间（虚拟存储空间）为4G（2的32次方）。
    操作系统的核心是内核，独立于普通的应用程序，可以访问受保护的内存空间，也有访问底层硬件设备的所有权限。为了保证用户进程不能直接操作内核（kernel），保证内核的安全，操作系统将虚拟空间划分为两部分，一部分为内核空间，一部分为用户空间。
- **进程切换**
    为了控制进程的执行，内核必须有能力挂起正在CPU上运行的进程，并恢复以前挂起的某个进程的执行。这种行为被称为进程切换。因此可以说，任何进程都是在操作系统内核的支持下运行的，是与内核紧密相关的，并且进程切换是非常耗费资源的。
- **进程阻塞**
    正在执行的进程，由于期待的某些事件未发生，如请求系统资源失败、等待某种操作的完成、新数据尚未到达或无新工作做等，则由系统自动执行阻塞原语(Block)，使自己由运行状态变为阻塞状态。可见，进程的阻塞是进程自身的一种主动行为，也因此只有处于运行态的进程（获得了CPU资源），才可能将其转为阻塞状态。当进程进入阻塞状态，是不占用CPU资源的。
- **文件描述符**
    文件描述符（File descriptor）是计算机科学中的一个术语，是一个用于表述指向文件的引用的抽象化概念。
    文件描述符在形式上是一个非负整数。实际上，它是一个索引值，指向内核为每一个进程所维护的该进程打开文件的记录表。当程序打开一个现有文件或者创建一个新文件时，内核向进程返回一个文件描述符。在程序设计中，一些涉及底层的程序编写往往会围绕着文件描述符展开。但是文件描述符这一概念往往只适用于UNIX、Linux这样的操作系统。
- **缓存I/O**
    缓存I/O又称为标准I/O，大多数文件系统的默认I/O操作都是缓存I/O。在Linux的缓存I/O机制中，操作系统会将I/O的数据缓存在文件系统的页缓存中，即数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的地址空间。

## Select

我们先分析一下select函数

`int select(int maxfdp1,fd_set *readset,fd_set *writeset,fd_set *exceptset,const struct timeval *timeout);`

**【参数说明】**
**int maxfdp1** 指定待测试的文件描述字个数，它的值是待测试的最大描述字加1。
**fd\_set \*readset , fd\_set \*writeset , fd_set *exceptset**
`fd_set`可以理解为一个集合，这个集合中存放的是文件描述符(file descriptor)，即文件句柄。中间的三个参数指定我们要让内核测试读、写和异常条件的文件描述符集合。如果对某一个的条件不感兴趣，就可以把它设为空指针。
**const struct timeval *timeout** `timeout`告知内核等待所指定文件描述符集合中的任何一个就绪可花多少时间。其timeval结构用于指定这段时间的秒数和微秒数。

**【返回值】**
**int** 若有就绪描述符返回其数目，若超时则为0，若出错则为-1

##### select运行机制

select()的机制中提供一种`fd_set`的数据结构，实际上是一个long类型的数组，每一个数组元素都能与一打开的文件句柄（不管是Socket句柄,还是其他文件或命名管道或设备句柄）建立联系，建立联系的工作由程序员完成，当调用select()时，由内核根据IO状态修改fd_set的内容，由此来通知执行了select()的进程哪一Socket或文件可读。

从流程上来看，使用select函数进行IO请求和同步阻塞模型没有太大的区别，甚至还多了添加监视socket，以及调用select函数的额外操作，效率更差。但是，使用select以后最大的优势是用户可以在一个线程内同时处理多个socket的IO请求。用户可以注册多个socket，然后不断地调用select读取被激活的socket，即可达到在同一个线程内同时处理多个IO请求的目的。而在同步阻塞模型中，必须通过多线程的方式才能达到这个目的。

##### select机制的问题

1.  每次调用select，都需要把`fd_set`集合从用户态拷贝到内核态，如果`fd_set`集合很大时，那这个开销也很大
2.  同时每次调用select都需要在内核遍历传递进来的所有`fd_set`，如果`fd_set`集合很大时，那这个开销也很大
3.  为了减少数据拷贝带来的性能损坏，内核对被监控的`fd_set`集合大小做了限制，并且这个是通过宏控制的，大小不可改变(限制为1024)

## Poll

poll的机制与select类似，与select在本质上没有多大差别，管理多个描述符也是进行轮询，根据描述符的状态进行处理，但是poll没有最大文件描述符数量的限制。也就是说，poll只解决了上面的问题3，并没有解决问题1，2的性能开销问题。

下面是pll的函数原型：

```
int poll(struct pollfd *fds, nfds_t nfds, int timeout);

typedef struct pollfd {
        int fd;                         // 需要被检测或选择的文件描述符
        short events;                   // 对文件描述符fd上感兴趣的事件
        short revents;                  // 文件描述符fd上当前实际发生的事件
} pollfd_t; 
```

poll改变了文件描述符集合的描述方式，使用了`pollfd`结构而不是select的`fd_set`结构，使得poll支持的文件描述符集合限制远大于select的1024

**【参数说明】**

**struct pollfd *fds** `fds`是一个`struct pollfd`类型的数组，用于存放需要检测其状态的socket描述符，并且调用poll函数之后`fds`数组不会被清空；一个`pollfd`结构体表示一个被监视的文件描述符，通过传递`fds`指示 poll() 监视多个文件描述符。其中，结构体的`events`域是监视该文件描述符的事件掩码，由用户来设置这个域，结构体的`revents`域是文件描述符的操作结果事件掩码，内核在调用返回时设置这个域

**nfds_t nfds** 记录数组`fds`中描述符的总数量

**【返回值】**
**int** 函数返回fds集合中就绪的读、写，或出错的描述符数量，返回0表示超时，返回-1表示出错；

## Epoll

epoll在Linux2.6内核正式提出，是基于事件驱动的I/O方式，相对于select来说，epoll没有描述符个数限制，使用一个文件描述符管理多个描述符，将用户关心的文件描述符的事件存放到内核的一个事件表中，这样在用户空间和内核空间的copy只需一次。

Linux中提供的epoll相关函数如下：

```
int epoll_create(int size);
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout); 
```

**1\. epoll_create** 函数创建一个epoll句柄，参数`size`表明内核要监听的描述符数量。调用成功时返回一个epoll句柄描述符，失败时返回-1。

**2\. epoll_ctl** 函数注册要监听的事件类型。四个参数解释如下：

- `epfd` 表示epoll句柄
- `op` 表示fd操作类型，有如下3种
    - EPOLL\_CTL\_ADD 注册新的fd到epfd中
    - EPOLL\_CTL\_MOD 修改已注册的fd的监听事件
    - EPOLL\_CTL\_DEL 从epfd中删除一个fd
- `fd` 是要监听的描述符
- `event` 表示要监听的事件

epoll_event 结构体定义如下：

```
struct epoll_event {
    __uint32_t events;  /* Epoll events */
    epoll_data_t data;  /* User data variable */
};

typedef union epoll_data {
    void *ptr;
    int fd;
    __uint32_t u32;
    __uint64_t u64;
} epoll_data_t; 
```

**3\. epoll_wait** 函数等待事件的就绪，成功时返回就绪的事件数目，调用失败时返回 -1，等待超时返回 0。

- `epfd` 是epoll句柄
- `events` 表示从内核得到的就绪事件集合
- `maxevents` 告诉内核events的大小
- `timeout` 表示等待的超时事件

epoll是Linux内核为处理大批量文件描述符而作了改进的poll，是Linux下多路复用IO接口select/poll的增强版本，它能显著提高程序在大量并发连接中只有少量活跃的情况下的系统CPU利用率。原因就是获取事件的时候，它无须遍历整个被侦听的描述符集，只要遍历那些被内核IO事件异步唤醒而加入Ready队列的描述符集合就行了。

epoll除了提供select/poll那种IO事件的水平触发（Level Triggered）外，还提供了边缘触发（Edge Triggered），这就使得用户空间程序有可能缓存IO状态，减少epoll\_wait/epoll\_pwait的调用，提高应用程序效率。

- **水平触发（LT）：**默认工作模式，即当epoll\_wait检测到某描述符事件就绪并通知应用程序时，应用程序可以不立即处理该事件；下次调用epoll\_wait时，会再次通知此事件
- **边缘触发（ET）：** 当epoll\_wait检测到某描述符事件就绪并通知应用程序时，应用程序必须立即处理该事件。如果不处理，下次调用epoll\_wait时，不会再次通知此事件。（直到你做了某些操作导致该描述符变成未就绪状态了，也就是说边缘触发只在状态由未就绪变为就绪时只通知一次）。

LT和ET原本应该是用于脉冲信号的，可能用它来解释更加形象。Level和Edge指的就是触发点，Level为只要处于水平，那么就一直触发，而Edge则为上升沿和下降沿的时候触发。比如：0->1 就是Edge，1->1 就是Level。

ET模式很大程度上减少了epoll事件的触发次数，因此效率比LT模式下高。

## 总结

一张图总结一下select,poll,epoll的区别：

|     | select | poll | epoll |
| --- | --- | --- | --- |
| 操作方式 | 遍历  | 遍历  | 回调  |
| 底层实现 | 数组  | 链表  | 红黑树 |
| IO效率 | 每次调用都进行线性遍历，时间复杂度为O(n) | 每次调用都进行线性遍历，时间复杂度为O(n) | 事件通知方式，每当fd就绪，系统注册的回调函数就会被调用，将就绪fd放到readyList里面，时间复杂度O(1) |
| 最大连接数 | 1024（x86）或2048（x64） | 无上限 | 无上限 |
| fd拷贝 | 每次调用select，都需要把fd集合从用户态拷贝到内核态 | 每次调用poll，都需要把fd集合从用户态拷贝到内核态 | 调用epoll\_ctl时拷贝进内核并保存，之后每次epoll\_wait不拷贝 |

epoll是Linux目前大规模网络并发程序开发的首选模型。在绝大多数情况下性能远超select和poll。目前流行的高性能web服务器Nginx正式依赖于epoll提供的高效网络套接字轮询服务。但是，在并发连接不高的情况下，多线程+阻塞I/O方式可能性能更好。

* * *

*既然select，poll，epoll都是I/O多路复用的具体的实现，之所以现在同时存在，其实他们也是不同历史时期的产物*

- *select出现是1984年在BSD里面实现的*
- *14年之后也就是1997年才实现了poll，其实拖那么久也不是效率问题， 而是那个时代的硬件实在太弱，一台服务器处理1千多个链接简直就是神一样的存在了，select很长段时间已经满足需求*
- *2002, 大神 Davide Libenzi 实现了epoll*

更多精彩内容，就在简书APP

"小礼物走一走，来简书关注我"

还没有人赞赏，支持一下

[![  ](https://upload.jianshu.io/users/upload_avatars/11224747/595ff503-0e4f-4752-816b-220ef73ba80d.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/100/h/100/format/webp)](https://www.jianshu.com/u/c2f0d7b9f96b)

[似水牛年](https://www.jianshu.com/u/c2f0d7b9f96b "似水牛年")知人者智，自知者明&lt;br&gt;qianyang.wang@gmail.com

总资产23共写了7.3W字获得373个赞共118个粉丝

### 被以下专题收入，发现更多相似内容

### 推荐阅读[更多精彩内容](https://www.jianshu.com/)

- 上一篇《聊聊同步、异步、阻塞与非阻塞》\[https://www.jianshu.com/p/aed6067eeac...
    
    [![](https://upload.jianshu.io/users/upload_avatars/2062729/404b7397-cbe2-40cf-8f36-6c8d019c9788.jpeg?imageMogr2/auto-orient/strip|imageView2/1/w/48/h/48/format/webp)七寸知架构](https://www.jianshu.com/u/657c611b2e07)阅读 110,971评论 56赞 403
    
    [![](https://upload-images.jianshu.io/upload_images/2062729-6c2577a9facdef48.png?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/486b0965c296)
- 同步IO和异步IO，阻塞IO和非阻塞IO分别是什么，到底有什么区别？不同的人在不同的上下文下给出的答案是不同的。所...
    
    [![](https://upload-images.jianshu.io/upload_images/6560870-85f799135b9c8153.png?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/15d3b10d7722)
- 本文讨论的背景是Linux环境下的network IO。 一、 概念说明 在进行解释之前，首先要说明几个概念： 用...
    
    [![](https://upload-images.jianshu.io/upload_images/9021696-4d608c5d493b21b1.png?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/fe54ca4affe8)
- 转载：https://cloud.tencent.com/developer/article/1005481提到s...
    
    [![](https://upload-images.jianshu.io/upload_images/9021696-04cc9833a3516cb7.png?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/1838de0d611d)
- 磨难，往往成就一个人物！孤独、苦难，令人格外珍惜温暖！从古到今，很多人可以共患难，却很少人，可以同甘！ 比如，刘邦...
    
    [<img width="24" height="24" src="../../_resources/1766c91b19cd41938cb2c2337d48fb25.jpg"/>徐海宾](https://www.jianshu.com/u/0415ff10cf0a)阅读 132评论 0赞 0