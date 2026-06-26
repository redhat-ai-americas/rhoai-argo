#!/bin/bash

uri=$(oc get secret openshift-ai-maas-app -ojsonpath='{.data.uri}' | base64 -d)
oc create secret generic maas-db-config -n redhat-ods-applications --from-literal=DB_CONNECTION_URL="$uri" --dry-run=client -oyaml | oc apply -f-
