#!/bin/bash

# ./util.sh init               # reconfigure your users kubeconfig settings to point to this cluster
# ./util.sh addons      # deploy addons (ns/kube-system, svc+rc/kube-dashboard, svc+rc/skydns+kube2sky)
# ./util.sh copykey            # copys private key to master
# ./util.sh ssh                # ssh into the master
source env.sh

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cmd_init() {
	kubectl config set-cluster "${AZURE_DEPLOY_ID}" --server="https://${MASTER_FQDN}:6443" --certificate-authority="${DIR}/secret/ca.crt"
	kubectl config set-credentials "${ADMIN_USER_NAME}_user" --client-certificate="${DIR}/secret/client.crt" --client-key="${DIR}/secret/client.key"
	kubectl config set-context "${AZURE_DEPLOY_ID}" --cluster="${AZURE_DEPLOY_ID}" --user="${ADMIN_USER_NAME}_user"
	kubectl config use-context "${AZURE_DEPLOY_ID}"
}

cmd_addons() {
	kubectl create -f "${DIR}/addons/kube-dashboard.yaml"
}

cmd_copykey() {
	scp -i "secret/${ADMIN_USER_NAME}_rsa" "secret/${ADMIN_USER_NAME}_rsa" "${ADMIN_USER_NAME}@${MASTER_FQDN}":"/home/${ADMIN_USER_NAME}/${ADMIN_USER_NAME}_rsa"
}

cmd_ssh() {
	ssh -i "secret/${ADMIN_USER_NAME}_rsa" ${ADMIN_USER_NAME}@${MASTER_FQDN}
}

cmd="$1"
shift 1

"cmd_${cmd}" "${@}"