#!/bin/sh

## Author : Pierre-Yves Péneau
## Last update : 18/08/15

## This tools is your swiss-knife and you will love it. You can generate:
##
## - the TSAR description file (hard_config.h)
## - the TSAR architecture
## - the TSAR architecture file for almos-mk (arch-info)
## - the Almos-MK kernel
## - the Almos-MK bootloader
## - the Almos-MK userland
## - the hard drive image for the simulation
##

## TODO ##
##
## - don't use $SCRIPTS_DIR/gen_arch_info_almos_mk.sh and use
##   $GIET_TOP/giet_python/genmap instead. For now, this solution bring a bug
##   because almos-mk isn't compatible with the actual genmap.
##


## Exit on fail
set -e

## Actions to do
TCLN=0          # Clean TSAR
TSAR=0          # The TSAR Leti architecture
HARD=0          # The TSAR hard_config.h
PRLD=0          # The TSAR preloader
ACLN=0          # Clean Almos-MK
ARCH=0          # The Almos-MK architecture definition (arch.bib)
KERN=0          # The Almos-MK kernel
BOOT=0          # The Almos-MK bootloader
DISK=0          # Generates the disk image (kernel+bootloader+arch.bib)
LALL=0          # Do all operations ahead
LNCH=0          # Launching the simulation
HELP=1          # Display help

## Default configuration
XSIZ=2          # X size
YSIZ=2          # Y size
DBUG=0          # Use debug mode ?
USEX=0          # Use Xterm ?
DEBG=0          # Use debug mode ?
FMBF=0          # Use framebuffer ? 

usage()
{
        clear;
        echo -e "$0 :\n"
        echo -e "       ## ALMOS-MK OPTIONS ## \n"
        echo -e "       -c      clean Almos-MK (kernel, sys, bootloader, hard disk and $ARCH_INFO.{info,bib} )"
        echo -e "       -a      generate $ARCH_INFO.{info,bin}"
        echo -e "       -k      compile the Almos-MK kernel"
        echo -e "       -b      generate boot-loader"
        echo -e "       -dd     generate hard drive disk\n"
        echo -e "       ## TSAR OPTIONS ##\n"
        echo -e "       -csim   clean platform (topcell and preloader)"
        echo -e "       -arch   generate hard_config.h"
        echo -e "       -p      generate pre-loader"
        echo -e "       -t      compile the tsar architecture\n"
        echo -e "       ## GLOBAL OPTIONS ##\n"
        echo -e "       -v      verbose mode"
        echo -e "       -d      debug mode"
        echo -e "       -f      use framebuffer"
        echo -e "       -usex   use soclib tty"
        echo -e "       -x #    Size of the platforn in X (default is 2)"
        echo -e "       -y #    Size of the platforn in Y (default is 2)\n"
        echo -e "       ## SHORTCUTS ##\n"
        echo -e "       --help          print this message"
        echo -e "       --tsar          equivalent to -csim -p -t"
        echo -e "       --almos         equivalent to -c -a -k -b -dd"
        echo -e "       --almos-nc      equivalent to --almos without \"make clean\""
        echo -e "       --all           clean and generate all stuff plus launch simulation\n"
}

## Clean all Almos-MK related things
clean_almos()
{
        if [ -f $ALMOS_TOP/$ARCH_INFO.bib ]; then
                rm $ALMOS_TOP/$ARCH_INFO.bib
        fi
        if [ -f $ALMOS_TOP/$ARCH_INFO.info ]; then
                rm $ALMOS_TOP/$ARCH_INFO.info
        fi
        if [ -f $ALMOS_TOP/$IMAGE_NAME ]; then
                rm $ALMOS_TOP/$IMAGE_NAME
        fi
        make -C $ALMOS_TOP/tools/arch_info/ realclean
        make -C $ALMOS_TOP/tools/soclib-bootloader realclean
        make -C $ALMOS_TOP clean
        return $?
}

## Clean all tsar related things 
clean_tsar()
{
        ## We need hard_config.h to clean everything
        if [ ! -f $TSAR_TOP/platforms/tsar_generic_leti/hard_config.h ]; then
                hardconfig
        fi
        make -C $TSAR_TOP/softs/tsar_boot/ distclean
        make -C $TSAR_TOP/platforms/tsar_generic_leti clean
        rm $TSAR_TOP/platforms/tsar_generic_leti/hard_config.h

        return $?
}

