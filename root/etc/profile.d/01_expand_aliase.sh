#!/bin/bash
shopt -e expand_aliases
alias pkcs11-tool_softhsm='pkcs11-tool --module /usr/local/lib/softhsm/libsofthsm2.so'
alias pkcs11-tool='pkcs11-tool --module /usr/local/lib/softhsm/libsofthsm2.so'
