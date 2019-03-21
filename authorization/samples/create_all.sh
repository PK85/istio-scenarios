#!/usr/bin/env bash
kubectl create ns foo
kubectl apply -f samples/httpbin.yaml -n foo
kubectl apply -f samples/sleep.yaml -n foo
kubectl create ns bar
kubectl apply -f samples/httpbin.yaml -n bar
kubectl apply -f samples/sleep.yaml -n bar
kubectl create ns legacy
kubectl label namespace legacy istio-injection=disabled
kubectl apply -f samples/sleep.yaml -n legacy

kubectl apply -f samples/destination-rule.yaml
kubectl apply -f samples/policy-permissive.yaml

kubectl apply -f samples/rbac-config.yaml
kubectl apply -f samples/service-role.yaml
kubectl apply -f samples/service-role-binding-both.yaml