archinfo()
{
        GENERATOR=$SCRIPTS_DIR/gen_arch_info_almos_mk.sh
        
        make -C $ALMOS_TOP/tools/arch_info

        if [ -f $ALMOS_TOP/$ARCH_INFO.info ] ;then
                echo "$ALMOS_TOP/$ARCH_INFO.info already exists. It will be erase."
                rm $ALMOS_TOP/$ARCH_INFO.info
        fi
        echo -e "Generate $ARCH_INFO.info :\t$ALMOS_TOP/$ARCH_INFO.info for a $XSIZ x $YSIZ platform."
        
        if [ ! -f $GENERATOR ]; then
                echo "There is no script to generate $ARCH_INFO.info ! Exiting."
                exit 1
        fi

        $GENERATOR $XSIZ $YSIZ > $ALMOS_TOP/$ARCH_INFO.info

        echo -e "Generate $ARCH_INFO.bib :\t$ALMOS_TOP/tools/bin/info2bib -i $ALMOS_TOP/$ARCH_INFO.info -o $ALMOS_TOP/$ARCH_INFO.bib"
        $ALMOS_TOP/tools/bin/info2bib -i $ALMOS_TOP/$ARCH_INFO.info -o $ALMOS_TOP/$ARCH_INFO.bib

        return $?
}

bootloader()
{
        KERN_ELF=$ALMOS_TOP/kernel/obj.tsar/almos-mk-tsar-mipsel.elf
        KERN_ELF_OLD=$ALMOS_TOP/kernel/obj.tsar/almix-tsar-mipsel.elf 

        if [ ! -f $KERN_ELF ]; then
          ## Test the old name (on on master and almos_preloader branches)
          if [ ! -f $KERN_ELF_OLD ]; then    
            echo "You need the kernel (-k) to generate the bootloader."
            exit 1
          fi
        fi

        if [ $DBUG -eq 1 ]; then
          make -C $ALMOS_TOP/tools/soclib-bootloader MODE=DEBUG \
                ARCH_INFO=$ARCH_INFO.bib
        else
          make -C $ALMOS_TOP/tools/soclib-bootloader            \
                ARCH_INFO=$ARCH_INFO.bib
        fi

        return $?
}

harddisk()
{
        if [ ! -f $ALMOS_TOP/tools/soclib-bootloader/bootloader-tsar-mipsel.bin ]; then
          echo "You need an arch-info (-a), the kernel (-k) and the bootloader (-b) to generate a drive disk image"
          exit 1
        fi

        BOOTLOADER_ELF=$ALMOS_TOP/tools/soclib-bootloader/bootloader-tsar-mipsel.bin
        if [ ! -d /tmp/hdd ]; then
                mkdir -p /tmp/hdd/{home,etc,bin}
                mkdir -p /home/hdd/home/root
                echo "echo \"Almos-MK user shell\"" > /tmp/hdd/etc/shrc
        fi
        
        if [ -f $ALMOS_TOP/$IMAGE_NAME ]; then
                rm $ALMOS_TOP/$IMAGE_NAME
        fi

        ## Generate hard disk image : boot_loader + arch-bib + kernel in sector 2
        sh $SCRIPTS_DIR/gen_hdd-img.sh /tmp/hdd $ALMOS_TOP/$IMAGE_NAME

        ## Add apps from $ALMOS_USR_TOP/apps
        make -C $ALMOS_USR_TOP/apps TARGET=tsar install

        return $?
}

almos()
{
        if [ $DBUG -eq 1 ]; then
                make -j 8  -C $ALMOS_TOP/kernel MODE=DEBUG 
                make -j 16 -C $ALMOS_TOP/sys    MODE=DEBUG 
        else
                make -j 8  -C $ALMOS_TOP/kernel
                make -j 16 -C $ALMOS_TOP/sys
        fi
        return $?
}

hardconfig()
{
        ## Generate hard_config.h for our platform
        ## Two parameters are modified : we use 4 CPU per clusters
        ## (instead of 2) and we need 3 TTy instead of 1.
        python $GIET_TOP/giet_python/genmap                             \
                --arch=$TSAR_TOP/platforms/tsar_generic_leti            \
                --hard=$TSAR_TOP/platforms/tsar_generic_leti            \
                --x=$XSIZ                                               \
                --y=$YSIZ                                               \
                --p=4                                                   \
                --tty=3
        return $?
}

