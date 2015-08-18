#!/bin/sh

## Author : Pierre-Yves Péneau
## Last update : 18/07/15

##################
## TODO section ##
##################
## 1/ remove $ALMOS_DISTRIB variable in userland/, sys/ and lib/. Use
##    $ALMOS_USR_TOP instead.


#################
## Directories ##
#################
export ROOT_DIR=TO_BE_SET
export ALMOS_TOP=$ROOT_DIR/almos-mk
export ALMOS_USR_TOP=$ALMOS_TOP/userland/almos-tsar-mipsel-1.0
export TSAR_TOP=$ROOT_DIR/tsar
export GIET_TOP=$ROOT_DIR/giet-vm
export SOCLIB=$ROOT_DIR/soclib
## Uncomment this lines if you are using your own SystemC and SystemCASS
#export SYSTEMC=$ROOT_DIR/systemc
#export SYSTEMCASS=$ROOT_DIR/systemcass
export SCRIPTS_DIR=$ROOT_DIR/scripts


#############################
## ALMOS related variables ##
#############################
## $ALMOS_USR_APPS define all user applications that will be compiled and added
## in the disk image. All apps can be found in $ALMOS_USR_TOP/apps. init and sh
## are obviously needed.
export ALMOS_USR_APPS="init sh homeless"
export ALMOS_CPU=mipsel
export ALMOS_ARCH=tsar
export CCTOOLS=$ALMOS_USR_TOP/cross-tools/mipsel-unknown-elf
export IMAGE_NAME=hdd-img.bin   # name used for the hard drive image
export ARCH_INFO=arch           # name used for the hardware description file used by Almos-MK
export PATH=$CCTOOLS/bin:$PATH
export PATH=$ALMOS_TOP/tools/bin:$PATH
## This variable is only export for compatibility. See TODO section
export ALMOS_DISTRIB=$ALMOS_USR_TOP


############################
## TSAR related variables ##
############################
export PRELOAD_TOP=$TSAR_TOP/softs/tsar_boot
export USE_SOCLIB=1
## We don't want to use the device tree: the operating system
## will have to discover the hardware topology itself
## this is Almos-MK specific !
export USE_DT=0


#####################
## Compiling tools ##
#####################
export PATH=~devigne/gcc/bin:~dsx/cctools/bin:$SOCLIB/utils/bin:$PATH
export LD_LIBRARY_PATH=~devigne/gcc/lib64:~devigne/gcc/lib:$LD_LIBRARY_PATH
export TARGET=tsar


##########
## Misc ##
##########
export NCPU=$(grep -c ^processor /proc/cpuinfo)

