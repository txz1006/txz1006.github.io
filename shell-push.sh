#!/usr/bin/env bash
echo 开始推送项目
currentDir=$(cd "$(dirname "$0")"; pwd)
cd $currentDir

git add ./
git commit -m "$(date "+%Y-%m-%d %H:%M:%S")"
git push

echo 项目推送完成
read -p "任意键关闭" x
exit