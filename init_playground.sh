#!/usr/bin/env bash
# set -x 
# source playground_vars.sh
source playground_functions.sh

while getopts 'idh' OPTION; do
  case "$OPTION" in 
    i) 
      create_platform
      ;;
    d)
      purge_all
      ;;
    h)
      
      ;;
    ?) 
      playground_help
      ;;
  esac
done