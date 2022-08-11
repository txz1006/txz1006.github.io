现象：域名a.com的系统页面存在一个iframe标签，嵌入了一个b.com的地址页面，结果出现了白屏问题

首先出现的一个问题是iframe的'X-Frame-Options' to 'sameorigin'同源策略问题，具体请了解点击劫持web安全问题。

X-Frame-Options是header的一个参数，如果开发者想保护自己的web页面不会被其他应用以iframe的形式嵌入，那么就可以在response设置这个参数来限制地址栏的url和iframe的src地址必须要属于同一个域名。

![image-20220811161327469](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111613531.png)

X-Frame-Options的具体使用方法，有三个可用的value值：

DENY：页面不能被嵌入到任何iframe或frame中；         

 SAMEORIGIN：页面只能被本站页面嵌入到iframe或者frame中；          

ALLOW-FROM：页面可以被嵌入到任何iframe或frame中。

所以我们设置X-Frame-Options为ALLOW-FROM(或者不设置这个参数)，后就没有上面文档问题了。

然后我们遇到了第二个问题：跨域问题，当前地址栏的url和iframe的src地址属于不同域名，那么就是跨域访问了，会出现下面三类问题

Cookie、LocalStorage 和 IndexDB 无法读取

DOM 无法获得

AJAX 请求不能发送

![image-20220811161404570](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111614613.png)

为了解决这个问题，需要设置Access-Control一类跨域参数：

Access-Control-Allow-Origin 允许哪些域名访问当前请求页面，一般设置为iframe所在域名或者是*

Access-Control-Allow-Credentials 是否允许发送cookies数据，true/false

Access-Control-Allow-Methods 允许跨域能调用哪些方法，一般是POST,GET,DELETE,PUT,OPTIONS

Access-Control-Max-Age 设置跨域请求得到结果的有效期

Access-Control-Expose-Headers 允许跨域获取header哪些信息，一般是x-requested-with,Content-Type,access-control-allow-origin,version-info



参考：https://zhuanlan.zhihu.com/p/159060398
