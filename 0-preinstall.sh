#!/bin/bash

# Раскомментируйте, чтобы просмотреть информацию об отладке когда выполняется
# скрипт
# set -xe

# Минимальный скрипт установки Alt Linux

# Русские шрифты
setfont cyr-sun16
sed -i "s/#\(en_US\.UTF-8\)/\1/; s/#\(ru_RU\.UTF-8\)/\1/" /etc/locale.gen
locale-gen
export LANG=ru_RU.UTF-8

clear

# Синхронизация часов материнской платы
timedatectl set-ntp true

read -p "Имя хоста (пустое поле - alt): " HOST_NAME
export HOST_NAME=${HOST_NAME:-alt}

read -p "Имя пользователя (Может быть только в нижнем регистре и без знаков, пустое поле - user): " USER_NAME
export USER_NAME=${USER_NAME:-user}

read -p "Пароль пользователя (поле ввода видимое): " USER_PASSWORD
export USER_PASSWORD

# Выпуск Alt Linux
echo "Доступные варианты установки Alt Linux, оба были протестированы"
echo "  p11 (Платформа 11) - является текущей стабильной версией Alt Linux"
echo "  Sisyphus (Регулярка) - это bleeding-edge, непрерывные обновления пакетов"
PS3="Какой выпуск системы вы хотите установить?: "
select ENTRY in "Sisyphus" "p11"; do
   export SUITE=${ENTRY}
   echo "Выбран ${LOCALE}"
   break
done

# Чтобы окружения подтягивали основные настройки локали
PS3="На каком языке будет система?: "
select ENTRY in "ru_RU" "en_US"; do
   export LOCALE=${ENTRY}
   echo "Выбран ${LOCALE}"
   break
done

PS3="Тип смены раскладки клавиатуры: "
select ENTRY in "Alt+Shift" "Caps Lock"; do
   export XKB_LAYOUT=${ENTRY}
   echo "Выбран ${XKB_LAYOUT}"
   break
done

PS3="Выберите диск, на который будет установлен Alt Linux: "
select ENTRY in $(lsblk -dpnoNAME | grep -P "/dev/sd|nvme|vd"); do
   export DISK=$ENTRY
   echo "Alt Linux будет установлен на ${DISK}."
   break
done

PS3="Выберите файловую систему: "
select ENTRY in "ext4" "btrfs"; do
   export FS=$ENTRY
   echo "Выбран ${FS}."
   break
done

# Предупредить пользователя об удалении старой схемы разделов.
echo "СОДЕРЖИМОЕ ДИСКА ${DISK} БУДЕТ СТЁРТО!"
read -p "Вы уверены что готовы начать установку? [y/N]: "
if ! [[ ${REPLY} =~ ^(yes|y)$ ]]; then
   echo "Выход.."
   exit
fi

# Удаляем старую схему разделов и перечитываем таблицу разделов
sgdisk --zap-all --clear $DISK # Удаляет (уничтожает) структуры данных GPT и MBR
partprobe $DISK                # Информировать ОС об изменениях в таблице разделов

# Разметка диска и перечитываем таблицу разделов
sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot $DISK
sgdisk -n 0:0:0 -t 0:8300 -c 0:root $DISK
partprobe $DISK

# Переменные для указывания созданных разделов
export DISK_EFI="/dev/disk/by-partlabel/boot"
export DISK_MNT="/dev/disk/by-partlabel/root"
# export DISK_HOME="/dev/disk/by-partlabel/home"

# Файловая система
if [ ${FS} = 'ext4' ]; then
   yes | mkfs.ext4 -L AltLinux $DISK_MNT
   # Отдельный раздел под /home
   # yes | mkfs.ext4 -L home $DISK_HOME
   mount -v $DISK_MNT /mnt
   # mkdir /mnt/home
   # mount $DISK_HOME /mnt/hom

