#! /usr/bin/env bash

THEME='fallout-grub-theme'
LANG='English'

# Change to temporary directory
cd $(mktemp -d)

# Pre-authorise sudo
sudo echo 2>>./error

# Select language, optional
declare -A LANGS=(
    [Chinese]=zh_CN
    [English]=EN
    [French]=FR
    [German]=DE
    [Italian]=IT
    [Norwegian]=NO
    [Portuguese]=PT
    [Russian]=RU
    [Spanish]=ES
    [Ukrainian]=UA
)

LANG_NAMES=($(echo ${!LANGS[*]} | tr ' ' '\n' | sort -n))

PS3='Please select language #: '
select l in "${LANG_NAMES[@]}"
do
    if [[ -v LANGS[$l] ]]; then
        LANG=$l
        break
    else
        echo 'No such language, try again'
    fi
done < /dev/tty

# Detect distro and set GRUB location and update method
GRUB_DIR='grub'
UPDATE_GRUB=''
BOOT_MODE='legacy'

if [[ -d /boot/efi && -d /sys/firmware/efi ]]; then
    BOOT_MODE='UEFI'
fi

echo "Boot mode: ${BOOT_MODE}"

if [[ -e /etc/os-release ]]; then

    source /etc/os-release

    if [[ "$ID" =~ (debian|ubuntu|solus) || \
          "$ID_LIKE" =~ (debian|ubuntu) ]]; then

        UPDATE_GRUB='update-grub'

    elif [[ "$ID" =~ (arch|gentoo) || \
            "$ID_LIKE" =~ (archlinux|gentoo) ]]; then

        UPDATE_GRUB='grub-mkconfig -o /boot/grub/grub.cfg'

    elif [[ "$ID" =~ (centos|fedora|opensuse) || \
            "$ID_LIKE" =~ (fedora|rhel|suse) ]]; then

        GRUB_DIR='grub2'
        GRUB_CFG='/boot/grub2/grub.cfg'

        if [[ "$BOOT_MODE" = "UEFI" ]]; then
            GRUB_CFG="/boot/efi/EFI/${ID}/grub.cfg"
        fi

        UPDATE_GRUB="grub2-mkconfig -o ${GRUB_CFG}"

        # BLS etries have 'kernel' class, copy corresponding icon
        if [[ -d /boot/loader/entries && -e ${THEME}-master/icons/${ID}.png ]]; then
            cp ${THEME}-master/icons/${ID}.png ${THEME}-master/icons/kernel.png
        fi
    fi
fi

echo 'Fetching theme archive'
wget -O ${THEME}.zip https://github.com/shvchk/${THEME}/archive/master.zip 2>>./error

echo 'Unpacking theme'
unzip ${THEME}.zip 2>>./error

# Checking for errors when some software packages aren't installed, thus may make installation fail
if [ -n "$(cat ./error)" ]; then
	cat ./error
	echo "Some errors occured, please check for the errors listed"
	rm -f ./error
	exit -1
fi

if [[ "$LANG" != "English" ]]; then
    echo "Changing language to ${LANG}"
    sed -i -r -e '/^\s+# EN$/{n;s/^(\s*)/\1# /}' \
              -e '/^\s+# '"${LANGS[$LANG]}"'$/{n;s/^(\s*)#\s*/\1/}' ${THEME}-master/theme.txt
fi

echo 'Creating GRUB themes directory'
sudo mkdir -p /boot/${GRUB_DIR}/themes/${THEME}

echo 'Copying theme to GRUB themes directory'
sudo cp -r ${THEME}-master/* /boot/${GRUB_DIR}/themes/${THEME}

echo 'Removing other themes from GRUB config'
sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub

echo 'Making sure GRUB uses graphical output'
sudo sed -i 's/^\(GRUB_TERMINAL\w*=.*\)/#\1/' /etc/default/grub

echo 'Removing empty lines at the end of GRUB config' # optional
sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /etc/default/grub

echo 'Adding new line to GRUB config just in case' # optional
echo | sudo tee -a /etc/default/grub

echo 'Adding theme to GRUB config'
echo "GRUB_THEME=/boot/${GRUB_DIR}/themes/${THEME}/theme.txt" | sudo tee -a /etc/default/grub

echo 'Removing theme installation files'
rm -rf ${THEME}.zip ${THEME}-master

echo 'Updating GRUB'
if [[ $UPDATE_GRUB ]]; then
    eval sudo "$UPDATE_GRUB"
else
    cat << '    EOF'
    --------------------------------------------------------------------------------
    Cannot detect your distro, you will need to run `grub-mkconfig` (as root) manually.

    Common ways:
    - Debian, Ubuntu, Solus and derivatives: `update-grub` or `grub-mkconfig -o /boot/grub/grub.cfg`
    - RHEL, CentOS, Fedora, SUSE and derivatives: `grub2-mkconfig -o /boot/grub2/grub.cfg`
    - Arch, Gentoo and derivatives: `grub-mkconfig -o /boot/grub/grub.cfg`
    --------------------------------------------------------------------------------
    EOF
fi
