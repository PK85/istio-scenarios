#!/usr/bin/env bash

echo -e "Check istio mtls nad authorization configurations across all namespaces.\n";

for crds in "servicerolebindings" "serviceroles" "rbacconfigs" "destinationrules" "policies";
do echo "- CR ${crds}:";kubectl get ${crds} --all-namespaces; echo ""; done