elif [ ${FS} = 'btrfs' ]; then
   mkfs.btrfs -L AltLinux -f $DISK_MNT
   mount -v $DISK_MNT /mnt

   btrfs su cr /mnt/@
   btrfs su cr /mnt/@home
   btrfs su cr /mnt/@snapshots
   btrfs su cr /mnt/@home_snapshots
   btrfs su cr /mnt/@var_log
   btrfs su cr /mnt/@var_lib_containers
   btrfs su cr /mnt/@var_lib_docker
   btrfs su cr /mnt/@var_lib_machines
   btrfs su cr /mnt/@var_lib_portables
   btrfs su cr /mnt/@var_lib_libvirt_images
   btrfs su cr /mnt/@var_lib_AccountsService
   btrfs su cr /mnt/@var_lib_gdm

   umount -v /mnt

   # Небольшой обзор опций:
   #
   # noatime: нет времени доступа. Повышает производительность за счет отсутствия времени записи при обращении к файлу.
   # compress: активация сжатия для определённых типов файлов и выбор алгоритма сжатия
   # compress-force: активация принудительного сжатия для любого типа файлов и выбор алгоритма сжатия.
   # discard=async: освобождает неиспользуемый блок с SSD-накопителя, поддерживающего команду.
   #   При использовании параметра discard=async освобожденные экстенты не удаляются немедленно, а
   #   группируются вместе и позже обрезаются отдельным рабочим потоком, что снижает задержку commit.
   #   Вы можете отказаться от этого, если используете жесткий диск.
   #
   #   INFO: BTRFS с версией ядра 6.2 по умолчанию включена опция "discard=async"
   #
   # space_cache: позволяет ядру знать, где на диске находится блок свободного места, чтобы
   #   оно могло записывать данные сразу после создания файла.
   #
   # subvol: выбор вложенного тома для монтирования.
   #
   # INFO: BTRFS сам обнаруживает и добавляет опцию "ssd" при монтировании
   # TODO: Добавить подтом @var_lib_blueman (/var/lib/blueman) для использования bluetooth мышек внутри read-only снимка?
   mount -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@ $DISK_MNT /mnt
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@home $DISK_MNT /mnt/home
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@snapshots $DISK_MNT /mnt/.snapshots
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@home_snapshots $DISK_MNT /mnt/home/.snapshots
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_log $DISK_MNT /mnt/var/log
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_containers $DISK_MNT /mnt/var/lib/containers
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_docker $DISK_MNT /mnt/var/lib/docker
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_machines $DISK_MNT /mnt/var/lib/machines
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_portables $DISK_MNT /mnt/var/lib/portables
   mount --mkdir -v -o noatime,nodatacow,compress=zstd:2,space_cache=v2,subvol=@var_lib_libvirt_images $DISK_MNT /mnt/var/lib/libvirt/images
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvolid=5 $DISK_MNT /mnt/.btrfsroot
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_AccountsService $DISK_MNT /mnt/var/lib/AccountsService
   mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_gdm $DISK_MNT /mnt/var/lib/gdm

   # Востановление прав доступа по требованию пакетов
   # Вроде нет необходимости, судя по тестированию
   # chmod -v 755 /mnt/var/lib/AccountsService/
   # chmod -v 1770 /mnt/var/lib/gdm/
else
   echo "FS type"
   exit 1
fi

# Форматирование и монтирование загрузочного раздела
# TODO: Изменить точку монтирования на /mnt/boot для стандартизации, также
# незабыть проделать изменения в других местах
yes | mkfs.fat -F32 -n BOOT $DISK_EFI
mount -v --mkdir $DISK_EFI /mnt/boot/efi

# Установка необходимых пакетов
pacman -Sy --noconfirm wget

# Установка базовой системы
if [ "${SUITE}" = 'Sisyphus' ]; then
   # Получаю файлы
   ROOTFS_SISYPHUS_ROOTPATH="https://ftp.altlinux.org/pub/distributions/ALTLinux/images/${SUITE}/cloud/x86_64"
   ROOTFS_SISYPHUS_ARCHIVE="alt-sisyphus-rootfs-minimal-x86_64.tar.xz"
   ROOTFS_SISYPHUS_URL="${ROOTFS_SISYPHUS_ROOTPATH}/${ROOTFS_SISYPHUS_ARCHIVE}"
   # Загрузка
   pushd /tmp; wget "${ROOTFS_SISYPHUS_URL}"; popd
elif [ "${SUITE}" = 'p11' ]; then
   # Получаю файлы
   ROOTFS_P11_ROOTPATH="https://ftp.altlinux.org/pub/distributions/ALTLinux/images/${SUITE}/cloud/x86_64"
   ROOTFS_P11_ARCHIVE="alt-p11-rootfs-minimal-x86_64.tar.xz"
   ROOTFS_P11_URL="${ROOTFS_P11_ROOTPATH}/${ROOTFS_P11_ARCHIVE}"
   # Загрузка
   pushd /tmp; wget "${ROOTFS_P11_URL}"; popd
fi

# Распаковка rootfs
# Использовал gentoo подход к распаковке архива
tar xpvf /tmp/alt-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt
sync

# Для Minimal resolver работает если скопировать файл resolv
# Для Systemd при копировании resolver не работает и apt не работает из-за этого
cp -v /etc/resolv.conf /mnt/etc/

# Генерирую fstab
genfstab -U /mnt >/mnt/etc/fstab

# Добавление дополнительных разделов
# TODO: проверить загрузку в btrfs снимок без tmpfs
tee -a /mnt/etc/fstab >/dev/null <<EOF
# tmpfs
# Чтобы не изнашивать SSD во время сборки
# Также без него не запускается Xorg и все systemd сервисы при загрузке в Read-only снимок Grub-Btrfs
tmpfs                   /tmp            tmpfs           rw,nosuid,nodev,noatime,size=4G,mode=1777,inode64   0 0
EOF

# Копирование папки установочных скриптов
cp -r /root/altinstall /mnt

# Выполняю bind монтирование для подготовки к chroot
for i in dev proc sys; do
   mount -v --rbind "/$i" "/mnt/$i"; mount -v --make-rslave "/mnt/$i"
done

# Chroot'имся
chroot /mnt /bin/bash /altinstall/1-chroot.sh

# Действия после chroot
if read -re -p "Желаете ли выполнить chroot /mnt? [y/N]: " ans && [[ $ans == 'y' || $ans == 'Y' ]]; then
   chroot /mnt
   echo "Не забудьте самостоятельно размонтировать /mnt перед reboot!"
else
   umount -R /mnt
fi
