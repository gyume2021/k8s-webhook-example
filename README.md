# kubernetes-webhook-example

This is a [Kubernetes admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) example modified from [slackhq repo](https://github.com/slackhq/simple-kubernetes-webhook). It is meant to be used as a validating and mutating admission webhook as the template for kubebuilder.

## Environment
This project run kubernetes webhook on cluster of google Kubernetes engine 

* kubectl = 1.23
* make = 4.2.1
* Go =1.18
* google kubernetes engine = 1.21

### Deploy Admission Webhook

* To configure the cluster to use the admission webhook and to deploy said webhook, simply run:
```
❯ make deploy
```

* Then, make sure the admission webhook pod is running (`NAMESPACE` can be set in `Makefile`):
```
❯ kubectl get pods -n NAMESPACE
```

* You can stream logs from it:
```
❯ make logs

🔍 Streaming simple-kubernetes-webhook logs...
kubectl logs -l app=simple-kubernetes-webhook -n "simple-webhook" -f
time="2022-04-17T10:41:42Z" level=info msg="Listening on port 443..."
time="2022-04-17T11:01:46Z" level=debug msg=healthy uri=/health
time="2022-04-17T11:01:49Z" level=debug msg=healthy uri=/health
```

* And hit it's health endpoint from local machine:
```
❯ make port-forward-test.
```

Open another terminal, and type:
```
❯ curl -k https://localhost:8443/health
OK
```

### Deploying pods
Deploy a valid test pod that gets succesfully created:
```
❯ make pod

🚀 Deploying test pod...
kubectl apply -f dev/manifests/pods/lifespan-seven.pod.yaml
pod/lifespan-seven created
```
You should see in the admission webhook logs that the pod got mutated and validated.

Deploy a non valid pod that gets rejected:
```
❯ make bad-pod

🚀 Deploying "bad" pod...
kubectl apply -f dev/manifests/pods/bad-name.pod.yaml
Error from server: error when creating "dev/manifests/pods/bad-name.pod.yaml": admission webhook "simple-kubernetes-webhook.acme.com" denied the request: pod name contains "offensive"
```
You should see in the admission webhook logs that the pod validation failed. It's possible you will also see that the pod was mutated, as webhook configurations are not ordered.

## Testing
Unit tests can be run with the following command:
```
$ make test
go test ./...
?   	github.com/slackhq/simple-kubernetes-webhook	[no test files]
ok  	github.com/slackhq/simple-kubernetes-webhook/pkg/admission	0.611s
ok  	github.com/slackhq/simple-kubernetes-webhook/pkg/mutation	1.064s
ok  	github.com/slackhq/simple-kubernetes-webhook/pkg/validation	0.749s
```

## Admission Logic
A set of validations and mutations are implemented in an extensible framework. Those happen on the fly when a pod is deployed and no further resources are tracked and updated (ie. no controller logic).

### Validating Webhooks
#### Implemented
- [name validation](pkg/validation/name_validator.go): validates that a pod name doesn't contain any offensive string

#### How to add a new pod validation
To add a new pod mutation, create a file `pkg/validation/MUTATION_NAME.go`, then create a new struct implementing the `validation.podValidator` interface.

### Mutating Webhooks
#### Implemented
- [inject env](pkg/mutation/inject_env.go): inject environment variables into the pod such as `KUBE: true`
- [minimum pod lifespan](pkg/mutation/minimum_lifespan.go): inject a set of tolerations used to match pods to nodes of a certain age, the tolerations injected are controlled via the `acme.com/lifespan-requested` pod label.

#### How to add a new pod mutation
To add a new pod mutation, create a file `pkg/mutation/MUTATION_NAME.go`, then create a new struct implementing the `mutation.podMutator` interface.

#### reference
- [admission webhook server](https://github.com/kubernetes/kubernetes/blob/release-1.21/test/images/agnhost/webhook/main.go)
- [admission webhook service](https://github.com/kubernetes/kubernetes/blob/v1.22.0/test/e2e/apimachinery/webhook.go#L748)
- [Using Envoy Proxy to load-balance gRPC services on GKE](https://cloud.google.com/architecture/exposing-grpc-services-on-gke-using-envoy-proxy#deploying_the_grpc_services)
