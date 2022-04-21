[Nginx配置SSL证书](https://www.cnblogs.com/zeussbook/p/11231820.html)

本文主要记录Nginx怎么配置SSL证书，前提是Nginx安装成功和SSL证书已经获取。

在我们下载的证书文件中有一个Nginx的文件夹，这里面的两个文件都是需要的。我们需要把这个两个文件上传到 linux 服务器中，推荐放到`/etc/ssl/`目录下

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723142514117-1607557032.png)

然后我们需要去找到nginx的配置文件。 

```
ps -ef | grep nginx
```

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723142941295-878714709.png)

可以看到 nginx的目录是 /usr/local/nginx

那么我们需要找到 nginx.conf文件并修改

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723143439212-1495408644.png)

```
cd /usr/local/nginx/conf
vim nginx.conf
```

我们需要在 http 中去添加一个server节点，如下所示。如果你不习惯在linux中修改，把nginx.conf这个下载到本地修改完成再上传也是一样的。

如果用户使用的是http协议进行访问，那么默认打开的端口是80端口，所以我们需要做一个重定向，我们在上一个代码块的基础上增加一个server节点提供重定向服务。

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
http{
    #http节点中可以添加多个server节点
    server{
        #监听443端口
        listen 443;
        #对应的域名，把baofeidyz.com改成你们自己的域名就可以了
        server_name baofeidyz.com;
        ssl on;
        #从腾讯云获取到的第一个文件的全路径
        ssl_certificate /etc/ssl/1_baofeidyz.com_bundle.crt;
        #从腾讯云获取到的第二个文件的全路径
        ssl_certificate_key /etc/ssl/2_baofeidyz.com.key;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;
        #这是我的主页访问地址，因为使用的是静态的html网页，所以直接使用location就可以完成了。
        location / {
                #文件夹
                root /usr/local/service/ROOT;
                #主页文件
                index index.html;
        }
    }
    server{
        listen 80;
        server_name baofeidyz.com;
        rewrite ^/(.*)$ https://baofeidyz.com:443/$1 permanent;
    }
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

 

万事俱备，只欠重启。

```
/usr/local/nginx/sbin/nginx
```

结果一重启，duang~出错了。

nginx:[emerg]unknown directive ssl，就是这个错误提示

因为我们配置这个SSL证书需要引用到nginx的中SSL这模块，然而我们一开始编译的Nginx的时候并没有把SSL模块一起编译进去，所以导致这个错误的出现。

1：我们先来到当初下载nginx的包压缩的解压目录，如果你是看小编写的教程安装的，解压目录应该在“/data/”目录下。

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723151201512-1886195869.png)

 

2：来到解压目录下后，按顺序执行一下命令：

```
cd /data/nginx-1.10.1 //这个命令是进入下载解压的 nginx 文件夹，看你的实际路径

./configure --with-http_ssl_module
```

 重新添加这个ssl模块

 注： 执行以上一条命令出现这个错误（./configure：错误：SSL模块需要OpenSSL库。），原因是因为缺少了OpenSSL，那我们再来安装一个即可执行：yum -y install openssl openssl-devel 等待OpenSSL的安装完成后，再执行./configure

 

3：执行make命令，但是不要执行make install，因为make是用来编译的，而make install是安装，不然你整个nginx会重新覆盖的。

```
make
```

 

4：在我们执行完做命令后，我们可以查看到在nginx解压目录下，objs文件夹中多了一个nginx的文件，这个就是新版本的程序了。首先我们把之前的nginx先备份一下，然后把新的程序复制过去覆盖之前的即可。

```
cp /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx.bak //备份，备份则不用执行

cp objs/nginx /usr/local/nginx/sbin/nginx
```

出现错误，删除掉/usr/local/nginx/sbin/下的 nginx 再复制过去即可

 

5：最后我们来到Nginx安装目录下，来查看是否有安装ssl模块成功。执行

```
cd /usr/local/nginx/

./sbin/nginx -v
 
```

即可看到如下图：

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723152931879-238022867.png)

最后如果出现如上图，则SSL模块添加到Nginx的编译好了

 

6：第二次配置证书重启的时候，报错

```
nginx: [emerg] bind() to 0.0.0.0:443 failed (98: Address already in use)
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```

杀掉占用443和80的进程就好了

```
fuser -k 443/tcp
fuser -k 80/tcp
```

 

重新启动则OK了。

![img](https://img2018.cnblogs.com/blog/1243133/201907/1243133-20190723153725391-161186361.png)