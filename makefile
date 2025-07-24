GOLANG          := golang:1.24.1
ALPINE          := alpine:3.22.4
KIND            := kindest/node:v1.32.0
POSTGRES        := postgres:17.5
GRAFANA         := grafana/grafana:11.5.10
PROMETHEUS      := prom/prometheus:v3.4.0
TEMPO           := grafana/tempo:2.6.0
LOKI            := grafana/loki:3.4.0
PROMTAIL        := grafana/promtail:3.4.0

KIND_CLUSTER    := ardan-starter-cluster
NAMESPACE       := products-system
PRODUCTS_APP    := products
BASE_IMAGE_NAME := localhost/kristi
SERVICE_NAME    := products-api
VERSION         := 0.0.1
SERVICE_IMAGE  := $(BASE_IMAGE_NAME)/$(PRODUCTS_APP):$(VERSION)
METRICS_IMAGE   := $(BASE_IMAGE_NAME)/metrics:$(VERSION)
AUTH_IMAGE      := $(BASE_IMAGE_NAME)/$(AUTH_APP):$(VERSION)


run:
	go run app/services/products-api/main.go | go run app/tooling/logfmt/main.go

dev-up:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

dev-down:
	kind delete cluster --name $(KIND_CLUSTER)

dev-load:
	cd zarf/k8s/dev/products; kustomize edit set image service-image=$(SERVICE_IMAGE)
	kind load docker-image $(SERVICE_IMAGE) --name $(KIND_CLUSTER)

dev-apply:
	kustomize build zarf/k8s/dev/products | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(PRODUCTS_APP) --timeout=120s --for=condition=Ready

dev-restart:
	kubectl rollout restart deployment $(PRODUCTS_APP) --namespace=$(NAMESPACE)

dev-update: all dev-load dev-restart

dev-update-apply: all dev-load dev-apply

dev-logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(PRODUCTS_APP) --all-containers=true -f --tail=100 --max-log-requests=6 | go run app/services/products-api/main.go -service=$(SERVICE_NAME)

dev-describe-deployment:
	kubectl describe deployment --namespace=$(NAMESPACE) $(PRODUCTS_APP)

dev-describe-products:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(PRODUCTS_APP)

dev-status-all:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

dev-status:
	watch -n 2 kubectl get pods -o wide --all-namespaces

all: service

service:
	docker build \
		-f zarf/docker/dockerfile.service \
		-t $(SERVICE_IMAGE) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
		.
