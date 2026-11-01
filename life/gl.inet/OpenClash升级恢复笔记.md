# GL-MT6000 (OpenWrt) 固件升级 → OpenClash 恢复笔记

> 2026-11-01 重建。所有相关文件统一放在知识库的 `~/sourceTree/my-knowledge/life/gl.inet/` 文件夹里。

## 0. 背景
- 路由器: GL.iNet GL-MT6000，OpenWrt 21.02（GL 4.x，内核 5.4，fw3/iptables，aarch64/arm64）
- 每次固件升级都会清掉 opkg 装的软件包（OpenClash 会消失），但数据可以靠备份恢复
- 思路：升级前备份数据 + 在 Mac 下载好安装包 → 升级后重装软件包 + 还原数据

## 1. 升级前（必做，约 10 分钟）

① SSH 到路由器，打包 OpenClash 数据 + 导出依赖清单（LuCI 备份里的 installed_packages.txt 不可靠）：
```sh
tar -czf /tmp/oc_backup.tar.gz -C / etc/openclash etc/config/openclash
opkg list-installed > /tmp/pkg.txt
```
② Mac 终端拉回本地（scp 必须加 -O，见坑 1）：
```sh
scp -O root@192.168.8.1:/tmp/oc_backup.tar.gz ~/sourceTree/my-knowledge/life/gl.inet/
scp -O root@192.168.8.1:/tmp/pkg.txt ~/sourceTree/my-knowledge/life/gl.inet/
```
③ Mac 下载对应版本 luci-app-openclash ipk 备用（升级后路由器没代理，直连 GitHub 常失败）：
- 先查最新版资产名：https://api.github.com/repos/vernesong/OpenClash/releases/latest
- 下载（Mac 直连不行就走本地代理，加 -x http://127.0.0.1:1082）：
```sh
curl -L -x http://127.0.0.1:1082 -o ~/sourceTree/my-knowledge/life/gl.inet/luci-app-openclash_版本号_all.ipk \
  "https://github.com/vernesong/OpenClash/releases/download/v版本号/luci-app-openclash_版本号_all.ipk"
```
④ 可选：顺手下载最新内核（见第 3 节）

## 2. 升级后恢复 OpenClash

① Mac 传文件到路由器：
```sh
scp -O ~/sourceTree/my-knowledge/life/gl.inet/luci-app-openclash_版本号_all.ipk ~/sourceTree/my-knowledge/life/gl.inet/restore_openclash.sh ~/sourceTree/my-knowledge/life/gl.inet/oc_backup.tar.gz root@192.168.8.1:/tmp/
```
② 路由器 SSH 一键恢复（依赖会自动装）：
```sh
sh /tmp/restore_openclash.sh /tmp/oc_backup.tar.gz /tmp/luci-app-openclash_版本号_all.ipk
```
③ LuCI 菜单里没出现 OpenClash 时（常见，菜单缓存问题）：
```sh
rm -f /tmp/luci-indexcache*
```
然后浏览器强制刷新（Cmd+Shift+R）并退出重新登录 LuCI；还不行就重启路由器。
④ 验证：
```sh
pidof clash                 # 有进程号 = 内核在跑
tail -20 /tmp/openclash.log # 看到 OpenClash Start Successful! = 成功
```
注意：OpenClash 只出现在 LuCI（192.168.8.1/cgi-bin/luci）的"服务"菜单里，GL.iNet 自己的首页面板里没有。

万一脚本不在了，手动恢复的完整命令：
```sh
opkg update
# 依赖（fw3/iptables 固件）。若以后 GL 换成 fw4/nftables 固件：
# 把 iptables 系列换成 kmod-nft-tproxy kmod-nft-socket nftables
opkg install bash coreutils coreutils-timeout curl ca-bundle ca-certificates ipset ip-full libcap \
  ruby ruby-yaml unzip kmod-tun kmod-inet-diag iptables iptables-mod-tproxy iptables-mod-extra \
  iptables-mod-conntrack-extra iptables-mod-ipopt kmod-ipt-nat kmod-ipt-nat6 jsonfilter luci-compat zlib
# GL 固件自带 dnsmasq-full；万一只有 dnsmasq 才需要：opkg remove dnsmasq && opkg install dnsmasq-full
opkg install /tmp/luci-app-openclash_版本号_all.ipk
mkdir -p /tmp/oc_restore && tar -xf /tmp/oc_backup.tar.gz -C /tmp/oc_restore
cp -a /tmp/oc_restore/etc/openclash /etc/
cp -a /tmp/oc_restore/etc/config/openclash /etc/config/
rm -rf /tmp/oc_restore
chmod +x /etc/openclash/core/*
uci set openclash.config.enable='1'; uci commit openclash
/etc/init.d/openclash enable
/etc/init.d/openclash start
```

## 3. 内核更新（可选）

