#!/bin/bash

# Раскомментируйте, чтобы просмотреть информацию об отладке когда выполняется
# скрипт
# set -xe

# Экспортирую переменную PATH
# для работоспособности
export PATH="$PATH:/usr/sbin:/sbin:/bin:/usr/bin"

# Имя хоста
echo "${HOST_NAME}" > /etc/hostname
tee /etc/hosts > /dev/null << EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOST_NAME.localdomain $HOST_NAME
EOF

# Кол-во шрифтов которые необходимы в пакетах
LANGS="C:ru_RU.UTF-8:en_US.UTF-8:ja_JP.UTF-8"
sed -i "s|%_install_langs.*|%_install_langs ${LANGS}|" /etc/rpm/macros

# Выставляет основную системную локаль и другую информацию
# LC_COLLATE: Приятная сортировка скрытых каталогов и сравнения строк
# SUPPORTED=$LANGS: Другие языки для отображения шрифтов
tee /etc/sysconfig/i18n > /dev/null << EOF
LANG=$LOCALE.UTF-8
LC_COLLATE=C
EOF

# Смена раскладки клавиатуры в tty (раскладка работает)
# Должно решить проблему с systemd-vconsole-setup.service ошибкой
# loadkeys: Unable to open file: us: No such file or directory
# TODO: ru-mab — кодировка UTF-8 переключение на Ctrl+Shift
if [ "${XKB_LAYOUT}" = 'Alt+Shift' ]; then
  echo "KEYMAP=ruwin_alt_sh-UTF-8" > /etc/vconsole.conf
elif [ "${XKB_LAYOUT}" = 'Caps Lock' ]; then
  echo "KEYMAP=ruwin_cplk-UTF-8" > /etc/vconsole.conf
fi

# Шрифт в tty (необходим пакет `fonts-console-terminus`)
# TODO: Глянуть FONT=UniCyr_8x16 или LatArCyrHeb-16
echo "FONT=ter-v22b" >> /etc/vconsole.conf

# Обновление пакетов
apt-get update && apt-get upgrade -yy --enable-upgrade

# Если какие-нибудь пакеты будут "удержаны" от обновления
# то они будет обновлены используя dist-upgrade
apt-get dist-upgrade -yy

# Установка необходимых пакетов
#  zram-generator не доступен у p11
# FIXME: Установка должна происходить из входного файла с обработкой
apt-get update && apt-get install -yy kernel-image-6.12 kernel-headers-6.12 kernel-modules-drm-6.12 kernel-modules-staging-6.12 systemd hwclock sudo su fonts-console-terminus console-scripts kbd neovim git zsh htop fastfetch wget curl dbus-broker efibootmgr man man-db grub-efi mlocate fonts-console-terminus NetworkManager openssh-common openssh-server build-essential ca-certificates blacklist-pcspkr xdg-user-dirs btrfs-progs shadow-change notify-send

