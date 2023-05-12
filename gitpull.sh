#!/bin/bash
url_NET="https://github.com/chenxinfeng4/multifiber.git"
cd "$(dirname "$0")"
upstream="$url_NET"
if [ -d ./.git/refs/remotes/upstream ]; then
	rmt=set-url
else
	rmt=add
fi

echo -e "欢迎使用\033[33m【LILAB 在线更新器】\033[0m"
echo -e "********************************\033[33m当前版本\033[0m*********************************"
git log --pretty=format:'%C(yellow)%h %C(cyan)%ad %Cgreen<%an>%n%b' --date=short master -1
echo "*"
echo "*"
echo -en "将[更新]、[覆盖]本地工作区，请确定! (继续【\033[41;33my\033[0m】/退出【其它】) : "
read ANS
echo "*"
case $ANS in
	y|Y|yes|YES)
		;;
	bash|sh)
		echo ********************************执行调试*********************************
		bash
		return 1
	;;
	*)
		return 1
		;;

esac

echo -e "********************************\033[33m执行更新\033[0m*********************************"
git remote $rmt upstream $upstream
git fetch upstream
git reset -q --hard upstream/master
echo "*"
echo "*"
echo -e "********************************\033[33m更新版本\033[0m*********************************"
git log --pretty=format:'%C(yellow)%h %C(cyan)%ad %Cgreen<%an>%n%C(blink)%s%n%n%b' --date=short master -1
echo "*"
echo "*"

read -s -n1 -p "按任意键退出 ... "