nginx应用-1

#### 一、nginx使用实践

nginx是一个高性能的http服务器，主要用途如下：

1.反向代理项目访问地址

2.反向代理多个项目地址做负载均衡

2.分离项目静态资源和web请求，静态资源使用nginx响应请求

### 

##### 0.安装前置插件

```sh
#安装git
yum -y install git
#下载nginx第三方的支持代理https的模块包(默认在/root文件夹下)
git clone https://github.com/chobits/ngx_http_proxy_connect_module
```

##### **1.下载安装Nginx**

```shell
 #查询是否安装nginx
 nginx -V
 #下载
 wget http://nginx.org/download/nginx-1.16.1.tar.gz
 #解压
 tar -zxvf nginx-1.16.1.tar.gz
 #进入解压目录
 cd nginx-1.16.1
 #配置支持https三方模块
 patch -p1 < /root/ngx_http_proxy_connect_module/patch/proxy_connect.patch
 ./configure --add-module=/root/ngx_http_proxy_connect_module
 #安装nginx
 make && make install
 #启动nginx
 systemctl start nginx.service
 或是执行/usr/local/nginx/sbin/nginx启动
 #设置开机自动启动nginx
 systemctl enable nginx.service
 #访问服务器ip出现Welcome to nginx/centOS即nginx正常工作
```

##### **2.nignx常用命令**

重载nginx配置文件：nginx -s reload

关闭nginx: nginx -s stop

重启nginx：nginx -s reopen

检测配置文件是否正确： nginx -t

##### 3.nginx基本功能

作为一个http服务器，nginx通常被用做反向代理服务器或正向代理服务器，其中的反向代理是经常使用的；这里简单介绍下正向代理和反向代理的概念：

##### **3.1正向代理**：

即客户端通过连接代理服务器来访问目标服务器端；此时服务器端只知道代理服务器访问了项目，而真正的客户端是谁？服务端是不清楚的，所以正向代理中nginx属于客户端侧，客户端对于服务端来说是隐藏的。

我们最常用的正向代理就是通过VPN访问特定的网站项目。

![image-20201110145528394](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110145528.png)

具体实践：

下面使用一台腾讯云服务器来实践正向代理整个过程，按照上面第一节的的步骤在服务器中安装nginx及三方支持https模块，之后在nginx.conf文件中配置正向代理地址信息：

```sh
#配置正向代理访问server
#注意要在防火墙和服务器安全组中开启nginx中使用的端口
    server {
        resolver 8.8.8.8;  #DNS解析地址
        resolver_timeout 5s;
        listen       82;   #此server的访问端口
        proxy_connect;     #开启三方https支持
        proxy_connect_allow            443 563;
        proxy_connect_connect_timeout  10s;
        proxy_connect_read_timeout     10s;
        proxy_connect_send_timeout     10s;

        location / {
          #proxy_pass $scheme://$host$request_uri;
          #proxy_set_header Host $http_host;

          proxy_pass http://$host;   #代理访问客户端地址
          #下面设置代理请求参数  
          proxy_set_header Host $host;


          proxy_buffers 256 4k;
          proxy_max_temp_file_size 0;

          proxy_connect_timeout 30;

          proxy_cache_valid 200 302 10m;
          proxy_cache_valid 301 1h;
          proxy_cache_valid any 1m;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

    }
```

使用nginx -s reload命令重载上文配置信息，之后就可以使用另一台机器来使用这个正向代理地址了：

1.在另一台机器中配置浏览器代理地址为服务器地址和配置的82端口

![image-20201110160113744](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110160113.png)

2.之后使用浏览器搜索本机IP得到代理服务器地址：

![image-20201110160203384](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110160203.png)

此时，通过浏览器访问的网页都是通过nginx正向代理访问的。

参考：https://www.cnblogs.com/flying607/p/6537215.html

##### 3.2反向代理：

即客户端直接访问代理服务器地址，代理服务器会根据请求来映射访问目标服务器；此时客户端只知道访问了代理服务器地址，但是不清楚代理服务器会具体映射访问哪台服务器，所以在反向代理中nginx属于服务器端侧，服务器端对于客户端来说是隐藏的。

![image-20201110150719134](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110150719.png)

具体实践：

再次编辑nginx.conf，配置nginx反向代理server：

```sh
#使用nginx的80端口代理映射服务器本机的8080端口
server {
       listen 80;
       server_name pwb.blog.com;
       location / {
         proxy_pass http://127.0.0.1:8080;
       }

    }
```

使用nginx -s reload命令重载nginx配置，之后使用另一个http服务器在8080端口部署项目，这里直接使用tomcat来作为8080端口的访问项目的服务器。

在启动tomcat服务器后先直接通过tomcat的8080端口来访问项目：

![image-20201110162838371](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110162838.png)