# Часовой пояс и апаратные часы
TIMEZONE=$(curl -s https://ipinfo.io/timezone)
ln -sfv /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
hwclock --systohc # Синхронизация аппаратных часов

# TODO: Не знаю будет ли работать?
# Для работы граф. планшета Xp-Pen G640 с OpenTabletDriver
echo "blacklist hid_uclogic" > /etc/modprobe.d/blacklist.conf

# Установка универсального host файла от StevenBlack (убирает рекламу и вредоносы из WEB'а)
# Обновление host файла выполняется командой: $ uphosts (доступна в dotfiles/base/zsh/funtctions.zsh)
wget -qO- https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
 | grep '^0\.0\.0\.0' \
 | grep -v '^0\.0\.0\.0 [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' \
 | sed '1s/^/\n/' \
 | tee --append /etc/hosts >/dev/null

# Не позволять системе становится раздудой
# Выставляю максимальный размер журнала systemd
sed -i 's/#SystemMaxUse=/SystemMaxUse=50M/g' /etc/systemd/journald.conf

# Разрешение на вход по SSH отключено для пользователя root
sed -ri -e "s/^#PermitRootLogin.*/PermitRootLogin\ no/g" /etc/openssh/sshd_config

# Пароль root пользователя
echo "root:${USER_PASSWORD}" | chpasswd

# Добавления юзера с созданием $HOME и присваивание групп к юзеру, оболочка zsh
# wheel - разрешение на команду sudo без ограничений
# adm - разрешение на прочтение логов из папки /var/log
# audio - только для pulse. Все остальные пользователи работают с pulse и pulse-access
# cdrom - позволяется использовать привод
# fuse - позволяет flatpak использовать /usr/bin/fusermount3 при установке ПО
# render - необходима для davinci resolve
useradd -m -G wheel,adm,dialout,dip,fuse,audio,video,input,cdrom,users,uucp,games,render -s /bin/zsh "${USER_NAME}"

# Пароль пользователя
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

# Контроль (специфичное для Alt Linux)

# Использование sudo обычному пользователю которому присвоена группа wheel
# https://www.altlinux.org/%D0%9F%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5_%D0%BF%D1%80%D0%B0%D0%B2_root
control sudowheel enabled

# Использование собственных каталогов XDG
# Use case: удобнее работать за терминалом
# Исправляет нарабочую команду xdg-user-dirs-update
control xdg-user-dirs enabled

# Добавляю root в sudoers, для того чтобы использовать sudo -u внутри chroot
# TODO: может откатить это поведение для non-chroot?
sed -i 's/^# root ALL=(ALL:ALL) ALL\.*/root ALL=(ALL:ALL) ALL/' /etc/sudoers

# Создание пользовательских XDG директорий
# Требование: необходимо активация `control xdg-user-dirs enabled`
# Используются английские названия для удобной работы с терминала
LC_ALL=C sudo -u "${USER_NAME}" xdg-user-dirs-update --force

# Настройка snapper и btrfs в случае обнаружения
if [ "${FS}" = 'btrfs' ]; then

  # Пакет для обслуживания btrfs:
  apt-get install -yy btrfsmaintenance

  # Snapper пакеты
  apt-get install -yy inotify-tools gawk snapper grub-btrfs

  # Размонтируем и удаляем /.snapshots и /home/.snapshots
  umount -v /.snapshots /home/.snapshots
  rm -rfv /.snapshots /home/.snapshots

  # Создаю конфигурацию Snapper для / и /home
  # Snapper отслеживать /home будет создавать снимки всех пользователей (если они присутствуют)
  snapper --no-dbus -c root create-config /
  snapper --no-dbus -c home create-config /home

  # Удаляем подтом /.snapshots и /home/.snapshots Snapper'а
  btrfs subvolume delete /.snapshots /home/.snapshots

  # Пересоздаём и переподключаем /.snapshots и /home/.snapshots
  mkdir -v /.snapshots /home/.snapshots
  mount -v -a

  # Меняем права доступа для легкой замены снимка @ в любое время без потери снимков snapper.
  chmod -v 750 /.snapshots /home/.snapshots

  # Доступ к снимкам для non-root пользователям
  chown -vR :wheel /.snapshots /home/.snapshots

  # Настройка Snapper

  # Синхронизировать права на доступ к снимкам при создании и удалении
  sed -i "s|^SYNC_ACL=.*|SYNC_ACL=\"yes\"|g" /etc/snapper/configs/root
  sed -i "s|^SYNC_ACL=.*|SYNC_ACL=\"yes\"|g" /etc/snapper/configs/home

  # Установка лимата снимков для /
  sed -i "s|^TIMELINE_LIMIT_HOURLY=.*|TIMELINE_LIMIT_HOURLY=\"3\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_DAILY=.*|TIMELINE_LIMIT_DAILY=\"6\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_WEEKLY=.*|TIMELINE_LIMIT_WEEKLY=\"0\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_MONTHLY=.*|TIMELINE_LIMIT_MONTHLY=\"0\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_YEARLY=.*|TIMELINE_LIMIT_YEARLY=\"0\"|g" /etc/snapper/configs/root

  # Не создавать timeline-снимки для /home
  sed -i "s|^TIMELINE_CREATE=.*|TIMELINE_CREATE=\"no\"|g" /etc/snapper/configs/home

  # mlocate не показывает индексы найденых файлов если используется файловая система Btrfs
  # Данная правка конфига исправляет это
  # Источник: https://devctrl.blog/posts/plocate-not-a-drop-in-replacement-if-you-re-using-btfrs/
  sed -i 's/PRUNE_BIND_MOUNTS =.*/PRUNE_BIND_MOUNTS = "no"/' /etc/updatedb.conf

  # Предотвращение индексирования снимков программой "updatedb", что замедляло бы работу системы
  sed -i '/PRUNEPATHS/s/"$/ \/\.btrfsroot \/\.snapshots \/home\/\.snapshots"/' /etc/updatedb.conf

  # Не создавать снимки при загрузке системы
  systemctl disable snapper-boot.timer

  # Обслуживание BTRFS (btrfsmaintenance)
  systemctl enable btrfs-scrub.timer

  # Меню снимков Grub-Btrfs
  systemctl enable grub-btrfsd

  # ВНИМАНИЕ:
  # Откат снимков при использовании snapper-rollback не работает из-за
  # отсуствтвия python3-btrfsutil (btrfsutil) в составе btrfs-progs. Поэтому
  # откат придётся делать вручную как это сделать описано ниже по ссылке
  # https://anzix.github.io/posts/snapper-snapshots/#mozhno-oboitis-bez-snapper-rollback-ot-sdelat-eto-vruchnuiu
  #
  # sudo mv /.btrfsroot/@ /.btrfsroot/@$(date +"%Y-%m-%dT%H:%M")
  # sudo btrfs subvolume snapshot /.btrfsroot/@snapshots/<номер>/snapshot /.btrfsroot/@
  # sudo btrfs subvolume set-default /.btrfsroot/@
  #
  # Удалить сломанный/ненужный снимок
  # sudo btrfs su delete /.btrfsroot/@2023-08-29T01:33

  # Устанавливаем простой и удобный CLI инструмент для отката системы внутри снимка
  # Использование: sudo snapper-rollback <номер_снимка>
  # git clone https://github.com/jrabinow/snapper-rollback.git /tmp/snapper-rollback
  # pushd /tmp/snapper-rollback
  # cp -v snapper-rollback.py /usr/local/bin/snapper-rollback
  # cp -v snapper-rollback.conf /etc/
  # # Редактирую конфигурационный файл snapper-rollback что точка монтирования /.btrfsroot
  # sed -i "s|^mountpoint.*|mountpoint = /.btrfsroot|" /etc/snapper-rollback.conf
  # popd

  # Кароче не работает https://github.com/pavinjosdev/snap-apt, не выполняет pre
  # post снимки при apt-get транзакции. TODO: Нужно что-то другое искать
fi

# Размер Zram
# tee -a /etc/systemd/zram-generator.conf >> /dev/null << EOF
# [zram0]
# zram-size = min(min(ram, 4096) + max(ram - 4096, 0) / 2, 32 * 1024)
# compression-algorithm = zstd
# EOF

# TODO: добавить мои sysctl настройки

# Добавления моих опций ядра grub
# intel_iommu=on - Включает драйвер intel iommu
# iommu=pt - Проброс только тех устройств которые поддерживаются
# zswap.enabled=0 - Отключает приоритетный zswap который заменяется на zram
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 mitigations=off intel_iommu=on iommu=pt amdgpu.ppfeaturemask=0xffffffff cpufreq.default_governor=performance zswap.enabled=0"/g' /etc/default/grub

# Рекурсивная правка разрешений в папке скриптов
# chmod -R 700 /altinstall
# chown -R 1000:users /altinstall

# Врубаю сервисы
# BTRFS: discard=async можно использовать вместе с fstrim.timer
systemctl enable NetworkManager.service # Сеть
# systemctl enable bluetooth.service # Bluetooth
systemctl enable sshd.service # SSH
systemctl enable fstrim.timer # Trim для SSD
# systemctl enable fancontrol.service # Контроль вентиляторов GPU

# Установка и настройка Grub
#sed -i -e 's/#GRUB_DISABLE_OS_PROBER/GRUB_DISABLE_OS_PROBER/' /etc/default/grub # Обнаруживать другие ОС и добавлять их в grub (нужен пакет os-prober)
# TODO: Для стандартизации (если точка монтирования /mnt/boot) выставить --efi-directory=/boot
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
update-grub
