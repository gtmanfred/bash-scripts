#Created by Jaron Rolfe
#Released under the MIT License
#Copyright (c) 2014 Jaron Rolfe
#
#A quick script to install fail2ban on a rhel 5/6 server
#
#These commands are largely idempotent so error checking is not really required
#
#!/bin/bash
. /etc/init.d/functions

step() {
    echo "$@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@"
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

BACKUP_DIR="/home/rack/"

step "Checking Linux Version:"
try echo "Not implemented yet."
next

cmd=(yum install --quiet -y )
if yum repolist | grep -q nu_novell_com 2>&1 1>/dev/null; then
    cmd=(${cmd[@]} --disablerepo=nu_novell_com )
fi

if ! yum repolist | grep -q epel 2>&1 >/dev/null; then
    step "Installing epel-release:"
    try ${cmd[@]} epel-release
    next
fi

cmd=(${cmd[@]} --enablerepo=epel)

if ! rpm -q fail2ban; then
    step "Installing fail2ban:"
    try ${cmd[@]} fail2ban
    next
fi

step "Backing up fail2ban and iptables config:"
try cp /etc/fail2ban/jail.conf ${BACKUP_DIR}jail.conf.bak
try echo "Existing config backed up to ${BACKUP_DIR}jail.conf.bak"
#try iptables-save ${BACKUP_DIR}iptables.bak
#try echo "Live iptables config saved in ${BACKUP_DIR}iptables.bak"
next

step "Configuring fail2ban:"
try sed -i '/sendmail-whois\[name=SSH/d' /etc/fail2ban/jail.conf
if grep -q 'release 5\.' /etc/redhat-release; then
    try sed -i '214s/except Exception as e:/except Exception, e:/' /usr/share/fail2ban/server/filterpyinotify.py
fi
try chkconfig fail2ban on
try service fail2ban start 1>/dev/null
try service fail2ban status
next