在nginx中配置80 ->8080端口后，可以去掉8080端口，直接通过nginx的80端口来访问项目：

![image-20201110163257767](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110163257.png)

可以在XHR请求列表中找到请求都来自于nginx：

![image-20201110163516358](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110163516.png)

##### 3.3负载均衡

在反向代理中可以为nginx的一个端口地址设置多个服务器来分摊用户请求量，用于减轻服务器压力。

具体配置如下：

```sh
    upstream test.com{
    	#weight是轮询权重，数值越高，访问到对应地址可能就越大
        server 127.0.0.1:8080 weight=1;
        server 127.0.0.1:8081 wegiht=2;

    }

    server {
       listen 82;
       server_name pwb.blog.com;
       location / {
         proxy_pass http://test.com;
         proxy_pass http://test.com;
         proxy_set_header Host $http_host;
         proxy_set_header X-Real-IP $remote_host;
         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

       }

    }

```

使用nginx -s reload命令重载nginx配置，之后访问服务器的82端口：

![image-20201110200031767](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110200038.png)

上图是服务器8081端口的tomcat欢迎页面，多次刷新也可以得到8080端口的项目首页：

![image-20201110200207797](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201110200207.png)

Http转https：

```
server{
   listen 80;
   server_name XXXXX.com;  //你的域名
   rewrite ^(.*)$  https://XXXXXX.com permanent;
   location ~ / {
   index index.html index.php index.htm;
}
}
```

nginx缓存静态资源：

```
    #要缓存文件的后缀，可以在以下设置。
    location ~ .*\.(gif|jpg|png|css|js)(.*) {
        proxy_pass http://ip地址:90;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_cache cache_one;
        proxy_cache_valid 200 302 24h;
        proxy_cache_valid 301 30d;
        proxy_cache_valid any 5m;
        expires 90d;
        add_header wall "hey!guys!give me a star.";
    }
    
    #或者如下配置
    location ~ \.(gif|jpg|png|css|js)$ {
        proxy_pass https://api.17wanxiao.com;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
```

参考：https://www.jb51.net/article/139828.htm

nginx无法启动invalid PID number问题处理：https://blog.csdn.net/weixin_33759269/article/details/92124736

nginx无法识别sll问题处理：https://blog.csdn.net/qq_38011415/article/details/107095429

nginx反向代理示例配置：

```conf

#user  nobody;
worker_processes  1;

error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    proxy_connect_timeout 10;
    proxy_read_timeout 180;
    proxy_send_timeout 5;
    proxy_buffer_size 16k;
    proxy_buffers 4 32k;
    proxy_busy_buffers_size 96k;
    proxy_temp_file_write_size 96k;
    proxy_temp_path /tmp/temp_dir;
    proxy_cache_path /tmp/cache levels=1:2 keys_zone=cache_one:100m inactive=1d max_size=10g;

    #gzip  on;

    server {
        #SSL 访问端口号为 443
        listen 443 ssl; 
     #填写绑定证书的域名
        server_name txz1006.work; 
     #证书文件名称
        ssl_certificate ./1_txz1006.work_bundle.crt; 
     #私钥文件名称
        ssl_certificate_key ./2_txz1006.work.key; 
        ssl_session_timeout 5m;
     #请按照以下协议配置
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2; 
     #请按照以下套件配置，配置加密套件，写法遵循 openssl 标准。
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE; 
        ssl_prefer_server_ciphers on;

        #处理413 Request Entity Too Large
        client_max_body_size 1024m;

        location / {
          proxy_pass   http://127.0.0.1:8090;
        }


        #要缓存文件的后缀，可以在以下设置。
        location ~ .*\.(gif|jpg|png|css|js)(.*) {
                proxy_pass http://127.0.0.1:8090;
                proxy_redirect off;
                proxy_set_header Host $host;
                proxy_cache cache_one;
                proxy_cache_valid 200 302 24h;
                proxy_cache_valid 301 30d;
                proxy_cache_valid any 5m;
                expires 90d;
                add_header wall  "hey!guys!give me a star.";
        }
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #http转https
    server {
        listen       80;
        server_name  txz1006.work;
        rewrite ^(.*)$  https://txz1006.work permanent;
        location ~ / {
            index index.html index.php index.htm;
        }
    }

}

```

halo博客升级：

1.关闭项目命令：service halo stop

2.下载最新jar包：wget https://dl.halo.run/release/halo-XXX.jar -O halo.jar

3.备份原数据(在原halo。jar文件夹中)：cp -r .halo .halo.1.4.7

4.修改vim /etc/systemd/system/halo.service中jar包的名称，保存后执行systemctl daemon-reload

5.测试新的halo.jar是否能正常启动：java -jar halo.jar，Ctrl+C退出项目

6.后台启动项目：service halo start