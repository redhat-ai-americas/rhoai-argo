oc patch deployment/spark-operator-controller --type=json -p='[{"op": "remove", "path": "/metadata/ownerReferences"}]'

sleep 3

mkdir -p scratch/
CONSOLE_URL=$(oc get route console -n openshift-console -o go-template='{{if .spec.tls}}https://{{else}}http://{{end}}{{.spec.host}}{{"\n"}}')
BASE_URL=.apps$(echo $CONSOLE_URL | sed 's/^.*apps//g')
export INGRESS_URL_ARG='--ingress-url-format=https://{{$appName}}-{{$appNamespace}}'$BASE_URL
oc get deployment -n spark-operator spark-operator-controller -o yaml > scratch/manager.yaml
yq -i '.spec.template.spec.containers[0].args += strenv(INGRESS_URL_ARG)' scratch/manager.yaml
yq -i '.spec.template.spec.containers[0].args += "--ingress-tls=[{}]"' scratch/manager.yaml
oc apply -f scratch/manager.yaml