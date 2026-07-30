if [[ ! (-n $1 && -e $1) ]]
then
  echo "Input file does not exist!"
  exit 1
fi

CONSOLE_URL=$(oc get route console -n openshift-console -o go-template='{{if .spec.tls}}https://{{else}}http://{{end}}{{.spec.host}}{{"\n"}}')
BASE_URL=.apps$(echo $CONSOLE_URL | sed 's/^.*apps//g')

echo "Current cluster is ${BASE_URL:6}"

mkdir -p cluster-applications/
NEWFILE=cluster-applications/${BASE_URL:6}-$(basename $1)
cp $1 $NEWFILE
echo "New file location is $NEWFILE"

yq -i ".spec.source.helm.valuesObject.global.clusterBaseUrl = \"$BASE_URL\"" "$NEWFILE"

MAAS_ROUTE=$(yq '.spec.source.helm.valuesObject.configuration.inferenceApp.maasRoute // "false"' "$NEWFILE")
MAAS_ROUTE_TERMINATION=$(yq '.spec.source.helm.valuesObject.configuration.inferenceApp.maasRouteConfig.termination // "passthrough"' "$NEWFILE")
echo $MAAS_ROUTE
echo $MAAS_ROUTE_TERMINATION
if [[ $MAAS_ROUTE == "true" && $MAAS_ROUTE_TERMINATION == "reencrypt" ]]
then
  echo "Using routes with reencryption requires the cert to be set. Doing that now"
  SERVICE_CA_FILE=$(mktemp)
  oc get configmap signing-cabundle -n openshift-service-ca \
    -o jsonpath='{.data.ca-bundle\.crt}' > "$SERVICE_CA_FILE"
  
  # Literal block style preserves PEM newlines. Single-quoted multi-line YAML folds
  # them to spaces, which breaks OpenShift destinationCACertificate parsing.
  yq -i "
    .spec.source.helm.valuesObject.global.serviceCABundle = load_str(\"$SERVICE_CA_FILE\") |
    .spec.source.helm.valuesObject.global.serviceCABundle style=\"literal\"
  " "$NEWFILE"
  rm -f "$SERVICE_CA_FILE"
fi

#oc apply -f $NEWFILE
