

## 1. deploy OpenStack from scrach.
## 部署All-in-one的OpenStack系统
Only checkout and run it! 
1. Setup a fresh Ubuntu Precise(12.04) OS. 

2. Clone onestack:
svn checkout http://onestack.googlecode.com/svn/trunk/ onestack-read-only

3. run it.
cd onestack-read-only/ && ./oneStack.sh

or

## set up OpenStack in 2 steps:
## 分拆oneStack.sh，首先安装基本系统包括5大组件和必要的服务，然后上传镜像，创建实例，需要先做网络等配置，参照oneStack.sh里面的说明
base: ./setup_base.sh
img and instance: ./setup_test.sh


## usefull tools
## 2. delete OpenStack
./delStack.sh

## 3. delete all
./delAll.sh

## 4. reset OpenStack
./resetStack.sh clear
./resetStack.sh

## 5. add OpenStack compute node
./addComputeNode.sh

## 6. add OpenStack client manage node
./addClient.sh

## 8. otherwise, contact me at Hily.Hoo@gmail.com, thanks.

