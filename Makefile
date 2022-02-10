# SHELL := /bin/bash

RELEASE := sqlproxy
NAMESPACE := sqlproxy

CHART_NAME := rimusz/gcloud-sqlproxy
CHART_VERSION ?= 0.22.6

DEV_CLUSTER ?= p4-development
DEV_PROJECT ?= planet-4-151612
DEV_ZONE ?= us-central1-a


ifndef CLOUD_SERVICE_KEY
$(error CLOUD_SERVICE_KEY unset)
endif

PROD_CLUSTER ?= planet4-production
PROD_PROJECT ?= planet4-production
PROD_ZONE ?= us-central1-a

.DEFAULT_TARGET: status

lint:
	@find . -type f -name '*.yml' | xargs yamllint
	@find . -type f -name '*.yaml' | xargs yamllint

init:
	helm3 repo add rimusz https://charts.rimusz.net
	helm3 repo update

dev: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)
	-kubectl create namespace $(NAMESPACE)
	helm3 upgrade --install $(RELEASE) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--set serviceAccountKey=$(CLOUD_SERVICE_KEY) \
		-f values.yaml \
		-f env/dev/values.yaml \
		$(CHART_NAME)
	$(MAKE) history

prod: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_PROJECT) --zone $(PROD_ZONE) --project $(PROD_PROJECT)
	-kubectl create namespace $(NAMESPACE)
	helm3 upgrade --install $(RELEASE) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--set serviceAccountKey=$(CLOUD_SERVICE_KEY) \
		-f values.yaml \
		-f env/prod/values.yaml \
		$(CHART_NAME)
	$(MAKE) history

destroy:
	helm3 uninstall --purge $(RELEASE)
	-kubectl delete namespace $(NAMESPACE)

history:
	helm3 history $(RELEASE) --max=5
