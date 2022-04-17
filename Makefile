GOOGLE_CLOUD_PROJECT=<GOOGLE CLOUD PROJECT ID>
REGISTRY=<REGISTRY>
FOLDER=simple-kubernetes-webhook
TAG=latest
IMAGE=$(REGISTRY)/$(GOOGLE_CLOUD_PROJECT)/$(FOLDER):$(TAG)
NAMESPACE=simple-webhook

# test
.PHONY: unit-test
unit-test:
	@echo "\n🛠️  Running unit tests..."
	go test ./...

.PHONY: port-forward-test # curl -k https://localhost:9090/health
port-forward-test:
	@echo "\n🛠️  Running port forward test..."
	kubectl -n $(NAMESPACE) port-forward service/simple-kubernetes-webhook 9090:443

# build
.PHONY: build
build:
	@echo "\n🔧  Building Go binaries..."
	GOOS=darwin GOARCH=amd64 go build -o bin/admission-webhook-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: push
push:
	@echo "\n📦 Pushing admission-webhook image into google container registry..."
	gcloud builds submit --tag $(IMAGE) .

.PHONY: delete-image
delete-image:
	@echo "\n📦 Deleting admission-webhook image in google container registry..."
	gcloud container images list-tags $(REGISTRY)/$(GOOGLE_CLOUD_PROJECT)/$(FOLDER) \
		--format 'value(digest)' | xargs -I {} gcloud container images delete \
		--force-delete-tags --quiet $(REGISTRY)/$(GOOGLE_CLOUD_PROJECT)/$(FOLDER)@sha256:{}

# deploy cluster-webhook-config
.PHONY: deploy-config
deploy-config:
	@echo "\n⚙️  Applying cluster config..."
	kubectl apply -f dev/manifests/cluster-config/

.PHONY: delete-config
delete-config:
	@echo "\n♻️  Deleting Kubernetes cluster config..."
	kubectl delete -f dev/manifests/cluster-config/

# deploy webhook server
# kubectl create ns $(NAMESPACE)
.PHONY: deploy
deploy: push delete deploy-config
	@echo "\n🚀 Deploying simple-kubernetes-webhook..."
	kubectl create ns $(NAMESPACE)
	kubectl apply -f dev/manifests/webhook/ -n $(NAMESPACE)

.PHONY: delete
delete:
	@echo "\n♻️  Deleting simple-kubernetes-webhook deployment if existing..."
	kubectl delete -f dev/manifests/webhook/ -n $(NAMESPACE) || true
	kubectl delete ns $(NAMESPACE)

# deploy normal pod
.PHONY: pod
pod:
	@echo "\n🚀 Deploying test pod..."
	kubectl apply -f dev/manifests/pods/lifespan-seven.pod.yaml

.PHONY: delete-pod
delete-pod:
	@echo "\n♻️ Deleting test pod..."
	kubectl delete -f dev/manifests/pods/lifespan-seven.pod.yaml

# deploy bad pod
.PHONY: bad-pod
bad-pod:
	@echo "\n🚀 Deploying \"bad\" pod..."
	kubectl apply -f dev/manifests/pods/bad-name.pod.yaml

.PHONY: delete-bad-pod
delete-bad-pod:
	@echo "\n🚀 Deleting \"bad\" pod..."
	kubectl delete -f dev/manifests/pods/bad-name.pod.yaml

# others
.PHONY: logs
logs:
	@echo "\n🔍 Streaming simple-kubernetes-webhook logs..."
	kubectl logs -l app=simple-kubernetes-webhook -n $(NAMESPACE) -f

.PHONY: delete-all
delete-all: delete delete-config delete-pod delete-bad-pod