preloader()
{
        if [ ! -f $TSAR_TOP/platforms/tsar_generic_leti/hard_config.h ]; then
                echo "You need the hard_config.h (-arch) to generate preloader"
                exit 1
        fi
        make -C $TSAR_TOP/softs/tsar_boot/ \
                HARD_CONFIG_PATH=$TSAR_TOP/platforms/tsar_generic_leti
        return $?
}

tsar()
{
        make -C $TSAR_TOP/platforms/tsar_generic_leti
        return $?
}

launch()
{
        ## Check parameter
        if [ $USEX -eq 1 ]; then
                export SOCLIB_TTY=XTERM
        else
                export SOCLIB_TTY=FILES
        fi
        if [ $FMBF -eq 1 ]; then
                export SOCLIB_FRAMEBUFFER=
        else
                export SOCLIB_FRAMEBUFFER=HEADLESS
        fi
        cd $TSAR_TOP/platforms/tsar_generic_leti/
        trap break 1 2 9 15
        ./simul.x                                                       \
                -SOFT  $TSAR_TOP/softs/tsar_boot/preloader.elf          \
                -DISK  $ALMOS_TOP/hdd-img.bin                           \
                -THREADS 4

        cd $ROOT_DIR
        return 0
}

do_magic()
{
        ## If "--all" is set, do all and return
        if [ $LALL -eq 1 ]; then
                clean_tsar
                hardconfig
                preloader
                tsar
                clean_almos
                archinfo
                almos
                bootloader
                harddisk
                return $?
        fi

        ## Else, do :
        ## 1/ Check all parameters related to the hardware platform, and do what the user want
        if [ $TCLN -eq 1 ]; then clean_tsar;    fi
        if [ $HARD -eq 1 ]; then hardconfig;    fi
        if [ $PRLD -eq 1 ]; then preloader;     fi
        if [ $TSAR -eq 1 ]; then tsar;          fi

        ## 2/ Do the same thing for Almos-MK
        if [ $ACLN -eq 1 ]; then clean_almos;   fi
        if [ $ARCH -eq 1 ]; then archinfo;      fi
        if [ $KERN -eq 1 ]; then almos;         fi
        if [ $BOOT -eq 1 ]; then bootloader;    fi
        if [ $DISK -eq 1 ]; then harddisk;      fi

        ## 3/ Launch the simulation if needed
        if [ $LNCH -eq 1 ]; then launch;        fi

        return 0
}

## User MUST have source'd dev_env.sh !
cd $ROOT_DIR
if [ -z $ROOT_DIR ]; then
        echo "You must source dev_env.sh before using this script"
        exit 2
fi

## Check if there is any arguments, or if $1 is -h || --help
if [ -z $1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        usage
        exit 0
fi

## Get all arguments
ARGS_ARRAY=( $@ )                       # Gets all arguments in one array
ARGS_LEN=${#ARGS_ARRAY[@]}              # Get the number of arguments
ARGS_DONE=0

for i in ${ARGS_ARRAY[@]:0:$ARGS_LEN}; do
{
        case "$i" in
                ## Check options
                -d)             DBUG=1;;
                -usex)          USEX=1;;
                -f)             FMBF=1;;
                -x)             XSIZ=${ARGS_ARRAY[$(( $ARGS_DONE + 1))]}; shift;;
                -y)             YSIZ=${ARGS_ARRAY[$(( $ARGS_DONE + 1))]}; shift;;

                ## Check operations
                -c)             ACLN=1;;
                -csim)          TCLN=1;;
                -a)             ARCH=1;;
                -b)             BOOT=1;;
                -dd)            DISK=1;;
                -arch)          HARD=1;;
                -k)             KERN=1;; 
                -p)             PRLD=1;;
                -t)             TSAR=1;;
                --almos)        ACLN=1; ARCH=1; KERN=1; BOOT=1; DISK=1;;
                --almos-nc)     ARCH=1; KERN=1; BOOT=1; DISK=1;;
                --tsar)         TCLN=1; HARD=1; PRLD=1; TSAR=1;;
                --launch)       LNCH=1;;
                --all)          LALL=1;;
        esac
        ARGS_DONE=$(( $ARGS_DONE + 1 ))
}
done

do_magic

exit $?

## The end
