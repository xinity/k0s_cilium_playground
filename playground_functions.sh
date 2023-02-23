#!/usr/bin/env bash
# set -x 

source playground_vars.sh  

NORMAL=$(tput sgr0)
BOLD=$(tput bold)
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

# Clear Line
CL="\e[2K"
# Spinner Character
SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

function spinner() {
  tput civis
  task=$1
  msg=$2
  while :; do
    jobs %1 > /dev/null 2>&1
    [ $? = 0 ] || {
      printf "${CL}${GREEN}${BOLD}✓${WHITE}${BOLD} ${task} ${GREEN}${BOLD}Done\n${NORMAL}"
      break
    }
    for (( i=0; i<${#SPINNER}; i++ )); do
      sleep 0.05
      printf "${CL}${CYAN}${BLD}${SPINNER:$i:1}${NORMAL} ${task} ${BLUE}${BOLD}${msg}\r${NORMAL}"
      # tput cuu1
      # printf ""
    done
  done
}

function exec_spinner() {
msg="${2-InProgress}"
task="${3-$1}"
$1 > /dev/null 2>/dev/null & spinner "$task" "$msg"
# $1 & spinner "$task" "$msg"

tput cnorm
}

function check_bins() {
# checking brew binary
if [ "${CILIUMENABLED}" == 'true' ];
  then
    BINLIST+=" cilium"
fi

for b in $BINLIST ;
do 
if ! command -v "${b}" &> /dev/null
then
    echo "${b} could not be found"
    if [ "${b}" == brew ]
    then
      echo "Check <https://github.com/Homebrew/brew> on how to install it"
      exit
    else
        echo "Installing ${b} ..."
          case $i in 
            "cilium")
              brew install "${b}"-cli
              ;;
            "k0sctl")
              brew install k0sproject/tap/"${b}"@@
              ;;
            *)
              brew install "${b}"
              ;;
          esac
      echo ""${b}" successfully installed, next !" 
fi
fi
done
}

function check_gen_ssh_key(){
  if [ -s "${SSHPKEYPATH}""${SSHKEYNAME}" ];
    then
#    echo "checking existing key without passphrase"
    if ! ssh-keygen -y -P "" -f "${SSHPKEYPATH}""${SSHKEYNAME}" > /dev/null 2>&1;
      then
        echo "ssh key exist BUT WITH PASSPHRASE"
        echo "either remove the passphrase using: ssh-keygen -p ${SSHPKEYPATH}${SSHKEYNAME}"
        echo "or update the playground_vars script and change SSHKEYNAME value"
        echo "or load the ssh keypair using ssh-agent"
        exit
    fi
    else
    echo "generating ssh key ${SSHPKEYPATH}${SSHKEYNAME}"
      ssh-keygen -b 2048 -t rsa -f "${SSHPKEYPATH}""${SSHKEYNAME}" -q -N ""
  fi
}

function gen_multipass_cloud-init(){
#  echo "Create cloud-init to import ssh key..."

# https://github.com/canonical/multipass/issues/965#issuecomment-591284180
cat <<EOF > config/multipass-cloud-init.yml
---
users:
  - name: "${K0SADMINUSERNAME}"
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /usr/bin/bash
    ssh_authorized_keys:
      - $( cat "${SSHPKEYPATH}""${SSHKEYNAME}.pub")
EOF
}

function check_instances() {
  for knode in ${K0SHOSTLIST}; 
  do 
    timeout 5 bash -c "</dev/tcp/"${knode}"/22"
#  ssh -q -o BatchMode=yes  -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${knode}" 'exit 0'
    if [ $? == 0 ];then
      echo "SSH Connection to "${knode}" is possible"
    else
      echo "SSH Connection to "${knode}" is broken"
      exit 1
    fi
  done
}

function create_instances(){
K0SHOSTLIST=()

for ((n = 1 ; n <= "${NUMBER_OF_VMS}" ; n++)); do
#echo "["${n}"/${NUMBER_OF_VMS}] Creating instance "${K0SNODENAME}"-${n} with multipass..."

  exec_spinner "multipass launch --name "${K0SNODENAME}"-"${n}" --cloud-init config/multipass-cloud-init.yml --cpus 2 --mem 6000M --disk 20G focal" "Work in Progress" "["${n}"/${NUMBER_OF_VMS}] Creating instance "${K0SNODENAME}"-${n} ..."

  # echo "adding node "${K0SNODENAME}"-${n} ip to k0sctl host list "
  nodeip="$(multipass info "${K0SNODENAME}"-"${n}" --format csv | awk -F',' '{print$3}' | tail -1)"
  K0SHOSTLIST+="${nodeip} "
done
check_instances
}

