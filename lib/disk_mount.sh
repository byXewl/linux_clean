#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工具箱顶层目录，用于加载其他通用函数 (如果需要)
# SCRIPT_DIR is typically set by toolbox.sh
# 如果此脚本被独立执行, SCRIPT_DIR 可能未定义
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fi

# 列出可用的块设备 (磁盘和分区)
# 参数1: "unmounted" - 只列出未挂载的, "mounted" - 只列出已挂载的, "all" - 列出所有
list_block_devices() {
    local filter_type="$1"
    echo -e "${YELLOW}扫描磁盘信息...${NC}" >&2
    
    local devices_info
    devices_info=$(lsblk -P -f -o NAME,SIZE,FSTYPE,TYPE,UUID,MOUNTPOINT,LABEL)
    
    if [ -z "$devices_info" ]; then
        echo -e "${RED}没有找到任何块设备。${NC}" >&2
        return 1
    fi

    local old_ifs=$IFS
    IFS=$'\n' 
    local count=0
    
    # 定义列宽和格式
    # 序号(3) 设备(18) 大小(8) 类型(8) 文件系统(10) UUID(19) 挂载点(20) 标签(12)
    # Total width with spaces: 3+1+18+1+8+1+8+1+10+1+19+1+20+1+12 = 104
    local fmt_header="%-3s %-18s %-8s %-8s %-10s %-19s %-20s %-12s\n"
    local fmt_separator="%.3s %.18s %.8s %.8s %.10s %.19s %.20s %.12s\n"
    local separator_line
    separator_line=$(printf "$fmt_separator" | tr ' ' '-')

    printf "$fmt_header" "序号" "设备" "大小" "类型" "文件系统" "UUID" "挂载点" "标签"
    echo "$separator_line"

    local displayed_data=false
    for line in $devices_info; do 
        local name=$(echo "$line" | grep -o 'NAME="[^"]*"' | sed 's/NAME="//;s/"$//')
        local size=$(echo "$line" | grep -o 'SIZE="[^"]*"' | sed 's/SIZE="//;s/"$//')
        local fstype=$(echo "$line" | grep -o 'FSTYPE="[^"]*"' | sed 's/FSTYPE="//;s/"$//')
        local type=$(echo "$line" | grep -o 'TYPE="[^"]*"' | sed 's/TYPE="//;s/"$//')
        local uuid=$(echo "$line" | grep -o 'UUID="[^"]*"' | sed 's/UUID="//;s/"$//')
        local mountpoint=$(echo "$line" | grep -o 'MOUNTPOINT="[^"]*"' | sed 's/MOUNTPOINT="//;s/"$//')
        local label=$(echo "$line" | grep -o 'LABEL="[^"]*"' | sed 's/LABEL="//;s/"$//')

        local display_line=false # Default to not displaying
        if [ "$filter_type" == "all" ]; then
            display_line=true
        elif [ "$filter_type" == "unmounted" ]; then
            # Only show unmounted PARTITIONS
            if [ "$type" == "part" ] && [ -z "$mountpoint" ]; then
                display_line=true
            fi
        elif [ "$filter_type" == "mounted" ]; then
            # Show mounted devices, excluding SWAP
            if [ -n "$mountpoint" ] && [[ "$mountpoint" != "[SWAP]" ]]; then
                display_line=true
            fi
        fi
        
        # Common filters (loop, rom) still apply if display_line was true
        if $display_line; then
            if [[ "$type" == "loop" || "$type" == "rom" ]]; then
                 display_line=false # Explicitly exclude them after main filter logic
            fi
            # LVM PVs (TYPE="lvm" with no FSTYPE and no MOUNTPOINT) are also generally not directly mounted.
            if [[ "$type" == "lvm" && -z "$fstype" && -z "$mountpoint" ]]; then
                 display_line=false
            fi
        fi

        if $display_line; then
            count=$((count + 1))
            displayed_data=true

            # 清理可能存在的换行符，并准备用于显示和截断的变量
            local clean_name=$(echo "${name:-N/A}" | tr -d '\n\r')
            local clean_size=$(echo "${size:-N/A}" | tr -d '\n\r')
            local clean_type=$(echo "${type:-N/A}" | tr -d '\n\r')
            local clean_fstype=$(echo "${fstype:-N/A}" | tr -d '\n\r')
            local clean_uuid_val=$(echo "${uuid:-N/A}" | tr -d '\n\r')
            local clean_mountpoint=$(echo "${mountpoint:-N/A}" | tr -d '\n\r')
            local clean_label=$(echo "${label:-N/A}" | tr -d '\n\r')

            # 特殊处理UUID的显示格式
            local d_uuid_display="$clean_uuid_val"
            if [[ "$clean_uuid_val" != "N/A" && ${#clean_uuid_val} -gt 18 ]]; then
                d_uuid_display="${clean_uuid_val:0:8}...${clean_uuid_val:(-8)}" # xxx...xxx (19 chars total)
            fi 
            
            # 使用printf进行格式化输出每一行 (单行调用)
            printf "$fmt_header" "$count" \
                "${clean_name:0:18}" \
                "${clean_size:0:8}" \
                "${clean_type:0:8}" \
                "${clean_fstype:0:10}" \
                "${d_uuid_display:0:19}" \
                "${clean_mountpoint:0:20}" \
                "${clean_label:0:12}"
        fi
    done
    IFS=$old_ifs

    if ! $displayed_data; then # if count is 0 / no data was displayed
        # echo "$separator_line" # Optional: print separator even if no data, for consistent look
        if [ "$filter_type" == "unmounted" ]; then
            echo -e "${YELLOW}没有找到未挂载的可用分区。${NC}" >&2
        elif [ "$filter_type" == "mounted" ]; then
            echo -e "${YELLOW}没有找到已挂载的非系统分区。${NC}" >&2
        else # For "all"
            echo -e "${YELLOW}没有找到符合条件的磁盘或分区。${NC}" >&2
        fi
        return 1
    fi
    
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}磁盘的分区表${NC}"
    lsblk -fp
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}当前磁盘使用情况${NC}"
    df -h | awk 'NR==1 || /^\/dev\//'
    echo -e "${BLUE}==================================${NC}"
    return 0
}

fdisk_partition(){
    list_block_devices "all"
    echo -e "${GREEN}=== 扩展磁盘分区 ===${NC}"
    echo -e "\n若sda > sda1+sda2+...+sdaN。则机器、VMware等扩容只是把磁盘sda变大了,已有的分区表和文件系统没有自动扩展  \n${NC}"
    echo -e "${GREEN}=== 示例:手动扩展sda2等旧分区和对应的文件系统 ===${NC}"
    echo -e "\n扩展分区(如把sda2扩展到占满sda):利用fdisk命令 1.删除sda2(不会丢数据,因为是LVM)。2.新建一个分区，起始位置一样(默认start)，结束位置用默认值(默认占满）
            \n刷新分区表: partprobe
            \n扩展更新物理卷: pvresize /dev/sda2
            \n扩展更新逻辑卷(比如根分区): lvextend -l +100%FREE /dev/mapper/centos-root
            \n扩展更新文件系统: 如 xfs_growfs /
            \n即可df -h查看情况
            "
   echo -e "${GREEN}=== 具体不同操作系统的命令请咨询AI ===${NC}"
}


# 挂载磁盘分区
mount_partition() {
    echo -e "${GREEN}=== 挂载磁盘分区 ===${NC}" >&2
    # list_block_devices "unmounted" # 调用list_block_devices仅用于显示，选择逻辑在下面
    # local list_result=$?
    
    # 重新获取未挂载设备列表，使用 KEY="value" 格式进行可靠解析
    local unmounted_devices_details=() # 存储解析后的设备详情 K=V 字符串
    local unmounted_devices_display=() # 存储用于 select 显示的字符串

    local raw_lsblk_info
    raw_lsblk_info=$(lsblk -P -f -o NAME,SIZE,FSTYPE,TYPE,UUID,MOUNTPOINT,LABEL)
    local old_ifs=$IFS
    IFS=$'\n'
    for line in $raw_lsblk_info; do
        local type=$(echo "$line" | grep -o 'TYPE="[^"]*"' | sed 's/TYPE="//;s/"$//')
        local mountpoint=$(echo "$line" | grep -o 'MOUNTPOINT="[^"]*"' | sed 's/MOUNTPOINT="//;s/"$//')
        local name=$(echo "$line" | grep -o 'NAME="[^"]*"' | sed 's/NAME="//;s/"$//')
        local size=$(echo "$line" | grep -o 'SIZE="[^"]*"' | sed 's/SIZE="//;s/"$//')
        local fstype=$(echo "$line" | grep -o 'FSTYPE="[^"]*"' | sed 's/FSTYPE="//;s/"$//')

        if [[ "$type" == "part" && -z "$mountpoint" && "$type" != "loop" && "$type" != "rom" ]]; then
            unmounted_devices_details+=("$line") # 存储整行 K=V 信息
            unmounted_devices_display+=("设备: ${name:-N/A} 大小: ${size:-N/A} 文件系统: ${fstype:-N/A}")
        fi
    done
    IFS=$old_ifs

    if [ ${#unmounted_devices_display[@]} -eq 0 ]; then
        # 调用 list_block_devices 来显示表格式的"无未挂载分区"信息
        list_block_devices "unmounted" 
        # echo -e "${YELLOW}当前没有可供挂载的未挂载分区。${NC}" # list_block_devices会打印类似信息
        return 1
    fi

    # 在选择前，先调用 list_block_devices "unmounted" 来美观地显示列表
    echo -e "${YELLOW}以下是检测到的未挂载分区:${NC}" >&2
    list_block_devices "unmounted"

    echo -e "${YELLOW}请选择要挂载的分区 (输入序号):${NC}" >&2
    select opt_display in "${unmounted_devices_display[@]}" "返回上一级"; do
        if [[ "$REPLY" == "b" || "$opt_display" == "返回上一级" ]]; then
            return
        elif [[ "$REPLY" == "0" ]]; then
             echo -e "${YELLOW}操作取消。${NC}" >&2; return;
        elif [ -n "$opt_display" ]; then
            # 获取选择的序号 (REPLY 是 select 命令设置的数字)
            local selected_index=$((REPLY - 1))
            local selected_device_kv_line="${unmounted_devices_details[$selected_index]}"
            
            # 从K=V行中解析所需字段
            local device_name=$(echo "$selected_device_kv_line" | grep -o 'NAME="[^"]*"' | sed 's/NAME="//;s/"$//')
            local fstype=$(echo "$selected_device_kv_line" | grep -o 'FSTYPE="[^"]*"' | sed 's/FSTYPE="//;s/"$//')
            local uuid=$(echo "$selected_device_kv_line" | grep -o 'UUID="[^"]*"' | sed 's/UUID="//;s/"$//')

            echo -e "${GREEN}您选择了: $device_name ${NC}" >&2
            
            # 获取或确认文件系统类型
            if [ -z "$fstype" ] || [ "$fstype" == "N/A" ]; then
                echo -e "${YELLOW}无法自动检测 $device_name 的文件系统类型。${NC}" >&2
                read -rp "请输入文件系统类型 (例如: ext4, xfs, ntfs, vfat): " detected_fstype
                if [ -z "$detected_fstype" ]; then
                    echo -e "${RED}未提供文件系统类型，操作取消。${NC}" >&2
                    continue # 回到select循环
                fi
                fstype="$detected_fstype"
            else
                echo -e "检测到文件系统类型为: ${GREEN}$fstype${NC}" >&2
            fi

            # 获取挂载点
            local default_mount_point="/mnt/$(basename "$device_name")"
            read -rp "请输入挂载点 (默认为 ${default_mount_point}): " mount_point
            mount_point="${mount_point:-$default_mount_point}"

            # 检查挂载点是否存在，如果不存在则创建
            if [ ! -d "$mount_point" ]; then
                echo -e "${YELLOW}挂载点 $mount_point 不存在。${NC}" >&2
                read -rp "是否创建目录 $mount_point ? (y/N): " create_dir_choice
                if [[ "$create_dir_choice" =~ ^[Yy]$ ]]; then
                    sudo mkdir -p "$mount_point"
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}创建目录 $mount_point 失败。请检查权限或路径。${NC}" >&2
                        continue
                    fi
                    echo -e "${GREEN}目录 $mount_point 创建成功。${NC}" >&2
                else
                    echo -e "${RED}操作取消，未创建挂载点。${NC}" >&2
                    continue
                fi
            fi
            
            # 检查挂载点是否已作为挂载点被使用
            if findmnt -rno TARGET "$mount_point" > /dev/null; then
                 echo -e "${RED}错误：挂载点 $mount_point 已经被 $device_name 或其他设备使用。${NC}" >&2
                 read -rp "是否尝试卸载 $mount_point (请谨慎操作)? (y/N): " umount_choice
                 if [[ "$umount_choice" =~ ^[Yy]$ ]]; then
                     sudo umount "$mount_point"
                     if [ $? -ne 0 ]; then
                         echo -e "${RED}卸载 $mount_point 失败。${NC}" >&2
                         continue
                     else
                         echo -e "${GREEN}$mount_point 已卸载。${NC}" >&2
                     fi
                 else
                     echo -e "${YELLOW}请选择其他挂载点或先手动卸载。${NC}" >&2
                     continue
                 fi
            fi

            # 执行挂载
            echo -e "${YELLOW}正在尝试挂载 $device_name 到 $mount_point (类型: $fstype)...${NC}" >&2
            sudo mount -t "$fstype" "$device_name" "$mount_point"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}成功将 $device_name 挂载到 $mount_point ${NC}" >&2
                
                # 询问是否添加到 /etc/fstab
                if [ -n "$uuid" ] && [ "$uuid" != "N/A" ]; then
                    read -rp "是否要将此挂载添加到 /etc/fstab 以实现开机自动挂载? (y/N): " add_to_fstab
                    if [[ "$add_to_fstab" =~ ^[Yy]$ ]]; then
                        local fstab_entry="UUID=$uuid $mount_point $fstype defaults 0 0"
                        echo -e "${YELLOW}将要添加到 /etc/fstab 的内容如下:${NC}" >&2
                        echo "$fstab_entry" >&2
                        read -rp "确认添加? (y/N): " confirm_fstab
                        if [[ "$confirm_fstab" =~ ^[Yy]$ ]]; then
                            # 备份fstab
                            sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)
                            echo -e "${GREEN}/etc/fstab 已备份为 /etc/fstab.bak...${NC}" >&2
                            # 追加到fstab
                            echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}成功添加到 /etc/fstab。${NC}" >&2
                                echo -e "${YELLOW}建议运行 'sudo mount -a' 来测试 fstab 配置 (如果系统支持)。${NC}" >&2
                            else
                                echo -e "${RED}添加到 /etc/fstab 失败。请检查权限或手动添加。${NC}" >&2
                            fi
                        else
                            echo -e "${YELLOW}未添加到 /etc/fstab。${NC}" >&2
                        fi
                    fi
                else
                    echo -e "${YELLOW}无法获取 $device_name 的UUID，无法自动添加到 fstab。请考虑使用设备名（不推荐）或手动添加。${NC}" >&2
                fi
            else
                echo -e "${RED}挂载 $device_name 到 $mount_point 失败。${NC}" >&2
                echo -e "${RED}请检查文件系统类型、设备状态和挂载点权限。${NC}" >&2
                echo -e "${RED}错误信息可能在 'dmesg | tail' 中找到。${NC}" >&2
            fi
            break # 完成操作后退出select
        else
            echo -e "${RED}无效的选择，请重新输入。${NC}" >&2
        fi
    done
}

