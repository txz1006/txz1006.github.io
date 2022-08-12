### ***\*缺少cookie安全属性\****

**漏洞描述：**

平台存在使用不安全的cookie方法的漏洞，js脚本可以读取cookie信息，存在被黑客XSS攻击的风险。

**漏洞位置：**

​	https://hub.17wanxiao.com/login.action

**漏洞证明：**

查看页面cookie属性，secure为false。

![img](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208121511717.jpg) 

**整改建议：**

1） 设置cookie的HttpOnly属性为true

**修复措施：**

在tomcat目录下的conf.web.xml配置文件中的session-config标签中，增加如下cookie-config配置：

```xml
    <session-config>
        <session-timeout>30</session-timeout>
        <cookie-config>
          <http-only>true</http-only>
          <secure>true</secure>
        </cookie-config>
    </session-config>
```

### ***\*中间件版本信息泄露\****

**漏洞描述：**

存在中间件版本信息泄露漏洞，中间件版本泄露可能会暴漏系统中间件版本信息，攻击者可能进行信息收集并对后续的攻击行为起到助力作用。

**漏洞位置：**

https://hub.17wanxiao.com/login.action

**漏洞证明：**

登陆系统，查看返回包，存在中间件版本信息泄露

![img](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208121516324.jpg) 

**整改建议：**

1） 对返回信息中的服务器信息进行模糊化处理。

**修复措施：**

在nginx配置文件nginx.conf中的http模块中使用server_tokens off;配置隐藏版本信息：

```

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    underscores_in_headers on;
    server_tokens off;  #隐藏版本信息配置

    include /etc/nginx/conf.d/*.conf;
}

```

### ***\*跨站请求伪造\****

**漏洞描述：**

攻击者通过伪造用户的浏览器的请求，向访问一个用户自己曾经认证访问过的网站发送出去，使目标网站接收并误以为是用户的真实操作而去执行命令。常用于盗取账号、转账、发送虚假消息等。攻击者利用网站对请求的验证漏洞而实现这样的攻击行为，网站能够确认请求来源于用户的浏览器，却不能验证请求是否源于用户的真实意愿下的操作行为。

**漏洞位置：**

https://hub.17wanxiao.com/login.action

**漏洞证明：**

抓包更改referer字段，正常响应，如下图

![img](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208121531176.jpg) 

**整改建议：**

1） 对Referer进行校验。

2） 添加token字段。

**修复措施：**

在B模块WEB-INF/web.xml中修改hearderFilter滤器拦截路径：

```
 <filter>
        <filter-name>hearderFilter</filter-name>
        <filter-class>net.newcapec.bsacs.web.filter.HearderFilter</filter-class>
    </filter>

    <filter-mapping>
        <filter-name>hearderFilter</filter-name>
          拦截路径由/bsacs/*改为/*
        <url-pattern>/*</url-pattern>
    </filter-mapping>
```

之后登陆B模块系统在参数同步管理中修改bsacs.domain.referer参数为

```
17wanxiao.com,newcapec.cn
```

等等域名(该参数默认为空，为空时不拦截任何请求)

![image-20220812154101789](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208121541878.png)