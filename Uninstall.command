#!/bin/zsh
set -e
APP="$HOME/Applications/What File Is This.app"
if [[ -d "$APP" ]]; then
  /bin/rm -rf "$APP"
  echo "已删除：$APP"
else
  echo "未找到已安装的 What File Is This.app"
fi
read -k 1 "?按任意键关闭…"
echo
