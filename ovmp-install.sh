#!/bin/bash

PASSFILE="/etc/openvpn/psw-file"

# 获取OpenVPN输入端口
getVPNPort() {
  # -n 不换行
  echo -n "输入OpenVPN输入端口(默认1194):"
  read vpnport
  # [-z string] “string”的长度为零则为真
  if [ -z $vpnport ]; then
    vpnport=1194
  fi
  return ${vpnport}
}

# 获取MProxy输入端口
getMport() {
  echo -n "输入http-proxy(MProxy)输入端口(默认8080):"
  read mpport
  if [ -z $mpport ]; then
    mpport=8080
  fi
  return ${mpport}
}

# 获得网卡名
getNetworkAdapter() {
  NA0=$(ifconfig)
  NA1=$(echo ${NA0} | awk '{print $1}')
  NA=${NA1/:/}
  echo -e "系统检测到的网卡为："${NA}"\033[0m"
  read -p "直接回车代表系统检测正确
  否则请输入N并按回车" determineNA
  if [ -z $determineNA ]; then
    echo "确定选择网卡"
  else
    read -p "请手动输入你的网卡名，不知道可以退出脚本在命令行输入'ifconfig'查看：" NA
  fi
}

selectCertificateSource() {
  echo "请选择证书来源"
  echo " 1. 使用dingd.cn证书（兼容大多数流控）"
  echo " 2. 生成新的证书（更安全）"
  read -p "选择[1]: " source
  [[ -z "${source}" ]] && source=1
  return ${source}
}
closeSeLinux() {
  echo "正在关闭Selinux....."
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}

changeFirewall() {
  echo "防火墙改为使用iptables"
  systemctl stop firewalld.service
  systemctl disable firewalld.service
  systemctl stop iptables.service
  yum -y install iptables iptables-services
  systemctl start iptables.service
  #清空iptables防火墙配置
  iptables -F
  service iptables save
  systemctl restart iptables.service

  iptables -A INPUT -s 127.0.0.1/32 -j ACCEPT
  iptables -A INPUT -d 127.0.0.1/32 -j ACCEPT
}
# 打开协议类型和单个端口
openPort() {
  iptables -A INPUT -p $1 --dport $2 -j ACCEPT
}

setNetWorkOutput() {
	iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ${NA} -j MASQUERADE
}

# 修改系统设置
changeSysctl() {
  echo "开启数据包转发"
  NEW_STR="net.ipv4.ip_forward = 1"
  echo ${NEW_STR} >> sysctl.conf
  sysctl -p
}
# 安装openvpn
installOpenVPN() {
  # 先安装epel
  yum -y install epel-release
  yum -y install openvpn
}

setOpenVPNConf() {
  cd /etc/openvpn
  wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/server.conf
  sed -i "s/1194/$1/g" server.conf

}

# 设置OpenVPNC证书
setOpenVPNCertificate() {
  cd /etc/openvpn
  if [ $1 == "1" ]; then
    # 如果是使用dingd.cn证书
    mkdir "dingd.cn"
    cd "dingd.cn"
    wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/easy-rsa/keys/ca.crt
    wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/easy-rsa/keys/server.crt
    wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/easy-rsa/keys/server.key
    wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/easy-rsa/keys/dh2048.pem
    wget https://raw.fastgit.org/imldy/OpenVpnControl/dev_SimpleInstall/dependence/openvpn/easy-rsa/keys/ta.key
  else
    # 如果是选择生成新的证书
    echo "暂未实现"
  fi
}

downloadCheckpsw() {
  cd /etc/openvpn
  wget https://raw.fastgit.org/imldy/openvpn-checkpsw/main/checkpsw.sh
  # 给其执行权限
  chmod +x checkpsw.sh
}
#运行OpenVPN
runOpenVPN() {
  systemctl start openvpn@server
}

installMProxy() {
  cd /etc/openvpn
  # 下载mproxy
  wget https://raw.fastgit.org/imldy/mproxy/master/mproxy.c
  # 修改转发到的端口
  sed -i "s/443/$1/g" mproxy.c
  # 编译
  gcc -o mproxy mproxy.c
}

runMProxy() {
  /etc/openvpn/mproxy -l $1 -d >/dev/null 2>&1
}

clientSoftwareIntroduction() {
  echo "关于客户端软件
  包括但不限于以下软件可以使用，客户端软件与本脚本无关"
  echo "安卓:"
  echo "  OpenVpn Connect 或 OpenVPN for Android 等"
  echo "IOS:"
  echo "  OpenVpn Connect 等"
  echo "Windows:"
  echo "  OpenVPN GUI 等"
  echo "更多客户端软件请自行搜索"
}

# 安装
install() {
  # 接收VPN端口和代理端口的输入
  getVPNPort
  # 不知为何，如果这里接收来自于函数的返回值，其值不是函数返回的
  # 而且比较有规律，例如1194会变为170，8080会变为144。三位数则原样返回
  #  vpnport=$?
  echo -e "已获取到OpenVPN输入端口:\033[32m${vpnport}\033[0m"
  getMport
  #  mpport=$?
  echo -e "已获取到http-proxy输入端口:\033[32m${mpport}\033[0m"
  # 获得网卡名
  getNetworkAdapter
  # 获得证书来源
  selectCertificateSource
  certSource=$?
  # 关闭SeLinux
  closeSeLinux
  # 修改防火墙为iptables
  changeFirewall

  # 防火墙打开对应端口
  openPort "TCP" ${vpnport}
  openPort "TCP" ${mpport}
  # 设置流量输出网卡
  setNetWorkOutput
  # 修改系统设置为net.ipv4.ip_forward=1
  changeSysctl
  # 安装OpenVPN
  installOpenVPN
  # 设置OpenVpn配置文件
  setOpenVPNConf ${vpnport}
  # 给OpenVPN设置证书
  setOpenVPNCertificate ${certSource}
  # 下载账户密码验证的脚本
  downloadCheckpsw
  # 运行OpenVPN
  runOpenVPN
  # 添加一个用户
  addUser
  # 下载安装MProxy，设置要转发到的端口
  installMProxy ${vpnport}
  # 运行MProxy，监控前面设置的端口
  runMProxy ${mpport}

  clientSoftwareIntroduction

}

addUser() {
  read -p "请输入要添加的用户名和密码，中间以空格分隔: " usernameandpsd
  echo ${usernameandpsd} >>${PASSFILE}
  if [ $? == 0 ]; then
    echo "添加成功"
  else
    echo "添加失败，请手动检查${PASSFILE}文件与其所在目录"
  fi
}

Menu() {
  printf "功能菜单: \n"
  printf " 1. 安装(install)\n"
  printf " 2. 添加用户(add user)\n"
  printf " 3. 打开端口(open port)\n"
  printf " 9. 卸载(uninstall)\n"
  printf " 0. 退出\n"
  printf "请选择并回车: "
  read option
  return ${option}
}
Introduce() {
  # printf "OpenVPN[用户名密码认证] + MProxy 安装程序\n"
  printf "OpenVPN & MProxy 安装程序\n"
  printf "干净的安装程序，尽可能少的影响到原来的系统\n"
}
# 介绍项目
Introduce
# 显示菜单
Menu
# 获取菜单函数返回的选项
option=$?
# 判断并执行相应的语句
if [ ${option} == 1 ]; then
  install
elif [ ${option} == 2 ]; then
  addUser
fi
