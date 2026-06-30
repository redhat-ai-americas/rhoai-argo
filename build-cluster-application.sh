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

yq -i ".spec.source.helm.valuesObject.global.clusterBaseUrl = \"$BASE_URL\"" $NEWFILE