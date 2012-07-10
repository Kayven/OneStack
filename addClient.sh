#!/usr/bin/env bash
# **addClient.sh** is a tool to deploy an environment to manage OpenStack cloud computing service.

# Hily.Hoo@gmail.com (Kayven)
# Learn more and get the most recent version at http://code.google.com/p/onestack/

set -o xtrace
## 请使用root执行本脚本！
## Ubuntu 12.04 ("Precise") 部署 OpenStack Essex，在client管理OpenStack安装nova管理工具
## 参考：
## http://docs.openstack.org/essex/openstack-compute/starter/content/

## 1、设置root权限
## 为了简单，全部都是用root来运行。

##########################################################################
## 2、自行检查下面network/interfaces的两个网卡设置
ServerControlIP="192.168.139.50"

## token, 登录dashboard密码
ADMIN_TOKEN="admin"
##########################################################################

## 3、安装ntp
apt-get install -y ntp
echo "server $ServerControlIP" > /etc/ntp.conf
service ntp restart

## 4、安装nova
apt-get install -y python-novaclient glance-client swift qemu-kvm

cat <<ENV_AUTH >> /etc/profile
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN
export OS_AUTH_URL="http://192.168.139.50:5000/v2.0/"
ENV_AUTH
sed -i -e "s/ADMIN/$ADMIN_TOKEN/g" /etc/profile
sed -i -e "s/192.168.139.50/$ServerControlIP/g" /etc/profile

## manage via web: http://192.168.139.50 （$ServerControlIP）
## command line:
##  nova list
##  glance index
