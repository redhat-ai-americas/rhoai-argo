#!/bin/bash
### relies on the KUBECONFIG environment variable or the ~/.kube/config content.
###
### Usage: bulk_approve_operators.sh [-u]
###   default: approve only pending install plans for fresh operator installs
###   -u     : also approve pending upgrades
###
### An install plan is classified by the subscription that references it
### (status.installPlanRef.name). If that subscription already has an
### installedCSV, the plan is an upgrade; otherwise it's a fresh install.
### Plans no subscription references are stale and never approved.
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NORMAL=$(tput sgr0)

INCLUDE_UPGRADES=false
while getopts "u" opt; do
  case $opt in
    u) INCLUDE_UPGRADES=true ;;
    *) echo "Usage: $0 [-u]"; exit 1 ;;
  esac
done

Plans=$(oc get installplan -A -o=jsonpath='{range .items[?(@.spec.approved == false)]}{.metadata.namespace} {.metadata.name} {.spec.clusterServiceVersionNames[*]}{"\n"}{end}')
Subs=$(oc get subscriptions.operators.coreos.com -A -o=jsonpath='{range .items[*]}{.metadata.namespace} {.status.installPlanRef.name} {.status.installedCSV}{"\n"}{end}')

# Emit: namespace name type csvs
Classified=$(awk '
  NR == FNR {
    key = $1 " " $2
    if (!(key in type)) type[key] = "install"
    if ($3 != "") type[key] = "upgrade"
    next
  }
  NF >= 2 {
    key = $1 " " $2
    t = (key in type) ? type[key] : "stale"
    csvs = ""
    for (i = 3; i <= NF; i++) csvs = csvs (csvs == "" ? "" : ",") $i
    print $1, $2, t, csvs
  }
' <(echo "$Subs") <(echo "$Plans"))

if [ -z "$Classified" ]
then
  echo "${YELLOW}No pending install plan to approve ${NORMAL}"
  exit 1
fi

echo -e "${GREEN}\nAll pending install plans:${NORMAL}"
{ echo "NAMESPACE NAME TYPE CSVS"; echo "$Classified"; } | column -t
echo

if [ "$INCLUDE_UPGRADES" = true ]
then
  Results=$(echo "$Classified" | awk '$3 == "install" || $3 == "upgrade"')
else
  Results=$(echo "$Classified" | awk '$3 == "install"')
fi

if [ -z "$Results" ]
then
  echo "${YELLOW}No pending install plans match the selected type (use -u to include upgrades) ${NORMAL}"
  exit 1
fi

echo -e "${GREEN}Below is the list of install plan to be approved.${NORMAL}"
echo "${GREEN}Please review and proceed.${NORMAL}"
echo
{ echo "NAMESPACE NAME TYPE CSVS"; echo "$Results"; } | column -t

read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

IFS=$'\n'
for item in $Results
do
    namespace=$(echo $item | awk '{print $1}')
    name=$(echo $item | awk '{print $2}')
    echo "approving installplan: ${name} from namespace: ${namespace}"
    oc get -n ${namespace} installplan ${name}
    oc patch installplan ${name} -n ${namespace} --type merge --patch '{"spec":{"approved":true}}'
    oc get -n ${namespace} installplan ${name}
    echo ------------- && echo
done
