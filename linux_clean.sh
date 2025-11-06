#!/bin/bash

shopt -s nullglob # 通配符找不到文件时返回空列表，避免“把 * 当成文件名”引发的误操作。

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


# 清理系统垃圾函数
clean_tmp(){
    # 清理临时目录
    echo -e "${GREEN}[开始] 清理临时文件目录(保留socket/pid/lock)${NC}"

    # 1. 找出正在被进程打开的文件（socket/pid/lock 等）
    local keep=$(mktemp)
    # lsof 列出的绝对路径去重后存临时文件
    lsof +D /tmp /var/tmp 2>/dev/null | awk '{print $9}' | sort -u > "$keep"

    # 2. 逐个删除 /tmp 里的文件/目录，跳过“正在使用”的
    for f in /tmp/* /var/tmp/*; do
        [[ -e $f ]] || continue          # 通配符找不到文件会原样返回，要跳过
        grep -Fxq "$f" "$keep" && continue   # 如果正在被使用，跳过
        rm -rf "$f" 2>/dev/null
    done

    rm -f "$keep"
    echo -e "${GREEN}临时目录已清理(保留socket/pid/lock)${NC}"
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}


clean_bag(){
    # 清理软件包缓存（针对不同的Linux发行版，因系统而异，不影响正常包使用）
    echo -e "\n${GREEN}[开始] 清理软件包缓存（不影响正常包使用）:${NC}"
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian系统
        echo -e "检测到 ${YELLOW}Ubuntu/Debian${NC} 系统"
        echo -e "清理已卸载的软件包 (${BLUE}apt-get autoremove${NC})"
        apt-get autoremove -y
        echo -e "清理APT缓存 (${BLUE}apt-get clean${NC})"
        apt-get clean
        echo -e "清理不需要的配置文件 (${BLUE}apt-get autoclean${NC})"
        apt-get autoclean
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL系统
        echo -e "检测到 ${YELLOW}CentOS/RHEL${NC} 系统"
        echo -e "清理YUM缓存 (${BLUE}yum clean all${NC})"
        yum clean all
        echo -e "清理已卸载的软件包 (${BLUE}yum autoremove${NC})"
        yum autoremove -y
    elif command -v dnf &> /dev/null; then
        # Fedora/新版CentOS系统
        echo -e "检测到 ${YELLOW}Fedora/CentOS Stream${NC} 系统"
        echo -e "清理DNF缓存 (${BLUE}dnf clean all${NC})"
        dnf clean all
        echo -e "清理已卸载的软件包 (${BLUE}dnf autoremove${NC})"
        dnf autoremove -y
    elif command -v pacman &> /dev/null; then
        # Arch Linux系统
        echo -e "检测到 ${YELLOW}Arch Linux${NC} 系统"
        echo -e "清理pacman缓存 (${BLUE}pacman -Scc${NC})"
        pacman -Scc --noconfirm
    else
        echo -e "${YELLOW}未检测到支持的包管理器，跳过软件包缓存清理${NC}"
    fi

    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}

clean_log(){
    # 清理日志文件
    echo -e "\n${GREEN}[开始] 清理系统日志:${NC}"
    if command -v journalctl &> /dev/null; then
        echo -e "清理系统日志文件 (${BLUE}journalctl --vacuum-time=3d${NC})"
        journalctl --vacuum-time=3d
        echo -e "限制日志大小 (${BLUE}journalctl --vacuum-size=100M${NC})"
        journalctl --vacuum-size=100M
    else
        echo -e "清理系统日志文件 (${BLUE}/var/log/${NC})"
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
        find /var/log -type f -name "*.gz" -delete
    fi

    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}

clean_cache(){
    # 清理用户缓存
    echo -e "\n${GREEN}[开始] 清理用户缓存:${NC}"
    echo -e "清理浏览器缓存、应用程序缓存、Vmware拖动缓存等 (${BLUE}~/.cache/*${NC})"

    # ll ~/.cache/vmware/drag_and_drop/
    rm -rf ~/.cache/* 2>/dev/null 
    /bin/rm -rf ~/.cache/* 2>/dev/null # 防止有rm别名
    
    echo -e "当前用户缓存目录的文件(${BLUE}ls ~/.cache/${NC})"
    ls -l ~/.cache/
    
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}

clean_docker_contain_log(){
    # 清理docker容器日志缓存
    echo "======== 开始清理docker容器日志 ========"  

    logs=$(find /var/lib/docker/containers/ -name "*-json.log")  
    for log in $logs  
            do  
                    echo "clean logs : $log"  
                    cat /dev/null > $log  
            done  

    echo "======== 结束清理docker容器日志========" 
    echo "======== PS:继续docker清理建议手动删除无用docker镜像和容器========" 
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}



clean_desktop_trash(){
    # 清理存在桌面环境(GNOME/KDE等)的用户级回收站
    echo -e "\n${GREEN}[开始] 清理桌面回收站:${NC}"

    # 获取当前用户工作目录
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    # echo "$REAL_HOME"
    # echo $HOME # sudo 工作目录可能变
    REAL_HOME=${REAL_HOME:-$HOME} 
    local dir="$REAL_HOME/.local/share/Trash"
    
    echo "${dir}"
    [[ -d "$dir" ]] || {
      echo -e "未找到桌面回收站${NC} \n"
      return 0
    }
    echo "============================"
    echo "${dir}"/files
    ls -l "${dir}"/files
    echo "============================"
    read -p "清空桌面回收站?[y/N]:" ans
    if [[ $ans == [yY] ]]; then
        # rm -rf "${dir}"/{files,info}/*
        /bin/rm -rf "${dir}"/files/* 
        /bin/rm -rf "${dir}"/info/*
        echo "✓ 已清空桌面回收站"
    else
        echo "- 未清空桌面回收站"
    fi
    echo "============================"
    echo "${dir}"/files
    ls -l "${dir}"/files
    echo "============================"
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}


clean_bt_trash(){
    # 清理宝塔回收站
     echo -e "\n${GREEN}[开始] 清理宝塔回收站:${NC}"
    local dirs=("/.Recycle_bin" "/www/.Recycle_bin")
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        local file_num=$(find "$dir" -type f 2>/dev/null | wc -l)

        [[ $file_num -eq 0 ]] &&{
              echo "宝塔回收站($dir)当前为空"
              continue
        }   
        
        local size=$(du -sh "$dir" | awk '{print $1}')
        echo "===== 宝塔回收站 ($dir) ====="
        echo "文件数：$file_num   大小：$size"
        ls -l "$dir"
        echo "============================"
        read -p "清空该宝塔回收站?[y/N]:" ans
        if [[ $ans == [yY] ]]; then
            rm -rf "${dir:?}"/*
            echo "✓ 宝塔回收站 $dir 已清空"
        else
            echo "- 跳过宝塔回收站 $dir"
        fi
    done
    
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}



clean_system_all() {
    echo -e "${BLUE}==================================${NC}"
    echo -e "${YELLOW}          一键系统清理          ${NC}"
    echo -e "${BLUE}==================================${NC}"
    
    echo -e "\n${YELLOW}准备开始清理系统...${NC}\n"
    sleep 1
    
    # 1. 清理临时目录
    echo -e "${GREEN}[1/5] 清理临时文件目录(保留socket/pid/lock):${NC}"
 
    # 找出正在被进程打开的文件（socket/pid/lock 等）
    local keep=$(mktemp)
    # lsof 列出的绝对路径去重后存临时文件
    lsof +D /tmp /var/tmp 2>/dev/null | awk '{print $9}' | sort -u > "$keep"

    # 逐个删除 /tmp 里的文件/目录，跳过“正在使用”的
    for f in /tmp/* /var/tmp/*; do
        [[ -e $f ]] || continue          # 通配符找不到文件会原样返回，要跳过
        grep -Fxq "$f" "$keep" && continue   # 如果正在被使用，跳过
        rm -rf "$f" 2>/dev/null
    done

    rm -f "$keep"
    echo -e "${GREEN}临时目录已清理(保留socket/pid/lock)${NC}"
    
    # 2. 清理软件包缓存（针对不同的Linux发行版）
    echo -e "\n${GREEN}[2/5] 清理软件包缓存:${NC}"
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian系统
        echo -e "检测到 ${YELLOW}Ubuntu/Debian${NC} 系统"
        echo -e "清理已卸载的软件包 (${BLUE}apt-get autoremove${NC})"
        apt-get autoremove -y
        echo -e "清理APT缓存 (${BLUE}apt-get clean${NC})"
        apt-get clean
        echo -e "清理不需要的配置文件 (${BLUE}apt-get autoclean${NC})"
        apt-get autoclean
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL系统
        echo -e "检测到 ${YELLOW}CentOS/RHEL${NC} 系统"
        echo -e "清理YUM缓存 (${BLUE}yum clean all${NC})"
        yum clean all
        echo -e "清理已卸载的软件包 (${BLUE}yum autoremove${NC})"
        yum autoremove -y
    elif command -v dnf &> /dev/null; then
        # Fedora/新版CentOS系统
        echo -e "检测到 ${YELLOW}Fedora/CentOS Stream${NC} 系统"
        echo -e "清理DNF缓存 (${BLUE}dnf clean all${NC})"
        dnf clean all
        echo -e "清理已卸载的软件包 (${BLUE}dnf autoremove${NC})"
        dnf autoremove -y
    elif command -v pacman &> /dev/null; then
        # Arch Linux系统
        echo -e "检测到 ${YELLOW}Arch Linux${NC} 系统"
        echo -e "清理pacman缓存 (${BLUE}pacman -Scc${NC})"
        pacman -Scc --noconfirm
    else
        echo -e "${YELLOW}未检测到支持的包管理器，跳过软件包缓存清理${NC}"
    fi
    
    # 3. 清理日志文件
    echo -e "\n${GREEN}[3/5] 清理系统日志:${NC}"
    if command -v journalctl &> /dev/null; then
        echo -e "清理系统日志文件 (${BLUE}journalctl --vacuum-time=3d${NC})"
        journalctl --vacuum-time=3d
        echo -e "限制日志大小 (${BLUE}journalctl --vacuum-size=100M${NC})"
        journalctl --vacuum-size=100M
    else
        echo -e "清理系统日志文件 (${BLUE}/var/log/${NC})"
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
        find /var/log -type f -name "*.gz" -delete
    fi
    
    # 4. 清理用户缓存
    echo -e "\n${GREEN}[4/5] 清理用户缓存:${NC}"
    echo -e "清理浏览器缓存、应用程序缓存、Vmware拖动缓存等 (${BLUE}~/.cache/*${NC})"

    # ll ~/.cache/vmware/drag_and_drop/
    rm -rf ~/.cache/* 2>/dev/null 
    /bin/rm -rf ~/.cache/* 2>/dev/null # 防止有rm别名
    
    echo -e "当前用户缓存目录的文件(${BLUE}ls ~/.cache/${NC})"
    ls -l ~/.cache/


    # 5. 清理docker容器日志
     echo -e "\n${GREEN}[5/5] 清理docker容器日志:${NC}"
    echo "======== 开始清理docker容器日志 ========"  

    logs=$(find /var/lib/docker/containers/ -name "*-json.log")  
    for log in $logs  
            do  
                    echo "clean logs : $log"  
                    cat /dev/null > $log  
            done  

    echo "======== 结束清理docker容器日志========" 
    echo "======== PS:继续docker清理建议手动删除无用docker镜像和容器========" 

    
    echo -e "\n${GREEN}系统清理完成！${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo -e "清理项目包括:"
    echo -e "1. 临时文件 (/tmp/*, /var/tmp/*, 保留socket/pid/lock)"
    echo -e "2. 软件包缓存 (因系统而异，不影响正常包使用)"
    echo -e "3. 系统日志 (journalctl或/var/log/)"
    echo -e "4. 用户缓存 (~/.cache/*)"
    echo -e "5. 清理docker容器日志 (/var/lib/docker/containers/*-json.log)"
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}当前磁盘使用情况${NC}"
    df -h | awk 'NR==1 || /^\/dev\//'
    echo -e "${BLUE}==================================${NC}"
    
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
} 

clean_by_user(){
    # 手动清理大文件
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}手动清理大文件-您可以新开一个窗口使用下方命令           ${NC}"
    echo -e "\n1、手动搜索大文件,如超过200m的文件:sudo find / -size +200M -type f           ${NC}"
    echo -e "2、手动按需删除搜索到的大文件,如:sudo rm /var/log/mysql/access.log           ${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo -e "当前系统超过200m的文件:${NC}"
    sleep 1
    find / -size +200M -type f
    echo -e "${BLUE}==================================${NC}"
    echo -e "拓展1:使用命令lsof | grep delet查看删除文件的进程若存在,可自行kill -f掉进程号    ${NC}"
    echo -e "拓展2:查看某目录下占用存储和文件:du /www/ -h --max-depth=1 | sort -gr    ${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}

clean_vmware(){
    # Vmware虚拟机压缩
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}Vmware虚拟机压缩:           ${NC}"
    echo -e "${GREEN}把磁盘清零空闲空间,让[宿主机]回收[虚拟机]中空闲存储,压缩[虚拟机]在[宿主机]中的真实存储空间  ${NC}"
    echo -e "${BLUE}==================================${NC}"
    sleep 1
    echo -e "\n${GREEN}[1/4] 手动删除本虚拟机存在的快照(若有须删除):${NC}"
    echo -e "Vmware的GUI按钮:顶部按钮'管理此虚拟机的快照' → 若存在'快照n' →右键删除"
    sleep 1
    echo -e "${BLUE}==================================${NC}"
    echo -e "\n${GREEN}[2/4] 清零空闲空间(命令:dd if=/dev/zero of=/zero bs=1M; sync; rm -f /zero):${NC}"
    echo -e "把磁盘剩余空间全部写成0在/zero,执行中提示“设备无空间”属正常,结束后空间会立刻恢复  ${NC}"

    read -p "是否清零空闲空间?[y/N]:" ans
        if [[ $ans == [yY] ]]; then
            dd if=/dev/zero of=/zero bs=1M; sync; rm -f /zero
            # 每次写 1 MiB。一直写到磁盘满为止。因为 `dd` 默认不限制大小。
            echo -e "\n"
            echo "${GREEN}✓ 成功清零空闲空间${NC}"
        else
            echo -e "\n"
            echo "- 跳过清零空闲空间"
        fi

    echo -e "${BLUE}==================================${NC}"
    echo -e "\n${GREEN}[3/4] 虚拟机关机:${NC}"
    echo -e "请手动对本Vmware虚拟机关机"
    sleep 1
    echo -e "${BLUE}==================================${NC}"
    echo -e "\n${GREEN}[4/4] 宿主机中压缩:${NC}"
    echo -e "方式1: Vmware的GUI按钮:虚拟机设置 → 硬盘 → '压缩磁盘以回收未使用的空间'"
    echo -e "方式2: 宿主机中使用命令vmware-vdiskmanager -k 虚拟机.vmdk"
    
    echo -e "${BLUE}==================================${NC}"
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
}


# 菜单窗口
show_clean_system_menu(){
    echo -e "${BLUE}==================================${NC}"
    echo -e "${YELLOW}       linux系统清理-by Xe      ${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}当前磁盘使用情况${NC}"
    df -h | awk 'NR==1 || /^\/dev\//'
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}1.${NC} 一键系统清理(包含下面2~6)"
    echo -e "${GREEN}2.${NC} 清理临时文件(保留socket/pid/lock)"
    echo -e "${GREEN}3.${NC} 清理软件包缓存"
    echo -e "${GREEN}4.${NC} 清理系统日志"
    echo -e "${GREEN}5.${NC} 清理用户缓存"
    echo -e "${GREEN}6.${NC} 清理docker容器日志"
    echo -e "${GREEN}7.${NC} 清理桌面回收站"
    echo -e "${GREEN}8.${NC} 清理宝塔回收站"
    echo -e "${GREEN}9.${NC} 手动清理大文件"
    echo -e "${GREEN}10.${NC} Vmware虚拟机压缩(回收空闲存储)"
    echo -e "${GREEN}11.${NC} 磁盘挂载与管理(beta)"
    echo -e "${BLUE}==================================${NC}"
    echo -e "${RED}PS: 请勿在重要生产环境使用本程序!${NC}"
    echo -e "请输入选项 [1-11] 或按 'b' 返回上级: "
}

# 主函数
clean_system_main() {
    clear
    
    while true; do
        show_clean_system_menu
        
        # 需要root权限
        if [ "$EUID" -ne 0 ]; then 
            echo -e "${RED}请使用root权限运行此命令,如:sudo xxx ${NC}"
            read -n 1
            return 1
        fi

        read -r choice
        
        case $choice in
            1)
                clean_system_all
                ;;
            2)
                clean_tmp
                ;;
            3)
                clean_bag
                ;;
            4)
                clean_log
                ;;
            5)
                clean_cache
                ;;
            6)
                clean_docker_contain_log
                ;;
            7)
                clean_desktop_trash
                ;;  
            8)
                clean_bt_trash
                ;;  
            9)
                clean_by_user
                ;; 
            10)
                clean_vmware
                ;;
            11)
                source "./lib/disk_mount.sh"
                ;;                 
            b|B)
                break
                ;;
            *)
                echo -e "${RED}无效的选项，请重试${NC}"
                sleep 1
                ;;
        esac
    done
}
clean_system_main