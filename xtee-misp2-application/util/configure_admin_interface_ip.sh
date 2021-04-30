#!/bin/bash
###
# Ask user to specify allowed IP address(es) for MISP2 admin interface access.
# Find user SSH session remote IP and use it as default.
# If that does not exist (e.g. when user has not logged in via SSH),
# use the IP already configured in xtee-misp2-base package ssl.conf file.
#
# Script takes an optional action, IP-list and conf file location arguments,
# it should be run in root permissions.
#
# Usage:
# ./configure_admin_interface_ip.sh [action [admin IPs [ssl.conf path]]]
#
# Example usage:
## Put interface to interactive mode and and ask user to *add* an allowed admin IP.
# ./configure_admin_interface_ip.sh
#
## Put interface in interactive mode and ask user to rewrite the entire allowed admin IP list.
# ./configure_admin_interface_ip.sh change
#
## Allow IP 192.168.1.1 without entering to interactive mode (keeps the original allowed list in place)
# ./configure_admin_interface_ip.sh add 192.168.1.1
#
## To give multiple IP-s from the command line, the IP addresses must be enclosed with quotes
## (so that it is received as one argument)
# ./configure_admin_interface_ip.sh change "192.168.1.1 10.1.1.0/24"
###

# Read input arguments
# By default, IPs are added to allowed IP list.
action=add
if [ "$1" != "" ]; then
    action=$1
fi

# If action is unknown, exit
action_regex="add|change|help"
if ! (echo "$action" | grep -Eq "$action_regex"); then
    echo "ERROR: Unknown action '$action'. Expected $action_regex."
    exit 1
elif [ "$action" == "help" ]; then
    # print out current script doctype
    perl -nle 'print if /^###$/ .. /^$/' $0
    exit 0
fi

##
# Validate configuration IP list. Checks for common errors, but not full validation.
#
# @param ip_conf string containing allowed IP-s.
# 	 The parameter format is IP v4 network addresses separated by spaces or commas.
#	 Term 'all' is also allowed.
#	 E.g '127.0.0.1 192.168.1.1 10.10.10.0/24'
# @return 0 if IP conf is considered valid, a non-zero integer if not
##
function is_valid_ip_conf {
    ip_conf=$1
    echo $ip_conf | grep -Eq "^(([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?|\s+|,)+|all$"
    return $?
}

# By default, new admin IP is not given, and script goes to interactive mode
new_admin_ip=""
if [ "$2" != "" ]; then
    new_admin_ip=$2
    # If given IP is not valid, exit
    if ! (is_valid_ip_conf $new_admin_ip); then
        echo "ERROR: Not valid IP address(es): '$new_admin_ip'."
        exit 1
    fi
fi

# Set apache conf location
apache_conf_location=/etc/apache2/sites-available/ssl.conf
if [ "$3" != "" ]; then
    apache_conf_location=$3
fi

# if apache conf is not writable, return error
if [[ ! -w "$apache_conf_location" ]]; then
    echo -n "ERROR: File $apache_conf_location cannot be accessed. "
    if [[ ! -f "$apache_conf_location" ]]; then
        echo "File does not exist."
    else
        echo "Are you root?"
    fi
    exit 1
fi
# done reading input arguments

# regex representing section that comes before allowed admin interface IP list in apache2 conf
admin_ip_bookmark_regex="<Location\s+\"\/[\/\*]*admin\/\*\">[^<]+Allow from "

# find allowed IPs from apache2 conf by substituting the file content with IP list
apache_conf_admin_ip=$(perl -p -e \
    "BEGIN{undef $/;} s/.*$admin_ip_bookmark_regex([^\n]+).*|.*/\1/smg" \
    $apache_conf_location)

# Do not substitute IP if conf IP was empty, meaning conf file was not found
# or the specific admin IP list was not found
if [ "$apache_conf_admin_ip" == "" ]; then
    echo "configure_admin_interface_ip.sh: WARNING: IP addresses allowed to access" \
        "administrator interface were not found from conf file $apache_conf_location."
    exit 1