function gen_k0s_config(){
  k0sctl init --k0s -n "${K0SCLUSTERNAME}" -u "${K0SADMINUSERNAME}" -i "${SSHPKEYPATH}""${SSHKEYNAME}" -C "${K0SCONTROLLERCOUNT}" ${K0SHOSTLIST} > k0s-"${K0SCLUSTERNAME}"-config.yaml

}

function tweak_k0s_config(){
    echo "tweaking ${K0SCLUSTERNAME} config file for cilium playground" 
    
    if [  "${DEBUGENABLED}" == 'true' ];
    then
      echo "enabling k0s controller(s) debug mode "
      sed -i '' -e '/controller/a\'$'\n''    installFlags: \
      - --enable-worker \
      - --debug=true' k0s-"${K0SCLUSTERNAME}"-config.yaml
    fi
    
    if [ "${CILIUMENABLED}" == 'true' ];
    then
      echo "disabling kube-proxy"
      sed -i '' -e '/          kubeProxy:/ {' -e 'n; s/.*/            disabled: true/' -e '}' k0s-"${K0SCLUSTERNAME}"-config.yaml
      echo "changing kuberouter to custom"
      sed -i '' -e 's/provider: kuberouter/provider: custom/' k0s-"${K0SCLUSTERNAME}"-config.yaml
      sed -i '' -e 's/10\.244\.0\.0\/16/10\.'"${p}"'44\.0\.0\/16/' k0s-"${K0SCLUSTERNAME}"-config.yaml
      sed -i '' -e 's/10\.96\.0\.0\/12/10\.'"${p}"'6\.0\.0\/12/' k0s-"${K0SCLUSTERNAME}"-config.yaml
      inject_cilium_config
    fi

}

function inject_cilium_config() {
  CNODEARRAY=(${K0SHOSTLIST})
  CNODE=${CNODEARRAY[0]}

    if [ "${CUSTOMCILIUM}" == 'true' ];
    then
      sed -i '' -e '/       api:/ {
      r config/'"${CUSTOMCILIUMVALUESFILES}"'
      N
      }' k0s-"${K0SCLUSTERNAME}"-config.yaml  
    else 
      sed -e 's/METALLBVERS/'"${METALLBVERS}"'/g; s/CLUSTERNAME/'"${K0SCLUSTERNAME}"'/g; s/CLUSTERID/'"${p}"'/g; s/CILIUMVERS/'"${CILIUMVERS}"'/g; s/CNODE/'"${CNODE}"'/g' config/cilium-values.yaml.tpl > config/cilium-values-"${K0SCLUSTERNAME}".yaml
      sed -i '' -e 's/10\.244\.0\.0\/16/10\.'"${p}"'44\.0\.0\/16/' config/cilium-values-"${K0SCLUSTERNAME}".yaml

      sed -i '' -e '/       api:/ {
      r config/cilium-values-'"${K0SCLUSTERNAME}"'.yaml
      N
      }' k0s-"${K0SCLUSTERNAME}"-config.yaml
      
    fi
}

###################
# metallb functions
###################

function gen_metallb_iprange(){
  CNODEARRAY=(${K0SHOSTLIST})
  CNODE=${CNODEARRAY[0]}
  NODERANGE=$(echo "${CNODE}" | awk -F'.' '{print$1"."$2"."$3}')
  STARTRANGE="${NODERANGE}.${p}00"
  ENDRANGE="${NODERANGE}.${p}50"
}

function gen_metallb_config(){
gen_metallb_iprange
sed -e 's/METALLBIPRANGE/'"${STARTRANGE}"'-'"${ENDRANGE}"'/' config/metallb-config.yaml.tpl > config/metallb-config-"${K0SCLUSTERNAME}".yaml
}

function apply_metallb_config(){
export KUBECONFIG=~/.kube/"${K0SCLUSTERNAME}".config
readynbr=''
check_deployment_status metallb
gen_metallb_config
kubectl apply -f config/metallb-config-"${K0SCLUSTERNAME}".yaml > /dev/null 2>&1
# echo $(echo ${FUNCNAME} | awk -F "_" '{print$2}')" configuration:"  $(printf "${BOLDGREEN}DEPLOYED${ENDCOLOR}")
}


function build_k0s_cluster(){
if [ "${CILIUMENABLED}" == 'true' ];
  then
    OPT='--no-wait'
fi
    k0sctl apply --config k0s-"${K0SCLUSTERNAME}"-config.yaml "${OPT}" > /dev/null 2>&1
#    echo $(echo ${FUNCNAME} | awk -F "_" '{print$2}')":"  $(printf "${BOLDGREEN}DEPLOYED${ENDCOLOR}")

}

