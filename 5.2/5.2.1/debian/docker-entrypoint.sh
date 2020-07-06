#!/bin/bash
set -e

COMMANDS="adduser debug fg foreground help kill logreopen logtail reopen_transcript run show status stop wait"
START="console start restart"

# make passwd entry for arbitrary running user (openshift / kubernetes)
if ! whoami &> /dev/null; then
    if [ -w /etc/passwd ]; then
        echo "${USER_NAME:-plonerunner}:x:$(id -u):0:${USER_NAME:-plonerunner} user:/plone:/sbin/nologin" >> /etc/passwd
    fi
    NONROOT="yes"
    # we are runnnig with group root!
    umask 002 
    echo + nonroot
fi
export HOME=/plone

# Fixing permissions for external /data volumes
mkdir -p /data/blobstorage /data/cache /data/filestorage /data/instance /data/log /data/zeoserver
mkdir -p /plone/instance/src
if [[ $NONROOT != "yes" ]]; then
  find /data  -not -user plone -exec chown plone:plone {} \+
  find /plone -not -user plone -exec chown plone:plone {} \+
fi

# Initializing from environment variables
if [[ $NONROOT != "yes" ]]; then
  gosu plone python /docker-initialize.py
else
  python /docker-initialize.py
fi

if [ -e "custom.cfg" ]; then
  if [ ! -e "bin/develop" ]; then
    buildout -c custom.cfg
    if [[ $NONROOT != "yes" ]]; then
      find /data  -not -user plone -exec chown plone:plone {} \+
      find /plone -not -user plone -exec chown plone:plone {} \+
      gosu plone python /docker-initialize.py
    else
      echo +nonroot: docker-initialize
      python /docker-initialize.py
    fi
  fi
fi

# ZEO Server
if [[ "$1" == "zeo"* ]]; then
  if [[ $NONROOT != "yes" ]]; then
    exec gosu plone bin/$1 fg
  else
    echo + nonroot: zeo 
    bin/$1 fg
  fi
fi

# Plone instance start
if [[ $START == *"$1"* ]]; then
  if [[ $NONROOT != "yes" ]]; then
    exec gosu plone bin/instance console
  else
    echo + nonroot: console
    bin/instance console
  fi
fi

# Plone instance helpers
if [[ $COMMANDS == *"$1"* ]]; then
  if [[ $NONROOT != "yes" ]]; then
    exec gosu plone bin/instance "$@"
  else
    echo + nonroot: instance
    bin/instance "$@"
  fi
fi

# Custom
exec "$@"
