docker容器-安装配置

### 零、docker介绍

docker是一种新的系统部署环境软件，我们可以将项目连带项目运行所依赖的环境打包成一个Image文件(docker执行文件)，之后将Image文件使用docker命令进行执行，则该Image会展开成一个执行的linux容器，容器中的依赖环境和你本地一致，项目同时会启动映射到指定的docker端口。docker可以部署多个linux容器，容器之间会互相独立，每个linux容器是一个独立的进程。

### 一、docker安装

#安装必要依赖组件

```
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
```

#添加docker下载源

```
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

#更新/安装(最新版本)docker-ce

```
sudo yum makecache fast
sudo yum -y install docker-ce
```

#开启docker服务

```
sudo service docker start
```

#验证docker是否安装成功

```
docker version
```

### 二、docker常用命令

#查询可以使用的dcoker-ce版本

```
yum list docker-ce.x86_64 --showduplicates | sort -r
```

#安装指定版本的docker-ce版本

```
sudo yum -y install docker-ce-版本号
```

#从docker仓库中拉取Image文件(和maven类似的仓库)

```
#library是library所在组(默认时可省略)，Image文件名是hello-world
docker image pull library/hello-world
```

**常用操作命令：**

#查询docker中的Image文件

```
docker image ls
```

#删除Image文件

```
docker image rm image文件
```

#运行docker文件，启动容器

```
#执行成功会输出一段话，并停止容器运行
docker container run hello-world
```

#手动停止容器

```
docker container kill (容器id号)
```

#查看正在运行的容器

```
docker container ls
```

#查看所有的容器

```
docker container ls -all
```

#删除容器

```
docker container rm (容器id号)
```

### 三、Image文件的创建和使用

**创建image文件：**

```
#从git上拉取一个项目到本地
git clone https://github.com/ruanyf/koa-demos.git
#cd到项目路径
cd koa-demos
#创建.dockerignore文件写入以下内容(作用：打image包时忽略指定文件)
.git
node_modules
npm-debug.log
#创建打包文件Dockerfile，写入以下内容(配置打包信息)
FROM node:8.4
COPY . /app
WORKDIR /app
RUN npm install --registry=https://registry.npm.taobao.org
EXPOSE 3000
#执行打包命令(注意最后有个点)
docker image build -t koa-demo .
#查看生成的image文件
dockers image ls
```

配置含义如下：

![image-20200822144210881](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103943.png)

**使用image文件生成linux容器：**

```
#启用image，生成并启动容器
docker container run -p 8000:3000 -it koa-demo /bin/bash
#若执行成功则会进入容器环境
root@11111:/app# 
#输入下面内容，执行项目中的js(或者启用容器中的项目)
root@11111:/app# node demos/01.js
#此时可以通过http://localhost:8000端口访问容器项目，这里的koa-demo项目没有设置路由会出现NotFound的情况
===================================
#停止node进程
按下ctrl+C
#退出容器环境
按下ctrl+D
#停止容器运行
docker container kill (容器id)
```

容器启用命令含义：

![image-20200822150850691](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103938.png)

### 四、发布image给其他人使用

当生成image文件后，就可以将image文件推到docker仓库供其他人下载使用了

1.去 [hub.docker.com](https://hub.docker.com/) 或 [cloud.docker.com](https://cloud.docker.com/) 注册一个账户后

在本地使用如下命令：

```
#登陆docker账号
docker login
#给image文件标注用户名和版本(docker image tag [imageName] [username]/[repository]:[tag])
docker image tag koa-demos:0.0.1 ruanyf/koa-demos:0.0.1
#发布到仓库
docker image push [username]/[repository]:[tag]
```

之后在 [hub.docker.com](https://hub.docker.com/) 或 [cloud.docker.com](https://cloud.docker.com/)的账号下可以看到已发布的image文件

### 五、其他

**使用CMD命令可以直接将项目启动命令写入Dockerfile：**

```
FROM node:8.4
COPY . /app
WORKDIR /app
RUN npm install --registry=https://registry.npm.taobao.org
EXPOSE 3000
CMD node demos/01.js
```

![image-20200822152022858](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103934.png)

**其他常用命令：**

1. 启动停止的容器`docker container start`

前面的`docker container run`命令每执行一次，都会创建一个容器，而`docker container start`用来启动已经生成、已经停止运行的容器文件

2. 停止运行的容器`docker container stop`

前面的`docker container kill`命令会终止容器运行，属于强行停止，而`docker container stop`则会执行一些关闭操作后才停止容器

3. 进入正常执行的容器环境`docker container exec`

若执行docker run没有使用-it参数映射shell时，就可以使用这个命令进入容器中，一旦进入了容器，就可以在容器的 Shell 执行命令了

4. 将容器中的文件复制出来`docker container cp`

```bash
docker container cp [containID]:[/path/to/file] .
```



#### **在windows上安装docker**

**一、准备环境**

win10专业版系统首先需要开启硬件虚拟化及Hyper-V功能，才能进行Docker for Windows软件安装。

我们在控制面板中开启Hyper-V和容器系统功能(注意windows家庭版没有该选项，需要升级)

![image-20220416165347508](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202204161654989.png)

**二、按照客户端**

Docker默认安装在C盘中，这样慢慢会导致C盘空间越来越小，建议把Docker安装到D盘。

先创建"D:\Program Files\Docker"目录。

然后在Windows中更改Docker默认安装路径方法：
1.先创建 D:\Program Files\Docker 目录。
2.开始—“Windows系统”—“命令提示符”，一定要以管理员身份运行，然后，再运行如下命令：

mklink /J "C:\Program Files\Docker"  "D:\Program Files\Docker"
1
运行结果：
为 C:\Program Files\Docker <<===>> D:\Program Files\Docker 创建的联接

![image-20220416165435686](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202204161654736.png)



然后我们其官网https://docs.docker.com/desktop/windows/install/下载Docker for Windows软件客户端

如果速度过慢可以在[阿里云](https://cr.console.aliyun.com/)注册一个账号，选择“镜像加速器”后，在右侧选择“Windows”,如下图，下载安装Docker稳定版即可

![image-20220416165648038](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202204161656136.png)

按照完成后出现wsl报错问题：

![image-20220416165833828](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202204161658877.png)

通过下载最新WSL更新包后解决问题：

https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

**三、配置国内镜像地址**

在系统右下角托盘图标内右键菜单选择 Settings，打开配置窗口后左侧导航菜单选择 Docker Daemon。编辑窗口内的JSON串，填写下方加速器地址（这个地址是阿里云账号的个人镜像地址）：

```
{
  "registry-mirrors": ["https://670gn9g6.mirror.aliyuncs.com"]
}
```

编辑完成后点击 Apply 保存按钮，等待Docker重启并应用配置的镜像加速器。