# 卸载已挂载的分区
unmount_partition() {
    echo -e "${GREEN}=== 卸载磁盘分区 ===${NC}"
    
    local mounted_partitions=()
    # findmnt -lno SOURCE,TARGET,FSTYPE,OPTIONS | grep -E '^/dev/(sd|hd|vd|nvme|xvd)' # 过滤系统关键挂载点比较复杂
    # 更简单的方式是列出所有可卸载的（非根、/boot等）
    # lsblk -fpno NAME,SIZE,FSTYPE,UUID,MOUNTPOINT,LABEL | awk '$6 != "" && $6 != "[SWAP]" && $6 != "/" {print $1 " (" $2 ", " $3 ") on " $6}'

    # 使用findmnt获取用户挂载点（排除一些系统常见的）
    # -t no*: 排除tmpfs, devtmpfs, sysfs, proc, etc.
    # -N /: 排除根目录
    # --real: 排除虚拟文件系统
    local raw_mounted_info
    raw_mounted_info=$(findmnt -lno SOURCE,TARGET,FSTYPE --real -t nosysfs,noproc,nodevtmpfs,notmpfs,noramfs,nodevpts,nooverlay,nosquashfs | grep -vE '^tmpfs|^overlay|^squashfs|(/run|/dev|/sys|/proc|/snap|/boot|/$ )')
    # raw_mounted_info=$(findmnt -lno SOURCE,TARGET,FSTYPE -R -t nosysfs,noproc,nodevtmpfs,notmpfs,noramfs,nodevpts,nooverlay,nosquashfs | grep -vE '^tmpfs|^overlay|^squashfs|(/run|/dev|/sys|/proc|/snap|/boot|/$ )')
    # raw_mounted_info=$(findmnt -lno SOURCE,TARGET,FSTYPE | grep '^/dev/' | grep -vE '^tmpfs|^overlay|^squashfs|(/run|/dev|/sys|/proc|/snap|/boot|/$ )')
    if [ -z "$raw_mounted_info" ]; then
        echo -e "${YELLOW}没有找到可供卸载的用户自定义挂载点。${NC}"
        return 1
    fi
    
    local IFS_old=$IFS
    IFS=$'\\n'
    for line in $raw_mounted_info; do
        local source=$(echo "$line" | awk '{print $1}')
        local target=$(echo "$line" | awk '{print $2}')
        local fstype=$(echo "$line" | awk '{print $3}')
        # 过滤掉 docker, kubernetes 等管理的复杂挂载，只关注简单设备挂载
        if [[ "$source" == "overlay" || "$source" == "tmpfs" || "$target" == "/" || "$target" == "/boot" || "$target" =~ ^/var/lib/(docker|kubelet) ]]; then # 进一步过滤
            continue
        fi
        mounted_partitions+=("卸载 ${source} (挂载于 ${target}, 类型 ${fstype})")
    done
    IFS=$IFS_old

    if [ ${#mounted_partitions[@]} -eq 0 ]; then
        echo -e "${YELLOW}当前没有可供卸载的用户自定义挂载分区。${NC}"
        return 1
    fi

    echo -e "${YELLOW}请选择要卸载的分区 (输入序号):${NC}"
    select opt in "${mounted_partitions[@]}" "返回上一级"; do
        if [[ "$REPLY" == "b" || "$opt" == "返回上一级" ]]; then
            return
        elif [ -n "$opt" ]; then
            # 从选项中提取设备名或挂载点
            # "卸载 /dev/sdb1 (挂载于 /mnt/sdb1, 类型 ext4)"
            local target_mount_point=$(echo "$opt" | grep -oP '挂载于 \K[^,]+')
            local device_name=$(echo "$opt" | awk '{print $2}') # 第二个字段是设备名

            echo -e "${GREEN}您选择了卸载: $target_mount_point (设备: $device_name)${NC}"
            read -rp "确认卸载 $target_mount_point ? (y/N): " confirm_unmount
            if [[ "$confirm_unmount" =~ ^[Yy]$ ]]; then
                sudo umount "$target_mount_point"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}成功卸载 $target_mount_point ${NC}"
                    
                    # 询问是否从 /etc/fstab 中移除 (如果存在)
                    # 需要获取UUID来准确查找fstab条目，或用挂载点
                    local uuid_of_device
                    if [[ $device_name =~ ^/dev/ ]]; then
                        uuid_of_device=$(sudo blkid -s UUID -o value "$device_name")
                    fi

                    local fstab_line_grep_pattern
                    if [ -n "$uuid_of_device" ]; then
                        fstab_line_grep_pattern="UUID=$uuid_of_device"
                    else # 如果没有UUID，尝试用挂载点，但这可能不唯一或不准确
                        fstab_line_grep_pattern="$target_mount_point"
                    fi
                    
                    if sudo grep -q "$fstab_line_grep_pattern" /etc/fstab; then
                        echo -e "${YELLOW}$target_mount_point (或其对应设备 $device_name) 的条目存在于 /etc/fstab。${NC}"
                        read -rp "是否尝试从 /etc/fstab 中移除该条目? (y/N): " remove_fstab
                        if [[ "$remove_fstab" =~ ^[Yy]$ ]]; then
                            echo -e "${YELLOW}将要从 /etc/fstab 移除包含 '${fstab_line_grep_pattern}' 的行。${NC}"
                            echo -e "${RED}请仔细确认，这是一个危险操作！${NC}"
                            sudo grep "$fstab_line_grep_pattern" /etc/fstab
                            read -rp "确认移除? (y/N): " confirm_remove_fstab
                            if [[ "$confirm_remove_fstab" =~ ^[Yy]$ ]]; then
                                sudo cp /etc/fstab /etc/fstab.bak.umount.$(date +%Y%m%d%H%M%S)
                                echo -e "${GREEN}/etc/fstab 已备份。${NC}"
                                # 使用sed进行删除，确保操作的原子性
                                sudo sed -i.prev_umount -e "\\|$fstab_line_grep_pattern|d" /etc/fstab
                                if [ $? -eq 0 ]; then
                                    echo -e "${GREEN}成功从 /etc/fstab 移除相关条目。${NC}"
                                else
                                    echo -e "${RED}从 /etc/fstab 移除失败。请手动编辑。${NC}"
                                    echo -e "${YELLOW}旧的 fstab 文件备份为 /etc/fstab.prev_umount (如果sed支持)。${NC}"
                                fi
                            else
                                echo -e "${YELLOW}未从 /etc/fstab 移除。${NC}"
                            fi
                        fi
                    fi
                else
                    echo -e "${RED}卸载 $target_mount_point 失败。${NC}"
                    echo -e "${RED}可能是设备正忙，请使用 'lsof | grep $target_mount_point' 或 'fuser -vm $target_mount_point' 检查。${NC}"
                fi
            else
                echo -e "${YELLOW}操作取消。${NC}"
            fi
            break 
        else
            echo -e "${RED}无效的选择，请重新输入。${NC}"
        fi
    done
}

# 管理 /etc/fstab (暂未详细实现，可作为扩展)
manage_fstab() {
    echo -e "${GREEN}=== 管理 /etc/fstab ===${NC}"
    echo -e "${YELLOW}此功能允许您查看、添加或移除 /etc/fstab 中的持久化挂载项。${NC}"
    echo -e "${YELLOW}警告：错误地修改 /etc/fstab 可能导致系统无法启动！${NC}"
    
    echo "1. 查看 /etc/fstab 内容"
    echo "2. 检查未写入fstab的当前挂载"
    echo "b. 返回主菜单"
    read -rp "请选择操作: " fstab_choice

    case $fstab_choice in
        1)
            echo -e "${BLUE}--- /etc/fstab 内容 ---${NC}"
            sudo cat /etc/fstab
            echo -e "${BLUE}----------------------${NC}"
            ;;
        2)
            echo -e "${YELLOW}检查哪些当前挂载的设备 (基于UUID) 未在 /etc/fstab 中...${NC}"
            # 获取所有真实挂载设备及其UUID和挂载点
            # current_mounts=$(findmnt -lno SOURCE,TARGET,UUID --real -t nosysfs,noproc,nodevtmpfs,notmpfs,noramfs,nodevpts,nooverlay,nosquashfs | grep -vE '^tmpfs|^overlay|^squashfs|(/run|/dev|/sys|/proc|/snap|/boot|/$ )' | grep '^/dev/')
           current_mounts=$(findmnt -lno SOURCE,TARGET,UUID -R -t nosysfs,noproc,nodevtmpfs,notmpfs,noramfs,nodevpts,nooverlay,nosquashfs | grep -vE '^tmpfs|^overlay|^squashfs|(/run|/dev|/sys|/proc|/snap|/boot|/$ )' | grep '^/dev/') 
            if [ -z "$current_mounts" ]; then
                echo -e "${GREEN}没有找到适合检查的用户设备挂载。${NC}"
                return
            fi

            local IFS_old=$IFS IFS=$'\\n'
            local not_in_fstab_count=0
            for mount_info in $current_mounts; do
                local dev=$(echo "$mount_info" | awk '{print $1}')
                local target=$(echo "$mount_info" | awk '{print $2}')
                local uuid=$(echo "$mount_info" | awk '{print $3}')

                if [ -z "$uuid" ] || [ "$uuid" == "N/A" ]; then
                    echo -e "${YELLOW}设备 $dev (挂载于 $target) 没有UUID，跳过fstab检查。${NC}"
                    continue
                fi

                if ! sudo grep -q "UUID=$uuid" /etc/fstab; then
                    echo -e "${RED}发现：设备 $dev (UUID: $uuid, 挂载于: $target) 可能未在 /etc/fstab 中持久化。${NC}"
                    # 这里可以添加直接写入fstab的选项，但需谨慎
                    not_in_fstab_count=$((not_in_fstab_count + 1))
                fi
            done
            IFS=$IFS_old
            if [ $not_in_fstab_count -eq 0 ]; then
                echo -e "${GREEN}所有检测到的设备挂载似乎都已在 /etc/fstab 中有对应UUID条目。${NC}"
            fi
            ;;
        b|B)
            return
            ;;
        *)
            echo -e "${RED}无效选项。${NC}"
            ;;
    esac
}


