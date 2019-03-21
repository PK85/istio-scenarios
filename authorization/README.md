# Authorization for HTTP Services
In the scenario I will show you how to define access control policies to grant access to any service in the K8S environment. You will learn how to work with below Istio CRDs:
- Mutual TLS (required for service to service authorization)
  - DestinationRule
  - Policy
- Authorization (Access Control)
  - RbacConfig
  - ServiceRole
  - ServiceRoleBinding

See more:
- https://istio.io/docs/tasks/security/mtls-migration/
- https://istio.io/docs/tasks/security/authz-http/
## Prerequisites

1. Install [`Kyma`](https://kyma-project.io/docs/root/kyma#installation-installation) and its prerequisites (kubectl). Kyma uses the Istio Service Mesh.
   >**NOTE:** If you create a namespace then Istio sidecar injection is a default behaviour.
2. Install watch
   ```
   brew install watch
   ```
   
## Setup and flow
The scenario was tested on Kyma 0.8, Istio 1.0.2, Istio 1.1.0.

### Preparation
- Create the `foo` and `bar` namespaces and deploy `httpbin` and `sleep` with sidecar on both of them. 
  ```
  kubectl create ns foo
  kubectl apply -f samples/httpbin.yaml -n foo
  kubectl apply -f samples/sleep.yaml -n foo
  kubectl create ns bar
  kubectl apply -f samples/httpbin.yaml -n bar
  kubectl apply -f samples/sleep.yaml -n bar
  ```
  *Expected result:*
  ```
  namespace/foo created
  service/httpbin created
  deployment.extensions/httpbin created
  serviceaccount/sleep-account created
  service/sleep created
  deployment.extensions/sleep created
  namespace/bar created
  service/httpbin created
  deployment.extensions/httpbin created
  serviceaccount/sleep-account created
  service/sleep created
  deployment.extensions/sleep created
  ```
- Create the `legacy` namespace and deploy sleep without sidecar.
  ```
  kubectl create ns legacy
  kubectl label namespace legacy istio-injection=disabled
  kubectl apply -f samples/sleep.yaml -n legacy
  ```
  *Expected result:*
  ```
  namespace/legacy created
  namespace/legacy labeled
  serviceaccount/sleep-account created
  service/sleep created
  deployment.extensions/sleep created
  ```
- Check Istio configuration and verify that there are no authentication policies or destination rules (except mixer’s) in the system.
  ```
  ./samples/check_config.sh
  ```
  *Expected result:*
  ```
  Check istio mtls nad authorization configurations across all namespaces.
  
  - CR servicerolebindings:
  No resources found.
  
  - CR serviceroles:
  No resources found.
  
  - CR rbacconfigs:
  No resources found.
  
  - CR destinationrules:
  NAMESPACE      NAME              AGE
  istio-system   istio-policy      7h
  istio-system   istio-telemetry   7h
  
  - CR policies:
  No resources found.
  ```
- Check how `sleep` services access to `httpbin.foo` service. Open new terminal window and run below command.
  ```
  watch -n 3 ./samples/check_access.sh
  ```
  *Expected result (wait till):*
  ```
  Every 3.0s: ./samples/check_access.
  
  sleep.foo to httpbin.foo: 200
  sleep.bar to httpbin.foo: 200
  sleep.legacy to httpbin.foo: 200
  ```
### Mutual TLS Steps
- Configure `sleep` services to send mutual TLS traffic to `httpbin.foo`. Required for authorization scenarios.
  ```
  kubectl apply -f samples/destination-rule.yaml
  ``` 
  *Expected result:*
  ```
  destinationrule.networking.istio.io/httpbin-istio-client-mtls created
  ```
  *Expected result in check_access terminal (wait till):*
  ```

  sleep.foo to httpbin.foo: 503
  sleep.bar to httpbin.foo: 503
  sleep.legacy to httpbin.foo: 200
  ```
   >**CAUTION:** Mutual TLS and plain traffic should be allowed from definition, but Istio 1.0.2 says 503 for `sleep` services with sidecar because of lack of default MeshPolicy custom resource. See next point where Istio policy solves that issue. The Istio 1.1.0 has that default CR.
- Configure `sleep` services to send mutual TLS traffic to `httpbin.foo` with STRICT mode. Required for authorization scenarios.
  ```
  kubectl apply -f samples/policy-strict.yaml
  ```
  *Expected result:*
  ```
  policy.authentication.istio.io/httpbin-policy created
  ```
  *Expected result in check_access terminal (wait till):*
  ```
  Every 3.0s: ./samples/check_access.

  sleep.foo to httpbin.foo: 200
  sleep.bar to httpbin.foo: 200
  sleep.legacy to httpbin.foo: 000
  command terminated with exit code 56
  ```
- Configure `sleep` services to send mutual TLS traffic to `httpbin.foo` with PERMISSIVE mode. Required for authorization scenarios.
  ```
  kubectl apply -f samples/policy-permissive.yaml
  ```
  *Expected result:*
  ```
  policy.authentication.istio.io/httpbin-policy configured
  ```
  *Expected result in check_access terminal (wait till):*
  ```
  Every 3.0s: ./samples/check_access.
  
  sleep.foo to httpbin.foo: 200
  sleep.bar to httpbin.foo: 200
  sleep.legacy to httpbin.foo: 200
  ```
### Authorization Scenarios
- Create rbac configuration for `httpbin.foo` which by default blocks access.
  ```
  kubectl apply -f samples/rbac-config.yaml
  ```
  >**CAUTION:** The RbacConfig CRD is a namespace scoped resource but it's a **SINGLETON**, must have `default` name, and only first created CR is known for the Istio.
  
  *Expected result:*
  ```
  rbacconfig.rbac.istio.io/default created
  ```
  *Expected result in check_access terminal (wait till):*
  ```
  Every 3.0s: ./samples/check_access.
  
  sleep.foo to httpbin.foo: 403
  sleep.bar to httpbin.foo: 403
  sleep.legacy to httpbin.foo: 403
  ```
- Create service role with full access to `httpbin.foo` service.
  ```
  kubectl apply -f samples/service-role.yaml
  ```
  *Expected result:*
  ```
  servicerole.rbac.istio.io/httpbin created
  ```
The `Sleep.foo`, `Sleep.bar`, `Sleep.legacy` services will try to reach the destination `httpbin.foo` service by service role bindings, see examples:
1. The `httpbin.foo` available for `Sleep.foo` only.
   ```
   kubectl apply -f samples/service-role-binding-foo.yaml
   ```
   *Expected result:*
   ```
   servicerolebinding.rbac.istio.io/httpbin created
   ```
   *Expected result in check_access terminal (wait till):*
   ```
   Every 3.0s: ./samples/check_access.
   
   sleep.foo to httpbin.foo: 200
   sleep.bar to httpbin.foo: 403
   sleep.legacy to httpbin.foo: 403
   ```
2. The `httpbin.foo` available for `Sleep.bar` only.
   ```
   kubectl apply -f samples/service-role-binding-bar.yaml
   ```
   *Expected result:*
   ```
   servicerolebinding.rbac.istio.io/httpbin configured
   ```
   *Expected result in check_access terminal (wait till):*
   ```
   Every 3.0s: ./samples/check_access.

   sleep.foo to httpbin.foo: 403
   sleep.bar to httpbin.foo: 200
   sleep.legacy to httpbin.foo: 403
   ```
3. The `httpbin.foo` available for `Sleep.foo` and `Sleep.bar` only.
   ```
   kubectl apply -f samples/service-role-binding-both.yaml
   ```
   *Expected result:*
   ```
   servicerolebinding.rbac.istio.io/httpbin configured
   ```
   *Expected result in check_access terminal (wait till):*
   ```
   Every 3.0s: ./samples/check_access.
   
   sleep.foo to httpbin.foo: 200
   sleep.bar to httpbin.foo: 200
   sleep.legacy to httpbin.foo: 403
   ```
### Cleanup
Run command:
```
kubectl delete ns foo
kubectl delete ns bar
kubectl delete ns legacy
```
*Expected result (it just takes some time):*
```
namespace "foo" deleted
namespace "bar" deleted
namespace "legacy" deleted
```

### All-In-One
```
./samples/create_all.sh
```
*Expected result:*
```
namespace/foo created
service/httpbin created
deployment.extensions/httpbin created
serviceaccount/sleep-account created
service/sleep created
deployment.extensions/sleep created
namespace/bar created
service/httpbin created
deployment.extensions/httpbin created
serviceaccount/sleep-account created
service/sleep created
deployment.extensions/sleep created
namespace/legacy created
namespace/legacy labeled
serviceaccount/sleep-account created
service/sleep created
deployment.extensions/sleep created
destinationrule.networking.istio.io/httpbin-istio-client-mtls created
policy.authentication.istio.io/httpbin-policy created
rbacconfig.rbac.istio.io/default created
servicerole.rbac.istio.io/httpbin created
servicerolebinding.rbac.istio.io/httpbin created
```
*Expected result in check_access terminal (wait till):*
```
Every 3.0s: ./samples/check_access.

sleep.foo to httpbin.foo: 200
sleep.bar to httpbin.foo: 200
sleep.legacy to httpbin.foo: 403
```









