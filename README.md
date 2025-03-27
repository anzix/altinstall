# Мой скрипт установки Alt Linux (Для личного использования)

Установка Alt Linux из под [образа Arch Linux](https://archlinux.org/download/)

После загрузки Arch Linux образа ISO необходимо подождать минуту чтобы сервис
`pacman-init.service` **успешно** инициализировал связку ключей. Если всё же вы
столкнулись с ключами при скачивании git просто выполните `systemctl restart pacman-init.service`
и снова произойдёт инициализация ключей

## [Для ноутбуков] Установка Wi-Fi-соединения и проверка сети

Вот что нужно делать как только вы вошли в установщик Arch Linux

```sh
# Необходимо узнать сетевой интерфейс устройства (device)
ip a

# Входим в интерактивный промпт
iwctl

# Сканируем на наличие новых сетей
# Вместо `device` должен быть ваш интерфейс полученный из предыдущей команды
[iwd] station device scan

# Выводим список сетей
[iwd] station device get-networks

# Подключаемся к сети заполняя свои данные
[iwd] station device connect SSID --passphrase ""

# Проверяем сеть
ping archlinux.org
```

***

Обновляем зеркала и устанавливаем git

```sh
pacman -Sy git
```

Клонируем репо и переходим в него

```sh
git clone https://github.com/anzix/altinstall && cd altinstall
```

> Перед тем как начать установку пробегитесь по выбору пакетов которые я указал
> в ``packages/base`` открыв любым текстовым редактором vim или nano. Выберете
> (закомментировав/раскомментировав) используя # (хэш) те пакеты которые вы
> нуждаетесь. Предоставляется выбор для драйверов между AMD и Nvidia

Начинаем установку

```sh
./0-preinstall.sh
```

Как только установка завершится вам нужно перезагрузится командой `sudo reboot`
и вытащить носитель. И вас будет встречать чистый Debian 12

## Установка софта из моих файлов

Перемещаем папку со скриптами в домашнюю директорию

```sh
sudo mv /altinstall ~
cd ~/altinstall

# Установка базовых пакетов с обработкой используя sed
sudo apt-get install $(sed -e '/^#/d' -e 's/#.*//' -e "s/'//g" -e '/^\s*$/d' -e 's/ /\n/g' packages/base | column -t)
```

Подобным образом вместо `base` вставляем другой файл

## Для тестирования на виртуалке

1. Для QEMU/KVM качаем пакеты `qemu-guest-agent spice-vdagent xorg-drv-qxl xorg-drv-spiceqxl`

> В оконных менеджерах (WM) для активации Shared Clipboard в терминале надо ввести `spice-vdagent`

2. Для VirtualBox (не проверенно):

   - Качаем пакеты `virtualbox-guest-additions xorg-drv-vmware`
   - Присваиваем пользователю группу vboxfs командой `usermod -a -G vboxsf $(whoami)`
   <!-- - Активируем systemd сервис `sudo systemctl enable vboxservice.service` -->

## Восстановление Debian, chroot из под LiveISO если выбрали Btrfs

Используя ISO образ [Arch Linux](https://archlinux.org/download/)

```sh
# Монтируем
mount -v -o subvol=@ /dev/vda2 /mnt
mount -v /dev/vda1 /mnt/boot/efi
for i in dev proc sys; do
  mount -v --rbind "/$i" "/mnt/$i"; mount -v --make-rslave "/mnt/$i"
done

# Навсякий экспортируем переменную PATH
export PATH="$PATH:/usr/sbin:/sbin:/bin:/usr/bin"

# Чрутимся
chroot /mnt
```

## Установка шрифтов семейства Nerd в Debian

Так как нету данных шрифтов в репозиториях придётся устанавливать их вручную\
Выполняем данный скрипт и выбираем шрифт на выбор и готово.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)"
```

## Игры и лаунчеры

Все необходимые 32 битные репозитории в обеих Sisyphus и p11 присутствуют, поэтому
пакетный менеджер сразу всё подтянет

```sh
# Установка системного пакета wine (используется wine-tkg от Kron4ek)
sudo apt-get install wine-tkg

# Установка steam вместе с i386 библиотеками
sudo apt-get install steam

# Установка portproton, для non-steam игр
sudo apt-get install portproton-installer
```

### Ускорение скачивания игр Steam (из пакетного менеджера)

Прирост скачивания очень заметен, в 3 раза быстрее

```sh
tee $HOME/.steam/steam/steam_dev.cfg > /dev/null << EOF
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
```

## Обновление до новой версии платформы (например с p10 на p11)

- [Источник Youtube](https://www.youtube.com/watch?v=zKRBfF5tpNw)
- [Источник Rutube](https://rutube.ru/video/bae18b893fd633a0dd688318b10608cb/)

TODO: Не проверено

1. Обновляем репозитории и скачиваем последние обновления текущей платформы p10

   ```sh
   # И
   sudo apt-get update && sudo apt-get dist-upgrade
   # Или используя epm
   epm full-upgrade
   ```

   И перезагружаемся

2. Открываем терминал и проверяем (на всякий) наличие пакета apt-repo

   ```sh
   sudo apt-get install apt-repo
   ```

3. Подключаем репозиторий новой платформы (p11) командой

   ```sh
   sudo apt-repo set p11
   ```

4. Окончательно обновляемся

   Вводим команду для обновления с использованием `-d` опции которая только
   скачает обновления

   > Без `-d` опции упадёт X сервер по причине обновления dbus

   ```sh
   sudo apt-get update && sudo apt-get dist-upgrade -d
   ```

   Заходим в TTY и выполняем обновление

   ```sh
   sudo apt-get dist-upgrade
   ```

5. Обновление ядра Linux

   Необходимо обновить ядро, на выбор 2 опции

   - `std-def` - это стандартное стабильное ядро
   - `un-def` - это самое свежее ядро

   ```sh
   sudo update-kernel -t std-def
   ```

   Перезагружаемся

   ```sh
   sudo reboot
   ```

## Проприетарные драйвера Nvidia

TODO: Не проверено

Переход на драйвера Nvidia, устанавливая сторонний пакет

```sh
sudo epm play switch-to-nvidia
```

## LightDM не появляется при входе в Read-only снимок Snapper

Необходимо отредактировать конфиг ``/etc/lightdm/lightdm.conf``, раскомментировать и изменить значение на true

```conf
[LightDM]
...
user-authority-in-system-dir=true
```

## Flatpak в Alt Linux

```sh
# Включить поддержку Flatpak вместе с добавлением Flathub репозитория
sudo apt-get install flatpak flatpak-repo-flathub

# Изменения вступят в силу после выхода из системы или перезагрузки системы.
```

## TODO: Qemu KVM в Alt Linux

```sh
# Минимальный набор
sudo apt install -y \
 qemu-kvm `# Основной пакет KVM` \
 libvirt-daemon-system `# Автозапуск модулей KVM` \
 libvirt-clients `# Бинарные файлы клиента такие как virsh` \
 virtinst `# Группа cli инструментов такие как virt-install, virt-clone, virt-xml и т.д` \
 virt-manager `# GUI менеджер виртуальных машин` \
 libguestfs-tools `# Монтировать гостевой образ виртуалки qemu в хост используя guestmount`

# Проверить доступные элементы
# Обращайте внимание только на раздел Qemu
virt-host-validate

# TODO: Добавить инструкцию по изолированной сети используя bridge (мост)

# Автозапуск вирт. сети default при запуске системы
sudo virsh net-autostart default
# Включить default вирт. сеть
sudo virsh net-start default
```

## Итог по Alt Linux Sisyphus/p11 с BTRFS + Snapper

У меня получилось завести Read-only снимки подобно Arch Linux, стоит отметить
что без примонтированного ``/tmp`` с опцией **rw** (чтение-запись) у меня не
получается вообще залогиниться в систему (даже через ssh). Никаких ошибок небыло
замечено на этапе инициализации systemd. Поэтому необходимо наличие `/tmp` в
fstab

Что касается других ошибок то вот, они не влияют на загрузку и восстановление.
Просто жалуются что файловая система в режиме только чтение

```txt
systemd-tmpfiles[674]: rm_rf(/var/tmp/systemd-private-faed5ff785324f7c9bc59878fb372a0d-systemd-logind.service-AmU7ur): Read-only file system
systemd-tmpfiles[674]: rm(/var/lib/rpm/__db.001): Read-only file system
systemd-tmpfiles[674]: rm(/var/lib/rpm/__db.002): Read-only file system
systemd-tmpfiles[674]: rm(/var/lib/rpm/__db.003): Read-only file system
systemd-tmpfiles[674]: rm(/var/lib/rpm/__db.004): Read-only file system
systemd[1]: Failed to start kheaders.service - Adjust kernel headers.
░░ Subject: Ошибка юнита kheaders.service
░░ Defined-By: systemd
░░ Support: https://lists.freedesktop.org/mailman/listinfo/systemd-devel
░░
░░ Произошел сбой юнита kheaders.service.
░░
░░ Результат: failed.
```

Статус `kheaders.service`

```txt
× kheaders.service - Adjust kernel headers
     Loaded: loaded (/usr/lib/systemd/system/kheaders.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Fri 2025-03-21 18:30:41 +05; 2min 31s ago
   Main PID: 683 (code=exited, status=1/FAILURE)
        CPU: 16ms

мар 21 18:30:41 alt systemd[1]: Starting kheaders.service - Adjust kernel headers...
мар 21 18:30:41 alt adjust_kernel_headers[711]: ln: не удалось создать символьную ссылку '/etc/sysconfig/kernel/include': Файловая система доступна только для чтения
мар 21 18:30:41 alt systemd[1]: kheaders.service: Main process exited, code=exited, status=1/FAILURE
мар 21 18:30:41 alt systemd[1]: kheaders.service: Failed with result 'exit-code'.
мар 21 18:30:41 alt systemd[1]: Failed to start kheaders.service - Adjust kernel headers.
```

## Проблемы и способы их решения



Поддержите меня за мои старания (´｡• ᵕ •｡`)

> [DonationAlerts](https://www.donationalerts.com/r/givefly)
