#!/usr/bin/env bash
# Check access from sleep application(3 namespaces) to httpbin application installed in foo namespace.
for from in "foo" "bar" "legacy";
do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.foo:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.foo: %{http_code}\n";
done