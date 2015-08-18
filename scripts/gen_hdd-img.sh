#!/bin/bash
set -e
if [ -n $2 ]; then
   TARGET="$2"
else 
   TARGET="$ALMOS_TOP/hdd-img.bin"
fi

fat32=1
case "$3" in
      fat32) fat32=1 ;;
      ext2)  fat32=0 ;;
esac

echo "$0 : TARGET = $TARGET, fat32 $fat32"
BOOT_LOADER_BIN="$ALMOS_TOP/tools/soclib-bootloader/bootloader-tsar-mipsel.bin" # ! it is a .elf
echo "Bootloader elf : $BOOT_LOADER_BIN"

size_bytes=512000
sector_size=512 #must be 512 Bytes for generic_leti platform
sectors_per_cluster=8
boot_size=$(wc -c $BOOT_LOADER_BIN | awk '{print $1}')
sectors_boot=$((($boot_size / $sector_size)+1))

#reserved sector will begin from sector 2 and will contain the boot_loader code,
#the kernel image and the architecture informations
#We put the backup of VBR (MBR) at the end of the reserved sector
offset=2
let "reserved_sectors = offset + sectors_boot + 1"
let "back_up_sector = reserved_sectors - 1" #last reserved sector

echo ""
echo "******** HDD_IMG *********"
echo "$reserved_sectors reserved sectors --> backup at back_up_sector $back_up_sector"
#the first two cluster are not in the data region
#data_region_clusters=$cluster_size-2
#
#let "data_sectors = data_region_clusters * sectors_per_cluster"
#let "fat_sector   = ( clusters_nr * 4 ) / 512 "
#
##+1 for VBR sector
#let "sectors_nr = data_sectors + fat_sector + reserved_sectors"

case $1 in
   -h )
      echo "use : $0 <dir_source_partition> <TARGET> <fat_type>"
      echo "Dont forget to check the numbers of sectors for each file"
      exit 0
      ;;
   * )
      #create partition
      if [ $fat32 -eq 1 ]; then
          mkfs.vfat -C -F 32 -f 1\
         -r 512\
         -R $reserved_sectors\
         -S $sector_size\
         -s $sectors_per_cluster\
         -b $back_up_sector\
         -i f7120c4f\
         -n hdd\
         -v $TARGET $size_bytes
         
         #create FAT
         mcopy -s -i $TARGET $1/* :://
      else
          mkfs.ext2 $TARGET
      fi
      
      #copy bootloader, arch-info (boot-info) and kernel-img in reserved sectors from sector 2
      echo "Insert boot_loader at sector $offset"
      
      dd bs=$sector_size seek=$offset count=$sectors_boot conv=notrunc if=$BOOT_LOADER_BIN of=$TARGET   

      echo "****** HDD_IMG CREATED ******"
      echo ""
esac;


exit 0
