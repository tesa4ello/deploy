#!/usr/bin/env bash
# deploy.sh — первоначальная настройка Debian
set -euo pipefail

# --- Цвета ---
RED='\e[1;31m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; CYAN='\e[1;36m'; DEF='\e[0m'
info()  { echo -e "${CYAN}[INFO]${DEF} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${DEF} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${DEF} $*"; }
err()   { echo -e "${RED}[ERR ]${DEF} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Запускайте от root"

# --- 0. Установка hostname ---
read -rp "Hostname для сервера: " NEW_HOSTNAME < /dev/tty
[[ -n "$NEW_HOSTNAME" ]] || err "Hostname не может быть пустым"
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "$NEW_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts 2>/dev/null || true
ok "Hostname установлен: $NEW_HOSTNAME"

# --- 1. Очистка старых bashrc ---
info "Удаляю /root/.bashrc и /etc/skel/.bashrc"
rm -f /root/.bashrc /etc/skel/.bashrc

# --- 2. Установка кастомного /etc/bash.bashrc ---
info "Разворачиваю /etc/bash.bashrc"
cp /etc/bash.bashrc /etc/bash.bashrc.bak.$(date +%s) 2>/dev/null || true

cat > /etc/bash.bashrc <<'BASHRC_EOF'
# If not running interactively, don't do anything
[ -z "$PS1" ] && return
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
debian_chroot=$(cat /etc/debian_chroot)
fi
# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
PROMPT_COMMAND='echo -ne "\033]0;[ ${USER}@${HOSTNAME}: ${PWD} ]\007"'
;;
*)
;;
esac
# enable bash completion in interactive shells
#if ! shopt -oq posix; then
#  if [ -f /usr/share/bash-completion/bash_completion ]; then
#    . /usr/share/bash-completion/bash_completion
#  elif [ -f /etc/bash_completion ]; then
#    . /etc/bash_completion
#  fi
#fi
# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
function command_not_found_handle {
# check because c-n-f could've been removed in the meantime
if [ -x /usr/lib/command-not-found ]; then
/usr/lib/command-not-found -- "$1"
return $?
elif [ -x /usr/share/command-not-found/command-not-found ]; then
/usr/share/command-not-found/command-not-found -- "$1"
return $?
else
printf "%s: command not found
" "$1" >&2
return 127
fi
}
fi
case $- in
*i*) ;;
*) return;;
esac
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth
# append to the history file, don't overwrite it
shopt -s histappend
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
fi
tput sgr0     # Возврат цвета в "нормальное" состояние
clear
export EDITOR=nano
# Цвет текста:
export BLACK="\e[0;30m"         #  ${BLACK}
export RED="\e[0;31m"           #  ${RED}
export GREEN="\e[0;32m"         #  ${GREEN}
export YELLOW="\e[0;33m"        #  ${YELLOW}
export BLUE="\e[0;34m"  #  ${BLUE}
export MAGENTA="\e[0;35m"       #  ${MAGENTA}
export CYAN="\e[0;36m"          #  ${CYAN}
export GRAY="\e[0;37m"          #  ${GRAY}
export DEF="\e[0;39m"           #  ${DEF}
export DGRAY="\e[1;30m"         #  ${DGRAY}
export LRED="\e[1;31m"          #  ${LRED}
export LGREEN="\e[1;32m"        #  ${LGREEN}
export LYELLOW="\e[1;33m"       #  ${LYELLOW}
export LBLUE="\e[1;34m"         #  ${LBLUE}
export LMAGENTA="\e[1;35m"      #  ${LMAGENTA}
export LCYAN="\e[1;36m"         #  ${LCYAN}
export WHITE="\e[1;37m"         #  ${WHITE}
if [ `whoami` = 'root' ]; then
COLOR=$RED
else
COLOR=$GREEN
fi
#Меняем приглашение командной строки
export PS1="[ \[$COLOR\]\u\[$DEF\]@\[$LBLUE\]\h\[$DEF\]:\[$LYELLOW\]\w/\[$DEF\] ]\[$COLOR\]\\\$\[$DEF "
export PS2=">"
export PS3="?) "
export PS4="[DEBUG]: "
DOTSTRING=""
for((i=1;i<$COLUMNS;i++))
do
DOTSTRING="$DOTSTRING=";
done
header(){
local LINECOLOR=$LBLUE
local TEXTCOLOR=$YELLOW
local chars=$DOTSTRING
local str=" ${@:1} "
local half=$(( (${#chars} - ${#str})/2 ))
local rest=$(( ${#chars} - ${#str} - $half ))
echo -e
echo -e "$LINECOLOR${chars:0:$half}$TEXTCOLOR${str}$LINECOLOR${chars:0:$rest}$DEF"
echo -e
}
echo -e ${LCYAN}
figlet -ct "Welcome to `cat /etc/hostname`"
fastfetch
header "Место на разделах"
df -h | awk 'FNR<2||/^(\/dev)/'
ERRORS=$(dmesg | grep error | grep -v errors)
if [ -n "$ERRORS" ]; then
header "Последние ошибки"
echo "$ERRORS"
return 0
fi
alias ll='ls -lha --color=auto'
header "Удачного дня!"
BASHRC_EOF
ok "bash.bashrc установлен"

# --- 3. Обновление системы + чистка старых ядер ---
info "Обновление пакетов"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove --purge -y
apt-get autoclean -y

info "Удаление старых ядер (оставляю текущее: $(uname -r))"
CURRENT_VER=$(uname -r | sed 's/-[^-]*$//')
for pkg in $(dpkg -l 'linux-image-[0-9]*' 'linux-headers-[0-9]*' 2>/dev/null \
            | awk '/^ii/ {print $2}' \
            | grep -vE "$(uname -r|sed 's/\./\\./g')|${CURRENT_VER}"); do
    apt-get purge -y "$pkg" || warn "не удалось удалить $pkg"
done
update-grub || true
ok "Система обновлена"

# --- 4. Базовые пакеты ---
info "Установка базовых пакетов"
apt-get install -y curl wget sudo ufw btop figlet iptables
ok "Пакеты установлены"

# --- 5. fastfetch или neofetch ---
info "Установка fastfetch"
if apt-get install -y fastfetch; then
    ok "fastfetch установлен"
else
    warn "fastfetch недоступен, ставлю neofetch"
    apt-get install -y neofetch
fi

# --- 6. Настройка UFW ---
info "Настройка UFW"

# Автопереключение на iptables-legacy (нужно для OpenVZ/LXC)
if command -v iptables-legacy &>/dev/null; then
    info "Переключаю iptables на legacy-режим (совместимость с VPS)"
    update-alternatives --set iptables  /usr/sbin/iptables-legacy  2>/dev/null || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
fi

# Функция безопасного чтения порта
read_port() {
    local val
    while true; do
        read -rp "Порт SSH [22]: " val < /dev/tty
        val="${val//[[:space:]]/}"
        val="${val:-22}"
        if [[ "$val" =~ ^[0-9]+$ ]] && (( val >= 1 && val <= 65535 )); then
            echo "$val"
            return
        fi
        warn "Некорректный порт '$val'. Введите число от 1 до 65535."
    done
}

SSH_PORT=$(read_port)
info "Использую порт SSH: $SSH_PORT"
ufw allow "$SSH_PORT"/tcp comment 'SSH' || err "Не удалось добавить правило для порта $SSH_PORT"

read -rp "IP-адреса для полного доступа (через пробел, Enter — пропустить): " ALLOW_IPS < /dev/tty
for ip in $ALLOW_IPS; do
    if [[ $ip =~ ^[0-9./]+$ ]]; then
        ufw allow from "$ip" comment "whitelist $ip"
        ok "Добавлен whitelist: $ip"
    else
        warn "Пропущен некорректный адрес: $ip"
    fi
done

read -rp "Открыть HTTP (80)? [y/N]: " OPEN_HTTP < /dev/tty
[[ ${OPEN_HTTP,,} == y ]] && ufw allow 80/tcp comment 'HTTP'

read -rp "Открыть HTTPS (443)? [y/N]: " OPEN_HTTPS < /dev/tty
[[ ${OPEN_HTTPS,,} == y ]] && ufw allow 443/tcp comment 'HTTPS'

if [[ -z "$ALLOW_IPS" && "$SSH_PORT" != "22" ]]; then
    warn "Вы не указали IP для whitelist и сменили порт SSH."
    warn "Убедитесь, что сможете подключиться после включения firewall."
    read -rp "Продолжить и включить UFW? [y/N]: " CONFIRM < /dev/tty
    [[ ${CONFIRM,,} == y ]] || SKIP_UFW=1
fi

if [[ -z "${SKIP_UFW:-}" ]]; then
    ufw disable 2>/dev/null || true
    ufw --force enable
    ufw status verbose
    ok "UFW включён"
fi

# --- 7. Создание пользователя ---
read -rp "Имя нового пользователя: " NEWUSER < /dev/tty
[[ -n "$NEWUSER" ]] || err "Имя не может быть пустым"
id "$NEWUSER" &>/dev/null && err "Пользователь $NEWUSER уже существует"

adduser --gecos "" "$NEWUSER"
usermod -aG sudo "$NEWUSER"
ok "Пользователь $NEWUSER создан и добавлен в sudo"

# --- 8. Смена пароля root ---
info "Смена пароля root"
passwd root

# --- 9. Перенос SSH-ключей ---
if [[ -d /root/.ssh && -f /root/.ssh/authorized_keys ]]; then
    info "Переношу SSH-ключи в ~$NEWUSER/.ssh"
    mkdir -p "/home/$NEWUSER/.ssh"
    cp /root/.ssh/authorized_keys "/home/$NEWUSER/.ssh/"
    for k in /root/.ssh/id_*; do
        [[ -e "$k" && "$k" != *.pub ]] && cp "$k" "/home/$NEWUSER/.ssh/"
    done
    chown -R "$NEWUSER:$NEWUSER" "/home/$NEWUSER/.ssh"
    chmod 700 "/home/$NEWUSER/.ssh"
    chmod 600 "/home/$NEWUSER/.ssh"/* 2>/dev/null || true
    ok "Ключи перенесены"
else
    warn "Ключей у root не найдено — пропуск"
fi

# --- 10. Отключение входа по паролю SSH ---
info "Отключаю вход по паролю SSH"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-no-password.conf <<'SSH_EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
SSH_EOF
chmod 644 /etc/ssh/sshd_config.d/99-no-password.conf

grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config \
    || echo -e "\nInclude /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config

systemctl restart sshd || systemctl restart ssh
ok "SSH настроен: только ключи"

# --- 11. Перезагрузка ---
info "Готово. Перезагрузка через 5 секунд (Ctrl+C для отмены)..."
sleep 5
reboot
