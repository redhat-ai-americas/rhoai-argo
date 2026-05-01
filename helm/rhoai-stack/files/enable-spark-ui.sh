oc patch deployment/spark-operator-controller --type=json -p='[{"op": "remove", "path": "/metadata/ownerReferences"}]'

sleep 3

CONSOLE_URL=$(oc get route console -n openshift-console -o go-template='{{if .spec.tls}}https://{{else}}http://{{end}}{{.spec.host}}{{"\n"}}')
BASE_URL=.apps$(echo $CONSOLE_URL | sed 's/^.*apps//g')
export INGRESS_URL_ARG='--ingress-url-format=https://{{$appName}}-{{$appNamespace}}'$BASE_URL
#oc get deployment -n spark-operator spark-operator-controller -o yaml > /tmp/manager.yaml
#yq -i '.spec.template.spec.containers[0].args += strenv(INGRESS_URL_ARG)' /tmp/manager.yaml
#yq -i '.spec.template.spec.containers[0].args += "--ingress-tls=[{}]"' /tmp/manager.yaml
#oc apply -f /tmp/manager.yaml

oc patch deployment spark-operator-controller -n redhat-ods-applications --type='json' -p="[
  {
    \"op\": \"add\",
    \"path\": \"/spec/template/spec/containers/0/args/-\",
    \"value\": \"$INGRESS_URL_ARG\"
  },
  {
    \"op\": \"add\",
    \"path\": \"/spec/template/spec/containers/0/args/-\",
    \"value\": \"--ingress-tls=[{}]\"
  }
]"