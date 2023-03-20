#!/usr/bin/env bash
echo 开始拉取项目
currentDir=$(cd "$(dirname "$0")"; pwd)
cd $currentDir

git pull

echo 项目拉取完成
read -p "任意键继续" x