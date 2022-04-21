- git初始化命令：git init
- git拉起远程文件：git clone http://XXXX
- git添加文件(夹)索引到暂存区：git add ./
- git删除文件：git rm <文件名>
- git删除文件夹：git rm -f <文件夹名>/
- git提交暂存区文件到本地仓库：git commit -m '提交日志'
- git关联服务器端git地址：git remote add origin https://XXXX.git
- git推送本地仓库到服务器主分支(-u选择分支后，之后推送可以省略-u及分支信息)：git push -u origin main
- git拉取服务器新文件到本地：git pull -u origin main
- git切换本地仓库的分支(没有则会新建)：git checkout -b XXX-tree
- 创建空文件：touch README.md
- git查看项目当前分支的版本号：git rev-parse HEAD
- 删除本地分支(-D是强制删除)：git branch -d <分支名称>
- 删除远程分支：git push origin --delete <branch_name>
- 恢复删除的分支：git branch <分支名称> <分支对应的hash值>
- git退回到某个之前版本：首先我们需要知道退回到哪个具体的版本，这个需要到github或gitlab中的当前分支提交记录里面寻找要退回到的版本号，例如：

![image-20211112093619335](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111120936732.png)

然后我们将这个字符串复制下来，在本地项目的git命令窗口中执行如下命令：

```
git reset --hard XXXXXX(就是复制的版本号)
```

执行过后，我们可以使用git rev-parse HEAD，验证一下本地项目是否已经退回到了目标版本号的状态，如果没有问题了。就使用git push -f 强制提交(不用实际提交任何文件)，将本地项目状态提交到github或gitlab中。

- git修改提交：如果在某次git提交后，发现有一些小的地方需要修改，但是又不想再提交一次git记录，这里就可以使用git commit --amend修改上一次提交，将两次提交合并为一次提交。如果你不满意上次的提交，可以修改掉之前写的日志。(在push到远程分支前使用)

- 在本地创建新分支，提交到远程： 

  在本地创建新分支branch1 ：git checkout -b branch1 

  提交到远程的新分支中：git push --set-upstream origin branch1



- 
