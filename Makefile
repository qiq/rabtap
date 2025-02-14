# rabtap makefile

SOURCE=$(shell find . -name "*go" -a -not -path "./vendor/*" -not -path "./cmd/testgen/*" )
VERSION=$(shell git describe --tags)
TOXICMD:=docker compose exec toxiproxy /go/bin/toxiproxy-cli

.PHONY: phony

build: phony
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags \
				"-s -w -X main.version=$(VERSION)" -o ./bin/rabtap ./cmd/rabtap
wasm-build: phony
	CGO_ENABLED=1 GOOS=wasip1 GOARCH=wasm go build -o ./bin/rabtap-wasm ./cmd/rabtap

tags: $(SOURCE)
	@gotags -f tags $(SOURCE)

lint: phony
	golangci-lint run

short-test:  phony
	go test -v $(TESTOPTS) -race  github.com/jandelgado/rabtap/cmd/rabtap
	go test -v $(TESTOPTS) -race  github.com/jandelgado/rabtap/pkg

test-app: phony
	go test -race -v -tags "integration" $(TESTOPTS) -cover -coverprofile=coverage_app.out github.com/jandelgado/rabtap/cmd/rabtap

test-lib: phony
	go test -race -v -tags "integration" $(TESTOPTS) -cover -coverprofile=coverage.out github.com/jandelgado/rabtap/pkg

test: test-app test-lib
	grep -v "^mode:" coverage_app.out >> coverage.out
	go tool cover -func=coverage.out

# docker-compose up must be first called. Then create a proxy with
# this target and connect to to localhost:55672 (amqp).
toxiproxy-setup: phony
	$(TOXICMD) c amqp --listen :55672 --upstream rabbitmq:5672 || true

# call with e.g. 
# make toxiproxy-cmd         -- show help
# make TOXIARGS="toggle amqp"  -- toggle amqp proxy
toxiproxy-cmd: phony
	$(TOXICMD) $(TOXIARGS)

# run rabbitmq server for integration test using docker container.
run-broker: phony
	cd inttest/pki && ./mkcerts.sh
	cd inttest/rabbitmq && docker compose up

dist-clean: clean
	rm -rf *.out bin/ dist/

clean: phony
	go clean -r ./cmd/rabtap
	go clean -r ./cmd/testgen

phony:
