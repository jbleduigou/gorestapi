EXECUTABLE := gorestapicmd
GITVERSION := $(shell git describe --dirty --always --tags --long)
GOPATH ?= ${HOME}/go
PACKAGENAME := $(shell go list -m -f '{{.Path}}')
TOOLS := ${GOPATH}/bin/mockery \
	${GOPATH}/bin/swagger
SWAGGERSOURCE = $(wildcard gorestapi/*.go) \
	$(wildcard gorestapi/mainrpc/*.go)

.PHONY: default
default: ${EXECUTABLE}

tools: ${TOOLS}

${GOPATH}/bin/mockery:
	go get github.com/vektra/mockery/cmd/mockery 

${GOPATH}/bin/swagger:
	wget -O ${GOPATH}/bin/swagger https://github.com/go-swagger/go-swagger/releases/download/v0.25.0/swagger_linux_amd64
	chmod 755 ${GOPATH}/bin/swagger

.PHONY: swagger
swagger: tools ${SWAGGERSOURCE}
	swagger generate spec --scan-models -o embed/public_html/api-docs/swagger.json

embed/public_html/api-docs/swagger.json: tools ${SWAGGERSOURCE}
	swagger generate spec --scan-models -o embed/public_html/api-docs/swagger.json 

.PHONY: mocks
mocks: tools
	mockery -dir ./gorestapi -name GRStore

.PHONY: ${EXECUTABLE}
${EXECUTABLE}: tools embed/public/api-docs/swagger.json
	# Compiling...
	go build -ldflags "-X ${PACKAGENAME}/conf.Executable=${EXECUTABLE} -X ${PACKAGENAME}/conf.GitVersion=${GITVERSION}" -o ${EXECUTABLE}

.PHONY: test
test: tools mocks
	go test -cover ./...

.PHONY: deps
deps:
	# Fetching dependancies...
	go get -d -v # Adding -u here will break CI

.PHONY: lint
lint:
	docker run --rm -v ${PWD}:/app -w /app golangci/golangci-lint:v1.27.0 golangci-lint run -v --timeout 5m

.PHONY: hadolint
hadolint:
	docker run -it --rm -v ${PWD}/Dockerfile:/Dockerfile hadolint/hadolint:latest hadolint --ignore DL3018 Dockerfile

.PHONY: relocate
relocate:
	@test ${TARGET} || ( echo ">> TARGET is not set. Use: make relocate TARGET=<target>"; exit 1 )
	$(eval ESCAPED_PACKAGENAME := $(shell echo "${PACKAGENAME}" | sed -e 's/[\/&]/\\&/g'))
	$(eval ESCAPED_TARGET := $(shell echo "${TARGET}" | sed -e 's/[\/&]/\\&/g'))
	# Renaming package ${PACKAGENAME} to ${TARGET}
	@grep -rlI '${PACKAGENAME}' * | xargs -i@ sed -i 's/${ESCAPED_PACKAGENAME}/${ESCAPED_TARGET}/g' @
	# Complete... 
	# NOTE: This does not update the git config nor will it update any imports of the root directory of this project.

