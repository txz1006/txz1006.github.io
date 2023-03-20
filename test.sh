#!/usr/bin/env bash
echo 开始推送项目
currentDir=$(cd "$(dirname "$0")"; pwd)
cd $currentDir


echo 项目推送完成
read -p "任意键继续" x
exit