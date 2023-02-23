#!/usr/bin/env bash
# set -x 
# source playground_vars.sh
source playground_functions.sh

  # while getopts 'idh' OPTION; do
  #   case "$OPTION" in 
  #     i) 
  #       create_platform
  #       ;;
  #     d)
  #       purge_all
  #       ;;
  #     h)
  #       playground_help
  #       ;;
  #     ?) 
  #       playground_help
  #       ;;
  #   esac
  # done

while true; do
  case "$1" in
    -i | --install ) create_platform ; break ;;
    -d | --delete ) purge_all ;;
    -h | --help ) playground_help ;;
    -v | --verbose ) printf "${CL}${RED}${BOLD}I SAID NOT IMPLEMENTED YET ;-) \n${NORMAL}"  ; exec_spinner "count_down 3" "" "reboot!" ; clear ; playground_help ;;
    * ) playground_help ;;
  esac
done