function gen_kube_config() {
if [ ! -d ~/.kube ]
then
  mkdir ~/.kube
fi
k0sctl kubeconfig --config k0s-"${K0SCLUSTERNAME}"-config.yaml > ~/.kube/"${K0SCLUSTERNAME}".config
if [ "${CILIUMENABLED}" == 'true' ];
  then
    sed -i '' -e 's/admin/admin-'"${K0SCLUSTERNAME}"'/g' ~/.kube/"${K0SCLUSTERNAME}".config 
fi
}

function merge_kube_config() {
  export KUBECONFIG=$(find  ~/.kube/k0scilium*.config | awk 'BEGIN { ORS = ":" } { print }') \
  && kubectl config view --merge --flatten > ~/.kube/config-cilium \
  && export KUBECONFIG=~/.kube/config-cilium
}

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# function check_pods_ready_status(){

# until [ $(kubectl -n ${1} get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[*].ready.true}{.metadata.name}{ "\n"}{end}' | wc -l ) -eq $(kubectl get po -n ${1} | tail -n +2 | wc -l  )  ];
# do 
#   sleep 10
#   echo "waiting for ${1} pods to be fully ready"
# done
#   echo "${1} pods status: " $(printf "${BOLDGREEN}READY${ENDCOLOR}")

# }

function check_deployment_status(){


# echo "waiting for ${1} services to be deployed"
until kubectl get svc -n ${1} -o custom-columns=NAME:.metadata.name | tail -n +2 | grep -E -o '[A-Za-z]' > /dev/null 2>&1 ;
do 
        sleep 5
done
# echo "${1} service status: " $(printf "${BOLDGREEN}DEPLOYED${ENDCOLOR}")
SVCLIST=$(kubectl get svc -n ${1} -o custom-columns=NAME:.metadata.name | tail -n +2)
SVCNUMBER="$(echo "${SVCLIST}" | wc -l)"

while [[ ${readynbr} -lt "${SVCNUMBER}" ]]
do

  
  sleep 5
  # echo "waiting for ${1} services to be up and running:"$(echo ${SVCLIST} | tr '\n' ' ')
  for svc in ${SVCLIST};
    do 
        until kubectl get endpoints ${svc} -n ${1} -o=jsonpath='{.subsets[0].addresses[0].ip}' | grep -E -o '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' > /dev/null 2>&1 ; 
        do 
        sleep 5
        done
        readynbr=$((readynbr+1))
#        echo "${svc} status: " $(printf "${BOLDGREEN}READY${ENDCOLOR}")
  done
done  
}


function enable_cilium_clustermesh() {
merge_kube_config
if [ "${CILIUMENABLED}" == 'true' ];
  then
  CLUSTERLIST=()
#  while IFS=$'\n' read -r line; do CLUSTERLIST+=("$line"); done < <(kubectl config get-contexts --output=name)
  while IFS= read -r line; do CLUSTERLIST+=( "$line" ); done < <(kubectl config get-contexts --output=name)
  # echo knames: $(kubectl config get-contexts --output=name)
  # echo CLUSTER_LIST: ${CLUSTERLIST}
  # echo C1: ${CLUSTERLIST[0]}
  # echo C2: ${CLUSTERLIST[1]}
  for c in ${CLUSTERLIST[@]};
  do 
  kubectl config use-context "${c}"
  kubectl get endpoints clustermesh-apiserver -n cilium -o=jsonpath='{.subsets[0].addresses[0].ip}' | grep -E -o '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' > /dev/null 2>&1
  if [ $? -ne 0 ] && [ "${c}" == "${CLUSTERLIST[0]}" ];
    then
    readynbr=''
    check_deployment_status cilium
#    echo "enable cilium clustermesh on cluster:" "${c}"
    cilium clustermesh enable --context "${c}" --service-type=LoadBalancer -n cilium
  fi
    if [ "${c}" == "${CLUSTERLIST[1]}" ];
    then
      readynbr=''
      check_deployment_status cilium
      cilium clustermesh enable --context "${c}" --service-type=LoadBalancer -n cilium
#      echo "connecting cluster "${CLUSTERLIST[0]}" and "${CLUSTERLIST[1]}"" 
      cilium clustermesh connect --context "${CLUSTERLIST[0]}" --destination-context "${CLUSTERLIST[1]}"  -n cilium
    fi        
  done
  # check_pods_ready_status cilium
fi
}


