#!/bin/bash

echo "==> bootstraping base ..."

. /bootstrap.sh

bootstrap_hostname

bootstrap_timezone

bootstrap_locales

bootstrap_remove_packages

bootstrap_clean_common

bootstrap_clean_base