# 主菜单函数，由 toolbox.sh 的菜单调用
manage_disk_mount() {
    # 依赖检测
    local missing_deps=()
    local commands_to_check=("lsblk" "column" "findmnt" "blkid" "mount" "umount" "awk" "grep" "sed" "sudo")
    local command_sources=("util-linux" "util-linux or bsdmainutils" "util-linux" "util-linux" "util-linux" "util-linux" "gawk or mawk" "grep (coreutils)" "sed (coreutils)" "sudo")
    
    for i in "${!commands_to_check[@]}"; do
        local cmd="${commands_to_check[$i]}"
        local src="${command_sources[$i]}"
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd (来自 $src)")
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}错误：执行此功能所需的命令未找到:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - ${YELLOW}$dep${NC}"
        done
        echo -e "\n${YELLOW}请安装缺失的依赖项后重试。${NC}"
        echo -e "${YELLOW}例如，在 Debian/Ubuntu 上尝试: sudo apt install util-linux bsdmainutils gawk${NC}"
        echo -e "${YELLOW}在 CentOS/RHEL 上尝试: sudo yum install util-linux bsdmainutils gawk${NC}"
        # 脚本不会自动安装依赖
        if [[ -t 0 ]]; then # Check if stdin is a terminal
          read -n 1 -s -r -p "按任意键返回..."
        fi
        return 1
    fi

    while true; do
        echo -e "${BLUE}==================================${NC}"
        echo -e "${YELLOW}         磁盘挂载与管理         ${NC}"
        echo -e "${BLUE}==================================${NC}"
        echo -e "${GREEN}1.${NC} 查看所有块设备信息(磁盘分区)"
        echo -e "${GREEN}2.${NC} 扩展旧的磁盘分区"
        echo -e "${GREEN}3.${NC} 挂载新的磁盘分区"
        echo -e "${GREEN}4.${NC} 卸载已挂载的分区"
        echo -e "${GREEN}5.${NC} 查看所有块设备信息"
        echo -e "${GREEN}6.${NC} 管理 /etc/fstab (查看/检查)"
        echo -e "${GREEN}0.${NC} 返回上级菜单"
        echo -e "${BLUE}==================================${NC}"
        read -rp "请输入选项: " main_choice

        case $main_choice in
            1)
                list_block_devices "all"
                # mount_partition
                ;;
            2)
                fdisk_partition
                # mount_partition
                ;;
            3)
                mount_partition
                ;;
            4)
                unmount_partition
                ;;
            5)
                list_block_devices "all"
                ;;
            6)
                manage_fstab
                ;;
            0)
                echo -e "${YELLOW}返回上级菜单...${NC}"
                break
                ;;
            *)
                echo -e "${RED}无效的选项，请重试。${NC}"
                ;;
        esac
        # Pause for user to see output, unless returning to main menu
        if [[ "$main_choice" != "0" ]]; then 
            echo -e "\n${GREEN}按任意键返回磁盘管理菜单...${NC}"
            read -n 1 -s -r # -r to handle backslashes, -s silent, -n 1 char
        fi
    done
}

manage_disk_mount