else
    if echo "$apache_conf_admin_ip" | grep -Eq "[,\s]"; then
        echo "IP addresses from which administrator interface can be accessed" \
            "are currently '$apache_conf_admin_ip' in $apache_conf_location."
    else
        echo "IP address from which administrator interface can be accessed " \
            "is currently '$apache_conf_admin_ip' in $apache_conf_location."
    fi
    # Find SSH session remote IP.
    # IP address, if it exists, is read from netstat output
    ssh_remote_ip=$(netstat -tnpa | grep 'ESTABLISHED.*sshd' \
        | tail -n 1 | awk '{print $5}' | perl -nle 'print $& if m{.*(?=:)}')
    # Also run 'last' util and find currently logged in user remote IP.
    # This should be the same as ssh_remote_ip, so it is compared to ssh_remote_ip
    # to make sure the SSH user has not only establised connection, but also logged in
    logged_in_remote_ip=$(last | perl -nle "print $& if m{pts/[0-9]+.*still logged in\s*$}" \
        | awk '{print $2}' | head -n 1)
    #
    # if SSH remote IP exists, use that as default, else use existing IP in apache2 config
    if [ "$ssh_remote_ip" != "" ] && [ "$ssh_remote_ip" == "$logged_in_remote_ip" ] \
        && is_valid_ip_conf "$ssh_remote_ip"; then
        default_admin_ip="$ssh_remote_ip"
        echo "User remote IP is '$ssh_remote_ip'."
    else
        default_admin_ip="$apache_conf_admin_ip"
    fi

    # Run user input loop
    while [ "$new_admin_ip" == "" ]; do
        if [ "$action" == "change" ]; then
            echo -n "Please provide IP address(es) allowed to access administrator" \
                "interface: [default: $default_admin_ip] "
        elif [ "$action" == "add" ]; then
            echo -n "Please provide IP address(es) to be added to administrator" \
                "interface access list: [default: $default_admin_ip] "
        else
            echo "ERROR: Unknown action '$action'."
            exit 1
        fi

        read new_admin_ip < /dev/tty
        if [ "$new_admin_ip" == "" ]; then
            new_admin_ip="$default_admin_ip"
        fi
        # Check that input resembles list of IPv4 network addresses or keyward 'all'
        if ! (is_valid_ip_conf $new_admin_ip); then
            echo "Input '$new_admin_ip' is not a valid IPv4 network address or list thereof."
            # set to empty so that current loop would continue
            new_admin_ip=""
        fi
    done

    # If IP-s are added to existing ones
    if [ "$action" == "add" ]; then
        # If new admin IP-s have already been added, do not write
        if echo "$apache_conf_admin_ip" | grep -q "$new_admin_ip"; then
            echo "'$new_admin_ip' already enabled. Administrator interface access was not changed."
            exit 0
        else
            # Concatinate new IP-s with existing IP-s
            new_admin_ip="$apache_conf_admin_ip $new_admin_ip"
        fi
    # If IP-s are overwritten
    else
        # If the same IP already exists, there's no reason to overwrite
        if [ "$new_admin_ip" == "$apache_conf_admin_ip" ]; then
            echo "Administrator interface access '$new_admin_ip' was not changed."
            exit 0
        fi
    fi

    # Escape forward slashes in user input so it can be used as a perl-replacement string
    new_admin_ip_quoted="${new_admin_ip//[\/]/\\\/}"
    # Perform IP replacement in apache config file
    perl -pi -e "BEGIN{undef $/;} s/($admin_ip_bookmark_regex)[^\n]+/\${1}$new_admin_ip_quoted/smg" \
        $apache_conf_location
    service apache2 restart
    if [ $? -eq 0 ]; then
        echo "Administrator interface is now accessible from '$new_admin_ip'."
    else
        echo "configure_admin_interface_ip.sh: WARNING: " \
            "Allowed administrator interface access from '$new_admin_ip'" \
            "in $apache_conf_location, but failed to restart apache2."
    fi
    exit 0
fi
