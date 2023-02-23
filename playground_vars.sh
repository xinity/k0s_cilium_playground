#!/usr/bin/env bash
### DO NOT CHANGES THOSE VARIABLES ####

#### COLORS:
GREEN="32"
BOLDGREEN="\e[1;${GREEN}m"
ENDCOLOR="\e[0m"

#### list of binaries required
BINLIST="brew multipass k0sctl kubectl helm"

### DO NOT CHANGES THOSE VARIABLES ####

### VARIABLES BELOW CAN BE CHANGED ####
DEBUGENABLED='true'

K0SCTLVERS='v0.14.0'

METALLBVERS='v0.13.7'

CILIUMENABLED='true'

CILIUMVERS='1.12.4'

CUSTOMCILIUM='false'

CUSTOMCILIUMVALUESFILES=''
# Default to 5 VMs
NUMBER_OF_VMS='3'

# ssh pub key(s) path 
SSHPKEYPATH=~/.ssh/

# ssh pub key name   
SSHKEYNAME=id_rsa

K0SADMINUSERNAME=k0s

K0SCONTROLLERCOUNT='1'

K0SCLUSTERNUMBER='2'

K0SCLUSTERNAMEVAR='k0scilium'


