IMAGE ?= bborbe/kubernetes-deploy
REGISTRY ?= docker.io

ifeq ($(VERSION),)
	VERSION = $(shell git fetch --tags; git describe --tags `git rev-list --tags --max-count=1`)
endif

all: test install run

glide:
	go get github.com/Masterminds/glide

test: glide
	GO15VENDOREXPERIMENT=1 go test -cover `glide novendor`

dep: glide
	glide up
	glide install

install:
	GOBIN=$(GOPATH)/bin GO15VENDOREXPERIMENT=1 go install bin/k8s-deploy/*.go

run:
	k8s-deploy \
	-dir=~/Documents/workspaces/kubernetes/manifests/netcup \
	-logtostderr \
	-v=4

goimports:
	go get golang.org/x/tools/cmd/goimports

format: goimports
	find . -type f -name '*.go' -not -path './vendor/*' -exec gofmt -w "{}" +
	find . -type f -name '*.go' -not -path './vendor/*' -exec goimports -w "{}" +

buildgo:
	CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o k8s-deploy ./go/src/github.com/bborbe/k8s_deploy/cmd/k8s-deploy

build:
	docker build --no-cache --rm=true -t $(REGISTRY)/$(IMAGE)-build:$(VERSION) -f ./Dockerfile.build .
	docker run -t $(REGISTRY)/$(IMAGE)-build:$(VERSION) /bin/true
	docker cp `docker ps -q -n=1 -f ancestor=$(REGISTRY)/$(IMAGE)-build:$(VERSION) -f status=exited`:/k8s-deploy .
	docker rm `docker ps -q -n=1 -f ancestor=$(REGISTRY)/$(IMAGE)-build:$(VERSION) -f status=exited` || true
	docker build --no-cache --rm=true --tag=$(REGISTRY)/$(IMAGE):$(VERSION) -f Dockerfile.static .
	rm -f k8s-deploy

upload:
	docker push $(REGISTRY)/$(IMAGE):$(VERSION)

clean:
	docker rmi $(REGISTRY)/$(IMAGE):$(VERSION) || true

