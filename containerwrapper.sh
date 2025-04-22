#!/usr/bin/env sh

YOCTO_GID="1000"
YOCTO_UID="1000"
YOCTO_USER="ubuntu"
subgidSize=$(( $(podman info --format "{{ range .Host.IDMappings.GIDMap }}+{{.Size }}{{end }}" ) - 1 ))
subuidSize=$(( $(podman info --format "{{ range .Host.IDMappings.UIDMap }}+{{.Size }}{{end }}" ) - 1 ))

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

WORKDIR="$(pwd)"

if [ -z "$1" ] ; then
    echo "No argument supplied - Running interactive"
    INTERACTIVE="-it"
    COMMAND=""
else
    echo "Running: $@"
    INTERACTIVE="-it"
    COMMAND="$@"
fi


podman run \
    ${INTERACTIVE} --network=host --privileged --rm  \
    --gidmap ${YOCTO_GID}:0:1 \
    --gidmap $((YOCTO_GID+1)):$((YOCTO_GID+1)):$((subgidSize-YOCTO_GID)) \
    --gidmap 0:1:${YOCTO_GID} \
    --uidmap ${YOCTO_UID}:0:1 \
    --uidmap $((YOCTO_UID+1)):$((YOCTO_UID+1)):$((subuidSize-YOCTO_UID)) \
    --uidmap 0:1:${YOCTO_UID} \
    --user "${YOCTO_USER}:${YOCTO_USER}" \
    --mount type=bind,source=${WORKDIR},target=${WORKDIR} --workdir "${WORKDIR}" \
    crops/yocto:ubuntu-24.04-base \
    ${COMMAND}
