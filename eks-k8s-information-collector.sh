#!/bin/bash

K8S_OBJECTS=(
  cronjobs
  cninode
  daemonsets
  deployments
  ec2nodeclasses
  endpoints
  endpointslices
  horizontalpodautoscalers
  ingressclasses
  ingresses
  jobs
  namespaces
  nodeclasses
  nodeclaims
  nodepools
  nodes
  persistentvolumeclaims
  persistentvolumes
  poddisruptionbudgets
  pods
  replicasets
  serviceaccounts
  services
  statefulsets
  storageclasses
)

trap cleanup EXIT

function help() {
  echo -e "Usage: bash $(basename "${0}")" 
  echo "your bundled logs will be located in ./<Cluster_Name_Start_Timestamp>.tar.gz"
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h | --help)
      help && exit 0
      ;;
  esac
done

function error() {
  printf "%s\n" "$*" 1>&2
  exit 1
}

function check_kubectl() {
  if (! command -v kubectl >> /dev/null); then
    error "KUBECTL not found. Please install KUBECTL or make sure the PATH variable is set correctly. For more information: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html"
  fi

  local CONFIG
  CONFIG=$(kubectl config view --minify 2> /dev/null)
  if [[ -z $CONFIG ]]; then
    error "Make sure to set KUBECONFIG & Current Context. For more information visit: https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html"
  fi
}

function check_permissions() {
  if [[ $(kubectl auth can-i 'list' '*' -A 2> /dev/null) == 'no' \
     || $(kubectl auth can-i 'get' '*' -A 2> /dev/null) == 'no' \
     || $(kubectl auth can-i 'describe' '*' -A 2> /dev/null) == 'no' ]]; then
    error "Please make sure you have Read (get,list,describe) permission for the EKS cluster!!"
  fi
}

function get_cluster() {
  CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
  if [[ -z $CLUSTER ]]; then
    error "Set the current-context in a kubeconfig file. For more information: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_use-context/"
  fi
  export CLUSTER
}

function create_output_dir() {
  OUTPUT_DIR="eks_${CLUSTER}_${START_TIME}"
  mkdir -p "${OUTPUT_DIR}" || error "mkdir: cannot create directory ${OUTPUT_DIR}"
  export OUTPUT_DIR
}

# Cluster info
function get_cluster_info() {
  local ENV
  local PROFILE
  local EXEC_ARGS
  local REGION
  local ROLE
  local API_SERVER_END_POINT
  local CLUSTER_ARN
  local VERSION
  local CLUSTER_VERSION
  local KUBECTL_VERSION
  local CLUSTER_INFO
  local OUTPUT="${OUTPUT_DIR}/${CLUSTER}_cluster_info.json"

  echo "Trying to collect cluster info..."
  ENV=$(kubectl config view --minify -ojsonpath='{.users[0].user.exec.env}')
  if [[ -n ${ENV} ]] && [[ ${ENV} != "null" ]]; then
    PROFILE=$(kubectl config view --minify -ojsonpath='{.users[0].user.exec.env[?(@.name=="AWS_PROFILE")].value}')
  fi

  EXEC_ARGS=$(kubectl config view --minify -ojsonpath='{.users[0].user.exec.args}')
  REGION=$(echo "${EXEC_ARGS}" | sed -n -e 's/.*"--region","\([^"]*\)".*/\1/p')
  ROLE=$(echo "${EXEC_ARGS}" | sed -n -e 's/.*"--role-arn","\([^."]*\).*,/\1/p' | sed 's/".*//')
  if [[ -z $ROLE ]]; then
    if [[ -z $PROFILE ]]; then
      ROLE=$(aws sts get-caller-identity --region "${REGION}" --query "Arn" --output text)
    else
      ROLE=$(aws sts get-caller-identity --profile "${PROFILE}" --region "${REGION}" --query "Arn" --output text)
    fi
  fi

  API_SERVER_END_POINT=$(kubectl config view --minify -ojsonpath='{.clusters[0].cluster.server}')
  CLUSTER_ARN=$(kubectl config view --minify -ojsonpath='{.clusters[0].name}')

  VERSION=$(kubectl version 2> /dev/null)
  CLUSTER_VERSION=$(echo "$VERSION" | sed -nE 's/.*Server Version: v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
  KUBECTL_VERSION=$(echo "$VERSION" | sed -nE 's/.*Client Version: v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')

  CLUSTER_INFO="{\"cluster\": {\"server\": \"${API_SERVER_END_POINT}\"},\"name\": \"${CLUSTER_ARN}\",\"serverVersion\": \"${CLUSTER_VERSION}\", \"clientVersion\": \"${KUBECTL_VERSION}\",\"iamRole\": \"${ROLE}\"}"
  echo "${CLUSTER_INFO}" > "${OUTPUT}"
}

# All objects list
function get_all_objects_list() {
  local OUTPUT="${OUTPUT_DIR}/${CLUSTER}_all_objects_list.txt"
  echo "Trying to collect all objects list..."
  for i in $(kubectl api-resources --verbs=list -o name | grep -v events | sort | tr "\n" " "); do
    echo -e "\n---------- $i ----------\n" >> "${OUTPUT}" 2>&1
    kubectl get "$i" -o wide -A >> "${OUTPUT}" 2>&1
  done
}

# Specific objects details
function get_specific_objects_details() {
  local OUTPUT="${OUTPUT_DIR}/${CLUSTER}_specific_objects_details.txt"
  echo "Trying to collect specific objects details..."
  for i in "${K8S_OBJECTS[@]}"; do
    echo -e "\n---------- $i ----------\n" >> "${OUTPUT}" 2>&1
    kubectl describe "$i" -A >> "${OUTPUT}" 2>&1
  done
}

# Events
function get_events() {
  local OUTPUT="${OUTPUT_DIR}/${CLUSTER}_events.txt"
  echo "Trying to collect events..."
  kubectl get events --sort-by=.metadata.creationTimestamp -o wide -A >> "${OUTPUT}" 2>&1
}

function create_archive() {
  tar -czf "${OUTPUT_DIR}.tar.gz" "${OUTPUT_DIR}" > /dev/null 2>&1
  echo "Done... your bundled logs are located in ${OUTPUT_DIR}.tar.gz"
}

function cleanup() {
  if [[ -n "$OUTPUT_DIR" && -d "$OUTPUT_DIR" ]]; then
    rm -rf "${OUTPUT_DIR}" > /dev/null 2>&1
  fi
  if [[ -n "$OUTPUT_DIR" ]]; then unset OUTPUT_DIR; fi
  if [[ -n "$CLUSTER" ]]; then unset CLUSTER; fi
}

# Main
START_TIME=$(date -u "+%Y%m%dT%H%M_%Z")
check_kubectl
check_permissions
get_cluster
create_output_dir

get_cluster_info
get_all_objects_list
get_specific_objects_details
get_events

create_archive
exit
