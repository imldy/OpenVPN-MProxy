# OpenVPN & MProxy 安装程序

**1分钟快速安装OpenVPN和MProxy，可以实现用OpenVPN混淆自己的Host。**

**干净的安装程序，尽可能少的影响到原来的系统**

执行进行安装：

`bash <(curl -s https://raw.fastgit.org/imldy/OpenVPN-MProxy/master/ovmp-install.sh)`

**注意**：目前版本管理防火墙使用的是iptables，而且会清空你原来的防火墙设置，请谨慎使用。

目前仅支持安装TCP协议运行的OpenVPN。

仅在Centos7.4系统上测试过，其他版本待测试中。

