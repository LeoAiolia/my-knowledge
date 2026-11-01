#!/bin/sh
# OpenClash 一键恢复脚本 (GL-MT6000 / OpenWrt)
# 用法: sh /tmp/restore_openclash.sh <备份tar路径> <openclash的ipk路径>
# 例:  sh /tmp/restore_openclash.sh /tmp/oc_backup.tar.gz /tmp/luci-app-openclash_0.48.002_all.ipk

TAR="$1"
IPK="$2"

[ "$(id -u)" = "0" ] || { echo "[错误] 请用 root 运行"; exit 1; }
[ -f "$TAR" ] || { echo "[错误] 找不到备份包: $TAR"; exit 1; }
[ -f "$IPK" ] || { echo "[错误] 找不到安装包: $IPK"; exit 1; }

echo "==> [1/6] opkg update"
opkg update || echo "[警告] opkg update 失败，尝试继续（部分依赖可能装不上）"

echo "==> [2/6] 检测防火墙框架"
if opkg list-installed | grep -q '^firewall4'; then
  FW="nftables(fw4)"
  DEPS="bash coreutils coreutils-timeout curl ca-bundle ca-certificates ipset ip-full libcap ruby ruby-yaml unzip kmod-tun kmod-inet-diag kmod-nft-tproxy kmod-nft-socket jsonfilter luci-compat"
else
  FW="iptables(fw3)"
  DEPS="bash coreutils coreutils-timeout curl ca-bundle ca-certificates ipset ip-full libcap ruby ruby-yaml unzip kmod-tun kmod-inet-diag iptables iptables-mod-tproxy iptables-mod-extra iptables-mod-conntrack-extra iptables-mod-ipopt kmod-ipt-nat kmod-ipt-nat6 jsonfilter luci-compat zlib"
fi
echo "    检测到: $FW"

echo "==> [3/6] 确保 dnsmasq-full"
if opkg list-installed | grep -q '^dnsmasq-full'; then
  echo "    已有 dnsmasq-full，跳过"
else
  if opkg list-installed | grep -q '^dnsmasq '; then
    echo "    替换 dnsmasq -> dnsmasq-full"
    opkg remove dnsmasq
  fi
  opkg install dnsmasq-full
fi

echo "==> [4/6] 安装依赖（缺什么装什么）"
for p in $DEPS; do
  if ! opkg list-installed | grep -q "^$p "; then
    echo "    安装 $p"
    opkg install "$p" || echo "[警告] $p 安装失败，继续后面的步骤"
  fi
done

echo "==> [5/6] 安装 OpenClash 并恢复数据"
opkg install "$IPK"
# 注意：备份包内无目录条目且部分文件名含空格，必须整包解压再拷贝，不能按目录名挑选解包
rm -rf /tmp/oc_restore
mkdir -p /tmp/oc_restore
tar -xf "$TAR" -C /tmp/oc_restore
cp -a /tmp/oc_restore/etc/openclash /etc/
cp -a /tmp/oc_restore/etc/config/openclash /etc/config/
rm -rf /tmp/oc_restore
chmod +x /etc/openclash/core/* 2>/dev/null

echo "==> [6/6] 启动服务"
# 备份时 OpenClash 若处于关闭状态(enable=0)，这里自动改为启用，方便启动验证
uci set openclash.config.enable='1'
uci commit openclash
/etc/init.d/openclash enable
/etc/init.d/openclash start

echo ""
echo "全部完成！浏览器打开 LuCI -> 服务 -> OpenClash 查看运行状态。"
echo "如果菜单没出现: rm -f /tmp/luci-indexcache* 然后强制刷新浏览器重新登录。"
echo "如果显示未运行: tail -30 /tmp/openclash.log 查看日志排查。"
