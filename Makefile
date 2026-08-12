NY: default

usage:
	@echo "Available targets:"
	@echo " make init             --- Full setup: cluster, build all, deploy all"
	@echo " make setup            --- Create k3d cluster + registry at localhost:8888"
	@echo " make build-network    --- Helm dependency build for Cilium"
	@echo " make build-infra      --- Helm dependency build for Prometheus/Grafana/OTel"
	@echo " make build-apps       --- Build and push app Docker images to localhost:8888"
	@echo " make build-tools      --- Build tools for local use (e.g. tcpdump)"
	@echo " make deploy-network   --- Deploy Cilium network layer (kube-system ns)"
	@echo " make deploy-infra     --- Deploy infrastructure (default ns)"
	@echo " make deploy-apps      --- Deploy app Helm charts (default ns)"
	@echo " make bdnetwork        --- (Re)build and (re)deploy network only"
	@echo " make bdinfra          --- (Re)build and (re)deploy infrastructure only"
	@echo " make bdapps           --- (Re)build and (re)deploy applications only"
	@echo " make cleanup          --- Delete k3d cluster and registry"

init:
	make -j5 setup build-network build-infra build-apps build-tools
	make -j3 deploy-network deploy-infra deploy-apps

setup:
	k3d registry create observability-registry --port 8888
	k3d cluster create observability \
		--registry-use k3d-observability-registry:8888 \
		--k3s-arg "--disable=traefik@server:*" \
		--k3s-arg "--disable=metrics-server@server:*" \
		--k3s-arg "--disable=local-storage@server:*" \
		--k3s-arg "--disable=servicelb@server:*" \
		--k3s-arg "--flannel-backend=none" \
		--k3s-arg "--disable-network-policy" \
		--no-lb \
		--agents 0 \
		--wait

	docker exec -it k3d-observability-server-0 mount bpffs /sys/fs/bpf -t bpf
	docker exec -it k3d-observability-server-0 mount --make-shared /sys/fs/bpf

build-network:
	cd network; \
	helm dependency build;

build-infra:
	cd infra; \
	helm dependency build;

build-apps:
	curr=$$(CURDIR); \
	for dir in apps/*/; do \
		TAG=localhost:8888/$$(basename "$${dir%/}"):latest; \
		cd $$dir; \
		docker build -t $$TAG .; \
		docker push $$TAG; \
		cd $$curr; \
	done

build-tools:
	curr=$$(CURDIR); \
	for dir in tools/*/; do \
		TAG=$$(basename "$${dir%/}"); \
		cd $$dir; \
		docker build -t $$TAG .; \
		cd $$curr; \
	done

deploy-network:
	cd network; \
	helm upgrade --install --namespace kube-system network .

deploy-infra:
	cd infra; \
	helm upgrade --install observability . --create-namespace

deploy-apps:
	curr=$$(CURDIR); \
	for dir in apps/*/; do \
		APP=$$(basename "$${dir%/}"); \
		cd $$dir/helm; \
		helm upgrade --install $$APP . --create-namespace; \
		cd $$curr; \
	done

bdnetwork: build-network deploy-network

bdinfra: build-infra deploy-infra

bdapps: build-apps deploy-apps

cleanup:
	k3d cluster stop observability
	k3d cluster delete observability
	k3d registry delete k3d-observability-registry

default: usage