function create_platform() {
  exec_spinner "check_bins" "Work in progress" "checking binary:"
  exec_spinner "check_gen_ssh_key" "checking ssh keys" "check_gen_ssh_key:"
  exec_spinner "gen_multipass_cloud-init" "Work in Progress" "Generate Cloud init Config:"
  
  for ((p=1; p <= K0SCLUSTERNUMBER; p++))
  do
    K0SCLUSTERNAME=${K0SCLUSTERNAMEVAR}-"${p}"
    K0SNODENAME=${K0SCLUSTERNAME}-node
    printf "${CL}${BLUE}${BOLD}Cluster: ${K0SCLUSTERNAME} \n${NORMAL}"
    create_instances
    exec_spinner "gen_k0s_config" "Work in Progress" "Generating k0s yaml"
      if [ ${CILIUMENABLED} == 'true' ];
        then
            printf "${CL}${BLUE}${BOLD}Cluster: ${K0SCLUSTERNAME} will use Cilium Clustermesh configuration \n${NORMAL}"
            exec_spinner "tweak_k0s_config" "Work in Progress" "tweaking k0s config"
            exec_spinner "build_k0s_cluster" "Work in Progress" "Building k0s cluster"
            exec_spinner "gen_kube_config" "Work in Progress" "Generating kubeconfig"
            exec_spinner "apply_metallb_config" "Work in Progress" "Deploy MetalLB"
            exec_spinner "enable_cilium_clustermesh" "Work in Progress" "Deploying Cilium"           
        else
            printf "${CL}${BLUE}${BOLD}Cluster: ${K0SCLUSTERNAME} will use default CNI \n${NORMAL}"
            exec_spinner "build_k0s_cluster" "Work in Progress" "Building k0s cluster"
            exec_spinner "gen_kube_config" "Work in Progress" "Generating kubeconfig"
            exec_spinner "merge_kube_config" "Work in Progress" "merging kubeconfig"
      fi
  done
}
function playground_help() {
  # Display Help

  printf "${CL}${GREEN}${BOLD}Cilium playground scripts \n${NORMAL}"

  # printf "${CL}${GREEN}${BOLD}✓${WHITE}${BOLD} ${task} ${GREEN}${BOLD}Done\n${NORMAL}"

   echo ""
   echo
   printf "${CL}Syntax: ./playground [${GREEN}${BOLD} -i / --install || -d / --delete || ${RED}${BOLD} -v / --verbose ${GREEN}${BOLD} || -h / --help]\n${NORMAL}"
   echo ""
   echo "options:"
   printf "${GREEN} -i / --install     deploys the playground\n${NORMAL}"
   printf "${GREEN} -d / --delete      delete the playground , but leave '${BINLIST}' installed\n${NORMAL}"
   printf "${GREEN} -h / --help        Print this Help.\n${NORMAL}"
   printf "${RED} -v / --verbose     Verbose mode [ NOT IMPLEMENTED YET ]\n${NORMAL}"
   echo
   exit 0
}

function purge_all() {
  echo "${K0SCLUSTERNAMEVAR}"
  nodelist="$(multipass list --format csv | grep "${K0SCLUSTERNAMEVAR}" |  awk -F',' '{print$1}' | awk 'BEGIN { ORS = " " } { print }'  )"
  printf "${RED} HERE THE NODE LIST TO BE DELETED: \n${NORMAL}" "${nodelist}"
  printf "${BOLD}${RED}Do you wish to delete them? \n${NORMAL}"
  read -p "are you REALLY SURE ? (Delete_ALL/No) " yn
  case $yn in 
    Delete_ALL ) exec_spinner "multipass delete ${nodelist}" "Work in Progress" "deleting nodes" && exec_spinner "multipass purge" "Work in Progress" "Purging multipass" && rm -f "${HOME}"/.kube/"${K0SCLUSTERNAMEVAR}"-*.config *-"${K0SCLUSTERNAMEVAR}"-* config/*-"${K0SCLUSTERNAMEVAR}"-* config/multipass-cloud-init.yml  && \
    printf "\n${BOLD}${RED} /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\ ${NORMAL}" \
    && printf "\n${BOLD}${RED} /!\ you might need to manually Cleanup your ~/.ssh/known_hosts /!\ ${NORMAL}" \
    && printf "\n${BOLD}${RED} /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\ \n${NORMAL}" ; break ;;
    No ) echo "OK i won't change anything ( yet? :p )"; exit ;;
    * ) echo "you need to either enter: Delete_ALL or No ";;
  esac
}

function count_down() {
COUNT=$1
# bash while loop
while [ $COUNT -gt 0 ]; do
        echo $COUNT
        let COUNT=COUNT-1
        sleep 1
done
}