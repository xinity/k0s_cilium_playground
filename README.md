# WORK IN PROGRESS 
# contributions highly appreciated  ;)

## K0S Cilium Playground

### Intro
This repository holds set of scripts that helps building and configuring a full cilium playground with :
- cluster-mesh enabled
- metallb as an IPAM solution 

This toolkit has been tested on MACOS but should behave the exact same way on Linux hosts.
### Requirements
For this project to run successfully you will need the following binaries deployment on your host:
- multipass
- k0sctl
- brew 
- kubectl 
- helm

Note: on MACOS/Linux you just need `brew` installed, the scripts will install the rest of the needed requirements.

### Variables
Several variables as been declared in the `playground_vars.sh`  script, some of them can be overridden:

| name | description | type | default value | comment |
|------|-------------|------|---------------|---------|
|DEBUGENABLED| Enables Debug Mode i.e: k0s controller visible and debug log enabled|Boolean|true| If you don't need to see the controller(s) nor the full logs, pass the variable to 'false'|
|K0SCTLVERS|Version of the k0sctl binary|string|v0.14.0|if the binary doesn't exist AND brew installed, it will automatically deploy the latest version [UNUSED FOR NOW]|
|METALLBVERS|Version of metallb used|string|v0.13.7|         |
|CILIUMENABLED|Enable or not the Cilium CNI AND clustermesh configuration|Boolean|true|if cilium is not deployed i.e:CILIUMENABLED=false <br> the default CNI will be used <br>(as of now kube-router)       |
|CILIUMVERS|Version of cilium used|number|1.12.4|Cilium version <1.13 **NEEDS** metallb , the 1.13 is yet to be tested|
|CUSTOMCILIUM|Enables usage of a custom Cilium helm charts configuration|Boolean|false|if set to `true` <br>the CUSTOMCILIUMVALUESFILES should be filled with the values.yaml content to be used with cilium|
|CUSTOMCILIUMVALUESFILES|Values to be passed to the cilium helm charts|string|[empty]|values to be passed in yaml format|
|NUMBER_OF_VMS|number of VMs for each cluster|number|3| the number of VMs counts both controllers and workers nodes|
|SSHPKEYPATH|path to access the ssh key file |string|~/.ssh/|      |
|SSHKEYNAME|name of the ssh key file|string|id_rsa|if the file doesn't exist the scripts will create it and initialize it with a blank passphrase <br><br> if the keypair already exist make sure it has a **BLANK** passphrase or use ssh-agent and load the keypair before running the scripts|
|K0SADMINUSERNAME|system acountname to be created in each VMs|string|k0s|      |
|K0SCONTROLLERCOUNT|number of controller nodes to be configued|number|1|      |
|K0SCLUSTERNUMBER|number of cluster to be deployed and configured|number|2|      |
|K0SCLUSTERNAMEVAR|name to be for each cluster|string|k0scilium|      |


### deployment
if you don't feel the need to tweak the default variables, you just need to run the `init_playground` :
```
git clone https://github.com/xinity/k0s-cilium-playground
chmod u+x playground.sh
./playground.sh -i

or

./playground.sh --install
```

### TODO
- code refactoring
- log management 
- FULL debug mode
