#syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Mario Wicke
# SPDX-FileContributor: Mario Wicke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/mariowi/docker-hsm-proxy

# https://hub.docker.com/r/linuxserver/openssh-server/tags?name=9.9
# https://github.com/linuxserver/docker-openssh-server/blob/master/Dockerfile
ARG BASE_IMAGE=linuxserver/openssh-server:version-9.9_p2-r0

#############################################################
# build softhsmv2 + pkcs11-proxy
#############################################################

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS builder

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

ARG PKCS11_PROXY_SOURCE_URL

ARG BASE_LAYER_CACHE_KEY

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required dev packages..."
  echo "#################################################"
  apk add --no-cache \
    `# required for configure/make:` \
    build-base \
    openssl-dev \
    `# additional packages required by pkcs11-proxy:` \
    cmake \
    libseccomp-dev

EOF

# https://github.com/hadolint/hadolint/wiki/DL3003 Use WORKDIR to switch to a directory
# hadolint ignore=DL3003
RUN <<EOF
  echo "#################################################"
  echo "Buildding pkcs11-proxy ..."
  echo "#################################################"
  curl -fsS "$PKCS11_PROXY_SOURCE_URL" | tar xvz
  mv pkcs11-proxy-* pkcs11-proxy
  cd pkcs11-proxy || exit 1
  cmake .
  make
  make install

EOF


#############################################################
# build final image
#############################################################

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} as final

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

ARG BASE_LAYER_CACHE_KEY

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apk add --no-cache \
    opensc `# contains pkcs11-tool` \
    tini 

  /mnt/shared/cmd/alpine-cleanup.sh

EOF

# linking softhsm2 config
RUN <<EOF
  mkdir /config/softhsm2
  ln -s /etc/softhsm2.conf /config/softhsm2/softhsm2.conf

  mkdir -p /var/lib/softhsm/tokens/
  chmod -R 700 /var/lib/softhsm

EOF

# copy pkcs11-proxy
COPY --from=builder /usr/local/bin/pkcs11-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libpkcs11-proxy* /usr/local/lib/

COPY root/ /

# Default configuration: can be overridden at the docker command line
ENV \
  INIT_SH_FILE='/opt/init-token.sh' \
  #
  TOKEN_AUTO_INIT=1 \
  TOKEN_LABEL="Test Token" \
  TOKEN_USER_PIN="1234" \
  TOKEN_USER_PIN_FILE="" \
  TOKEN_SO_PIN="5678" \
  TOKEN_SO_PIN_FILE="" \
  TOKEN_IMPORT_TEST_DATA=0 \
  #
  SOFTHSM_STORAGE=file \
  #
  PKCS11_DAEMON_SOCKET="tls://0.0.0.0:2345" \
  PKCS11_PROXY_TLS_PSK_FILE="/opt/test.tls.psk"

ARG OCI_authors
ARG OCI_title
ARG OCI_description
ARG OCI_source
ARG OCI_revision
ARG OCI_version
ARG OCI_created

ARG GIT_BRANCH
ARG GIT_COMMIT_DATE

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL \
  org.opencontainers.image.title="$OCI_title" \
  org.opencontainers.image.description="$OCI_description" \
  org.opencontainers.image.source="$OCI_source" \
  org.opencontainers.image.revision="$OCI_revision" \
  org.opencontainers.image.version="$OCI_version" \
  org.opencontainers.image.created="$OCI_created"

LABEL maintainer="$OCI_authors"

RUN <<EOF
  echo "#################################################"
  echo "Writing build_info..."
  echo "#################################################"
  cat <<EOT >/opt/build_info
GIT_REPO:    $OCI_source
GIT_BRANCH:  $GIT_BRANCH
GIT_COMMIT:  $OCI_revision @ $GIT_COMMIT_DATE
IMAGE_BUILD: $OCI_created
EOT
  cat /opt/build_info

EOF

EXPOSE 2345
#EXPOSE 2222

#VOLUME "/config/"
#VOLUME "/var/lib/softhsm/"
#VOLUME "/etc/ssh/"

ENTRYPOINT ["/sbin/tini", "--"]

#CMD ["/bin/bash", "/opt/run.sh"]
