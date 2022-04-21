linux安装docker

### 1.docker环境安装

访问docker官方文档：https://docs.docker.com/engine/install/centos/

安装步骤，下载依赖：

```sh
sudo yum install -y yum-utils
 sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```

安装docker引擎：

```
sudo yum install docker-ce docker-ce-cli containerd.io
```

启动docker：

```
sudo systemctl start docker
```

出现start-limit问题启动失败

使用下面的命令检测具体问题原因：

```
systemctl status docker.service
journalctl -xe
dockerd
```

修改/etc/docker路径下文件daemon.json(没有就创建)

```
{
    "registry-mirrors": [
       "https://d8b3zdiw.mirror.aliyuncs.com"
    ],
 
    "insecure-registries": [
       "https://ower.site.com"
    ]
}
```

关闭防火墙

```
systemctl stop firewalld
systemctl disable firewalld
```

通过查询image镜像，验证docker是否正常运行

```
docker iamges
```

参考：https://blog.csdn.net/chentaichi6002/article/details/100920771

