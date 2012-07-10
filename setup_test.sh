#!/usr/bin/env bash
# **setup_test.sh** is a tool to deploy test and real OpenStack cloud computing service.

# This script add an image and an instance to OpenStack for test.

# Hily.Hoo@gmail.com (Kayven)
# Learn more and get the most recent version at http://code.google.com/p/onestack/

set -o xtrace
## 请使用root执行本脚本！
## Ubuntu 12.04 ("Precise") 部署 OpenStack Essex
## 参考：
## http://docs.openstack.org/essex/openstack-compute/starter/content/




## 一：部署基本系统
## ./setup_base.sh




## 二：下载镜像并上传
## ubuntu官方专门提供image，http://uec-images.ubuntu.com。不过一定要注意
## 这些镜像，都是必须使用密钥登录，直接用用户名密码是无法的登录的。
## 下载镜像
## http://cloud-images.ubuntu.com/precise/current/

## 1 这应该是ubuntu提供的最新的稳定的镜像。
wget http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img

## 2 如果本地镜像，放到本目录，名字改为precise-server-cloudimg-amd64-disk1.img，或者将下面镜像地址改为本地地址


## 3 如果scp，使用下面的方法
##  expect -c "spawn /usr/bin/scp  yuan@192.168.139.84:/home/yuan/precise-server-cloudimg-amd64-disk1.img .; expect {
##     \"password:\"; {
##    send \"yyhu\r\n\";
##    }; \"Are you sure you want to continue connecting (yes/no)?\" {
##    send \"yes\r\n\" ;
##    expect \"password:\";
##    send \"yyhu\r\n\";
##    }
##  } ; set timeout -1; expect -re \"100%\";"



## 三：创建第一个VM，可以通过上面安装的web管理系统创建。

# 0：同步数据库
## 以前我运行同步数据库，如果正确, 当nova.conf
## --verbose=False
## 是没有任何的输出，否则有一堆是输出。
nova-manage db sync

# 创建网络
nova-manage network create private --fixed_range_v4=10.0.0.1/27 --num_networks=1 --bridge=br100 --bridge_interface=eth1 --network_size=32

## 设定floating IP
nova-manage floating create --ip_range=192.168.139.225/27

## 设置权限
chown -R nova:nova /etc/nova
## 再重启相关服务
for a in libvirt-bin nova-network nova-compute nova-api nova-objectstore nova-scheduler novnc nova-volume nova-consoleauth; do service "$a" restart; done
sleep 10
 
## 1：检查nova服务
## 一路回车，就可以了。通过expect可以不用输入。
if [ ! -e ~/.ssh/id_rsa ]; then
expect -c "spawn ssh-keygen ; set timeout 5; expect \":\"; send \"\r\n\"; set timeout 3; expect  \":\"; send \"\r\n\";set timeout 3; expect \":\"; send \"\r\n\"; expect eof;"
fi
## 2：上传密钥到数据库
nova keypair-add --pub_key ~/.ssh/id_rsa.pub key1
## nova keypair-list


## 打开防火墙
nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0


## 4：开始创建虚拟机
## nova image-list
## nova flavor-list
## 创建虚拟机
# nova-manage flavor create --name=m1.minitest --memory=384 --cpu=1 --root_gb=1 --flavor=6 --ephemeral_gb=1
glance add name="Ubuntu12.04-amd64" is_public=true container_format=ovf disk_format=qcow2 < precise-server-cloudimg-amd64-disk1.img
nova boot --flavor 1 --image "Ubuntu12.04-amd64" --key_name key1 cloud01
# nova show cloud01
# nova console-log cloud01

##关联vm
sleep 10
## nova floating-ip-create
## nova add-floating-ip cloud01 192.168.139.226
nova show cloud01
nova add-floating-ip cloud01 `nova floating-ip-create | awk 'FNR==4{print $2}'`
nova list
nova show cloud01
# ssh instance
# ssh-keygen -f "/home/cloud/.ssh/known_hosts" -R 10.0.0.2
# ssh -i ~/.ssh/id_rsa ubuntu@10.0.0.2

## 5.有用的命令
### 查看keypair
### nova keypair-list
### 删除keypair
### nova keypair-delete
### 查看vm
### nova list
### 删除vm，vm的ID
### nova delete 10d1bc19-b2c4-4eee-a5c8-b256bda3f343




## 四、完成安装部署
cat <<EOF >&1
 1. login the dashboard
   http://192.168.139.50
   user:admin
   pass:ADMIN or $ADMIN_TOKEN
 2. login a instance("cloud01")
   ssh -i ~/.ssh/id_rsa ubuntu@10.0.0.2
 3. view & manage
   nova list
   nova show cloud01
   ...
 4. enjoy yourself! (Contact Hily.Hoo@gmail.com)
EOF