- 查看当前内核版本：`/etc/openclash/core/clash_meta -v`
- 下载地址：https://github.com/MetaCubeX/mihomo/releases
  - Alpha 分支（一直在用的）：tag 为 Prerelease-Alpha，文件 mihomo-linux-arm64-alpha-*.gz
  - 稳定版：tag 为 v1.19.x，文件 mihomo-linux-arm64-v1.19.x.gz
- Mac 下载并解压：
```sh
curl -L -x http://127.0.0.1:1082 -o /tmp/core.gz \
  "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-linux-arm64-alpha-xxxxxxx.gz"
gunzip /tmp/core.gz && scp -O /tmp/core root@192.168.8.1:/tmp/clash_meta.new
```
- 路由器替换：
```sh
/etc/init.d/openclash stop
cp /tmp/clash_meta.new /etc/openclash/core/clash_meta
chmod +x /etc/openclash/core/clash_meta
/etc/openclash/core/clash_meta -v   # 确认新版本号
/etc/init.d/openclash start
```
（也可以在 LuCI → OpenClash → 全局设置 → 版本更新 里一键更新内核，但路由器直连 GitHub 可能卡住）

## 4. 踩过的坑（重要经验）

1. **scp 必须加 -O**：新版 macOS scp 默认走 SFTP 协议，OpenWrt 没有 sftp-server，会报 "ash: /usr/libexec/sftp-server: not found"。
2. **备份 tar 不能按目录名解包**：备份包里只有文件条目、没有目录条目，且有带空格的文件名（"AI Suite" 等）。必须整包解压到临时目录再 `cp -a` 拷贝（restore_openclash.sh 已内置此逻辑）。
3. **Mac 直连 GitHub 时好时坏**：curl 加 `-x http://127.0.0.1:1082` 走本地代理（端口以 scutil --proxy 查到的为准）。
4. **"OpenClash Already Start!" 不代表真的在跑**：以 `pidof clash` 和 /tmp/openclash.log 为准。
5. **stop 时输出 "Command failed: Not found"**：无害提示，忽略。
6. **opkg 覆盖安装新版 ipk = 原地升级**：配置和 /etc/openclash 数据都不会丢。
7. **LuCI 装完新界面菜单不出现**：清 /tmp/luci-indexcache* + 重新登录即可。
8. **新固件 dnsmasq 卡死导致全网 DNS 超时**（2026-11-01 踩到）：固件 1095 上，
   "Dnsmasq 重定向"模式下 dnsmasq 运行几分钟后主循环卡死（netstat 看 53 端口
   Recv-Q 积压 200KB），所有 DNS 超时，但浏览器自带加密 DNS 能用所以表现为
   "Google 能开、GitHub 打不开"。修复：把 OpenClash 的 本地DNS劫持 改为
   **防火墙转发**（uci set openclash.config.enable_redirect_dns='2'），让防火墙
   把 53 端口直接转给 clash:7874，dnsmasq 退出 DNS 链路。LuCI 位置：
   OpenClash → 全局设置 → DNS设置 → 本地DNS劫持 → 防火墙转发。
9. **终端 claude update 卡住的真凶**（2026-11-01 复盘）：曾被诊断为 HTTP/2 问题、
   靠强制 http/1.1 绕过。改为"防火墙转发"修复 DNS 后，未做任何 HTTP 层改动，
   claude update 直接成功。结论：根因大概率是 dnsmasq 卡死导致的 DNS 间歇性
   超时，不是 HTTP/2 本身。**以后终端下载类工具卡死，先用 nslookup 域名 192.168.8.1
   查 DNS 是否秒回，再怀疑协议层。**（注：MSS 钳制规则曾写入
   /etc/openclash/custom/openclash_custom_firewall_rules.sh 但未生效，与本次修复无关）

## 5. 版本记录

- 2026-09-12：第一次升级恢复。固件 GL 4.5.x（OpenWrt 21.02，内核 5.4）；
  OpenClash 0.47.088 → 0.47.156；内核 alpha-gd801e6b → alpha-dca26db（go1.26.8）
- 2026-11-01：第二次升级完成 ✅。固件 r15812+1092 → r15812+1095（仍为 OpenWrt 21.02/fw3）；
  OpenClash 0.47.156 → 0.48.002；内核 alpha-dca26db → alpha-69c1631（go1.26.10）。
  SSH 密钥授权升级后仍在，全程免密完成。
- gl.inet 文件夹内容：restore_openclash.sh、luci-app-openclash_0.48.002_all.ipk、
  clash_meta_69c1631、本笔记；升级前还会有 oc_backup.tar.gz 和 pkg.txt
- 关键路径：/etc/openclash/（订阅在 config/、内核在 core/clash_meta、自定义规则在 custom/）；
  主配置 /etc/config/openclash（订阅链接、端口、模式都在里面）
