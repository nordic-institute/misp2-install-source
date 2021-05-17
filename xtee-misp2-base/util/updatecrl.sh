#!/bin/bash
WGET=/usr/bin/wget
OPENSSL=/usr/bin/openssl
RM=/bin/rm
LOGGER=/usr/bin/logger
MAIL=/usr/bin/mail
CAT=/bin/cat
GREP=/bin/grep
APACHECTL=/usr/sbin/apache2ctl
CP=/bin/cp
C_REHASH=/usr/bin/c_rehash
TEE=/usr/bin/tee

CERTS=/etc/apache2/ssl/
REASON_TEMPLATE_PREFIX="reason.$$."

CRLPATH_MISP=/etc/apache2/ssl
ESTEID2011_CRLPATH=http://www.sk.ee/repository/crls/esteid2011.crl
ESTEID2015_CRLPATH=http://www.sk.ee/crls/esteid/esteid2015.crl
ESTEID2018_CRLPATH=http://c.sk.ee/esteid2018.crl
EE_ROOT_CRLPATH=http://www.sk.ee/crls/eeccrca/eeccrca.crl
EE_ROOT2018_CRLPATH=http://c.sk.ee/EE-GovCA2018.crl

##
# Log error with system logger and also to STDERR.
# @param TEXT error message, by default "Internal error" (if argument is not given).
# @param CAT_REASON if empty, print "Reason unknown" to STDERR,
#                   otherwise use contents of the given REASON tmp file
# @return exit 1
##
fail() {
    if [ "$1" != "" ]; then
        TEXT="$1"
    else
        TEXT="Internal error"
    fi

    ${LOGGER} -p user.err "$TEXT"
    echo "ERROR: $TEXT" >> /dev/stderr

    if [ "$2" != "" ]; then
        ${CAT} "$2" >> /dev/stderr
        ${RM} -f "$2"
    else
        echo "Reason unknown" >> /dev/stderr
    fi

    exit 1
}

##
# Download CRL from URL, convert it to PEM and place to Apache SSL certificate directory.
# In case CRL is unchanged since last download, do not download the file again. This is
# solved using wget -N argument.
# Timestamp comparison file is stored at /tmp directory as '{CRT-name}.crl.der'.
# @param url URL where CRL is downloaded from with WGET utility
# @return 1 if CRT was successfully converted to PEM and placed in Apache directory,
#         0 if PEM was unchanged
##
update_crl() {
    local rc=0
    local url=$1
    local crl=${url##*/}

    local oldcrl="${crl}.der"
    local newcrl=${crl}
    local reasonfile
    reasonfile=$(mktemp --tmpdir ${REASON_TEMPLATE_PREFIX}XXXXX)

    local pemcrl="${CRLPATH_MISP}/${crl}.pem"

    cd /tmp || fail "Not able to cd to /tmp!"

    if [ -f "${newcrl}" ]; then
        if ! ${RM} -f "${newcrl}" 2>> "${reasonfile}"; then
            fail "Unable to remove old temporary crl file." "${reasonfile}"
        fi
    fi

    # Copy old CRT file to new file location, to stop WGET downloading
    # a file with this name again, in case it has not changed
    ${CP} -fp "${oldcrl}" "${newcrl}" 2>> "${reasonfile}"

    # Download new version of CRL based on timestamp (-N)
    # Redirect standard error to standard out and use 'tee'
    # to display to both, STDOUT and ${REASON} file at the same time
    echo
    echo "Download CRL ${newcrl}"

    if ! ${WGET} --progress=bar:force -N --cache=off "${url}" 2>&1 | ${TEE} --append "${reasonfile}"; then
        fail "Unable to retrieve new CRL." "${reasonfile}"
    fi

    # If non-zero size PEM CRL does not exist or new CRL was just downloaded, verify it and convert to PEM
    if [ ! -s "${pemcrl}" ] || (! grep -q "Not Modified" "${reasonfile}"); then
        echo "Set up CRL ${newcrl}."

        # Copy the downloaded file back to old file's location (for WGET timestamp cache)
        echo " Copy $newcrl to $oldcrl."
        ${CP} -fp "${newcrl}" "${oldcrl}"

        # Rehash ${CERTS} before verifying CRL, otherwise openssl fails to find CRL issuer
        if [ "$pre_rehash_done" != "true" ]; then
            echo " Rehashing Apache symbolic links before verifying CRL."
            ${C_REHASH} ${CERTS}
            pre_rehash_done=true
        fi

        echo " Verify CRL $newcrl."
        # Verify CRL file
        ${OPENSSL} crl -CApath ${CERTS} -noout -inform DER < "${newcrl}" 2>> "${reasonfile}"

        if ! ${GREP} -q "verify OK" "${reasonfile}"; then
            fail "Unable to verify CRL." "${reasonfile}"
        fi

        # Convert CRL to PEM and add it to apache2 SSL cert directory
        ${RM} -f "${pemcrl}"
        echo " Convert CRL $newcrl to PEM and copy it to '$pemcrl'."
        if ! ${OPENSSL} crl -inform DER -outform PEM < "${newcrl}" > "${pemcrl}" 2>> "${reasonfile}" \
            || [ ! -s "${pemcrl}" ] \
            || ! (head -n 1 "${pemcrl}" | grep -q "BEGIN X509 CRL"); then
            fail "Converting ${newcrl} to '${pemcrl}' with openssl failed." "${reasonfile}"
        fi
        echo " Successfully converted ${newcrl} to '${pemcrl}'."

        local rc=1
    fi

    if [ -f "${reasonfile}" ]; then
        ${RM} -f "${reasonfile}"
    fi

    return $rc
}

echo "Updating CRL-s..."
dorestart=0

for crl in ${ESTEID2011_CRLPATH} ${ESTEID2015_CRLPATH} ${ESTEID2018_CRLPATH} ${EE_ROOT_CRLPATH} ${EE_ROOT2018_CRLPATH}; do
    if ! update_crl ${crl}; then
        dorestart=1
    fi
done

if [[ "$dorestart" == "1" && "$1" != "norestart" ]]; then
    echo "Rehashing Apache symbolic links."
    ${C_REHASH} ${CERTS}
    echo "Restarting Apache."
    ${APACHECTL} restart
fi
${RM} -f "/tmp/${REASON_TEMPLATE_PREFIX}*"
echo "CRL update done..."
