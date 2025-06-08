#  customize.sh 脚本说明
#
# 脚本功能：
# 1. 打印自定义安装过程的开始信息。
# 2. 检查设备架构，并根据架构类型打印相应信息或终止安装。
# 3. 检查 Android API 版本，确保版本在支持范围内，否则终.安装。
# 4. 设置指定文件和目录的权限。
# 5. 打印自定义安装过程的完成信息。
#
# 脚本详细说明：
# - ui_print: 用于在安装过程中打印信息到控制台。
# - case "$ARCH" in ... esac: 检查设备架构，支持 "arm", "arm64", "x86", "x64" 四种架构。
# - abort: 用于终止安装过程并打印错.信息。
# - if [ "$API" -lt 23 ]; then ... fi: 检查 Android API 版本，要求版本不低于 23。
# - set_perm: 设置单个文件的权限。
# - set_perm_recursive: 递归设置目录及其内容的权限。

# 打印信息到控制台
ui_print "开始安装$MODID"
ui_print "模块路径: $MODPATH"

# 检查设备架构
case "$ARCH" in
    "arm")
        ui_print "设备架构为 ARM 32位"
        abort "不支持32位设备架构: $ARCH"
        ;;
    "arm64")
        ui_print "设备架构为 ARM 64位"
        ;;
    "x86")
        ui_print "设备架构为 x86 32位"
        abort "不支持32位设备架构: $ARCH"
        ;;
    "x64")
        ui_print "设备架构为 x86 64位"
        ;;
    *)
        abort "不支持的设备架构: $ARCH"
        ;;
esac

ui_print "Android API 版本: $API"

if [ "$KSU" = "true" ]; then
  ui_print "- kernelSU version: $KSU_VER ($KSU_VER_CODE)"
  echo "$KSU_VER" > $MODPATH/ksu
elif [ "$APATCH" = "true" ]; then
  APATCH_VER=$(cat "/data/adb/ap/version")
  ui_print "- APatch version: $APATCH_VER"
  ui_print "- KERNEL_VERSION: $KERNEL_VERSION"
  ui_print "- KERNELPATCH_VERSION: $KERNELPATCH_VERSION"
  echo "$APATCH_VER" > $MODPATH/apatch
else
  ui_print "- Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
  echo "$MAGISK_VER" > $MODPATH/magisk
  mv $MODPATH/boot-complete.sh $MODPATH/service.sh
fi


ui_print "模块目录: $MODPATH "

ui_print "给你3秒,请记住模块安装目录"
sleep 3


# 以上写的非常通用
ui_print "MagicSub模块"

ui_print "安装完成"

# 设置权限
set_perm_recursive $MODPATH 0 0 0755 0755

