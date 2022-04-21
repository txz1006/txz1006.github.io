git是一款免费/开源的分布式版本控制系统.

 github是一个面向开源及私有软件项目的托管平台,因为只支持git作为唯一的版本库格式进行托管.

## 一、git的工作原理图:

![img](https://img2018.cnblogs.com/i-beta/1724937/202002/1724937-20200217155304678-492462344.png)

 

 

workspace:工作区

index/staged:暂存区

repository:本地仓库

remote:远程仓库

workspace首先是add到index上,让后commit到repository,再push到remote.



## 二、基本操作命令：

(1). 返回上一级目录：cd .. (cd 与 .. 之间有一空格)。

(2). 进入某一目录：cd git (进入 git 目录)。

(3). 显示当前路径：pwd。

## 三、git创建文件:

git安装时会自带一个git bash工具，用起来感觉比cmd方便。可今天发现一个问题，用git bash无法创建文件夹和文件。在cmd下，只需要 md+文件夹名 就可以创建一个文件夹，可md在git bash下是无效的命令。

原因是cmd和git bash是两个完全不同的工具，cmd用的是Windows自己的命令，而git bash用的是linux下的命令。

在git bash新建文件夹命令是 mkdir+文件夹名。

### **新建文件有两种方式：**

1，touch+文件名，直接新建一个文件

2，vi+文件名，新建一个文件并进入编辑状态（如果文件已存在，则直接进入编辑状态）

vi其实是linux的一个文本编辑器，所以 vi+文件名 后，其实是进入vi程序了。



## 四、git的运行逻辑:

3步>>>>>>>>>



### 1.创建git仓库.

创建仓库分为2步:

<1>本地是没有库的,从服务器pull库到本地来.

<2>本地有库,上传库到服务器中.



### 2.提交本地代码

<1>git add .  是添加所有当前目录的所有文件

<2>git commit -m “这里是添加注释” :和服务器的代码合并



### 3.拉取远程代码 

\>>> git pull  合并有冲突的代码

(conflict:merger,修改了服务器原来的代码替换成你的代码,这些代码有冲突,是选择你的还是选择原来的,有冲突的时候,会自动修改你写的代码,并保留服务器原来的代码,如果你是要修改服务器的,只要删除自动添加的,再进行2<2>执行下一步步骤就行)

\>>>提交代码 git push



## 五、两种方式clone服务器上的代码库:



### 1)https方式 

通过填写账号和密码就可以clone代码库

cmd例子: git clone https://xxx.xxx



### 2)ssh公钥和私钥方式

先在本地制作公钥和私钥.

cmd例:ssh-keygen -t rsa或者是ssh-key -t rsa -C “可以填任何东西文字一般写邮箱,这段文字就在公钥私钥中文本的最后面”

\>>>解释:ssh-keygen -t rsa是直接制作公钥和私钥 -t是填写加密的标准rsa 按下三层Enter的键可以看见公钥和私钥放在哪里了.(一般在C:\Users\Administrator\.ssh的文件夹中公钥.pub后缀)

 然后在服务器中生成公钥,生成之后,在本地cmd中:git clone git@gitxx.x网址x.git就搞定clone代码库了

 

分支的作用:你的项目进行中遇到了一个问题，解决方案不确定，但是你不希望因此影响到当前的开发，那么你可以为此创建分支，然后在分支上测试你的方案，如果可行那么可以通过合并分支功能将你的更新应用到主干，反之你可以放弃它。



## 六、git常用命令

**git status -s**：查询repo的状态,-s表示short,输出标记有两列,第一列是对staging区域,第二列是working目录

**git log** ：显示每条分支的合并历史

**–oneline –graph**：可以图形化表示分支合并历史

**–author=[author name]**：指定作者提交历史

**git add .** ：帝国添加当前工作目录中的所有文件

**git commit**：提交已经被add进来的改动

 

### git的分支操作命令:



**git branch -b name**：创建分支

**git branch**：查看当前目录的分支

**git branch -d name**：删除分支

**git push origin:name** ：删除远程分支

**git checkout name**：切换分支

**git checkout –file**：撤销修改

**git rm file** ：删除文件

**git log –graph** ：分支情况图



## 七、git新建本地分支与远程分支关联问题：

 1)git在本地新建分支,push到远程服务器上之后,再次pull下来的时候,如果不做出来会报提示要求要up-to-data

所以,git本地新建一个分支后,必须要做远程分支关联.

例子>>

本地新建分支:**git branch -b new_branch**

将本地分支和远程服务器关联:**git branch –set-upstream-to=origin/master new_branch**

　　　　　　　　　　　　(将本地新建的分支new_branch分到服务器的origin/master的分支下)

 

2)跟踪远程的分支

**git branch –set-upstream-to=origin/分支名 分支名**

 

链接：https://blog.csdn.net/smile_lty/article/details/79930560

　　　https://blog.csdn.net/baozhiqiangjava/article/details/79504321