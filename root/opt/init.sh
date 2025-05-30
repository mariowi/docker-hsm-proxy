#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Mario Wicke
# SPDX-FileContributor: Mario Wicke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/mariowi/docker-hsm-proxy

# shellcheck disable=SC1091  # Not following: /opt/bash-init.sh was not specified as input
type -t log >/dev/null || source /opt/bash-init.sh



if [ -z "${SSH_PUB_KEY}" ]; then
	echo "=> Please pass your public key in the SSH_KEY environment variable"
	exit 1
fi

    ssh-keygen -A

# ToDo:? set rights for .ssh folders - chmod 0700 /root/.ssh
for MYHOME in /root /home/docker; do
	echo "=> Adding SSH key to ${MYHOME}"
	mkdir -p ${MYHOME}/.ssh
	chmod go-rwx ${MYHOME}/.ssh
	echo "${SSH_PUB_KEY}" > ${MYHOME}/.ssh/authorized_keys
	chmod go-rw ${MYHOME}/.ssh/authorized_keys
	echo "=> Done!"
done
chown -R docker:docker /home/docker/.ssh

echo "========================================================================"
echo "You can now connect to this container via SSH using:"
echo ""
echo "    ssh -p <port> <user>@<host>"
echo ""
echo "Choose root (full access) or docker (limited user account) as <user>."
echo "========================================================================"

# Run original SoftHSM2 Token Init file
source "/opt/init-token.sh"
