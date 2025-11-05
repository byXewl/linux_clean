## linux磁盘清理

关键词：
linux空间清理
linux存储清理
简单linux垃圾清理
一键linux清理
linux清理菜单
小白linux清理
linux系统清理
虚拟机清理磁盘
虚拟机清理空间
Vmware清理空间
Vmware虚拟机存储清理
Vmware存储清理
Vmware压缩
```
chmod 777 ./linux_clean.sh
sudo ./linux_clean.sh
```
```
==================================
       linux系统清理-by Xe      
==================================
当前磁盘使用情况
文件系统                 容量  已用  可用 已用% 挂载点
/dev/mapper/centos-root   39G   33G  5.4G   87% /
/dev/sda1               1014M  179M  836M   18% /boot
/dev/mapper/centos-home   19G  374M   19G    2% /home
==================================
1. 一键系统清理(包含下面2~6)
2. 清理临时文件(保留socket/pid/lock)
3. 清理软件包缓存
4. 清理系统日志
5. 清理用户缓存
6. 清理docker容器日志
7. 清理桌面回收站
8. 清理宝塔回收站
9. 手动清理大文件
10. Vmware虚拟机压缩(回收空闲存储)
11. 磁盘挂载与管理(beta)
==================================
PS: 请勿在重要生产环境使用本程序!
请输入选项 [1-11]
```
