NAMESPACE  ?= default
REPOSITORY ?= quay.io/steigr/postgres-operator
PREFIX     ?= postgres

all: release
	@true

release:
	./generate-and-install-operator.sh "$(NAMESPACE)" "$(REPOSITORY)" "$(shell git describe --tags 2>/dev/null)" "$(PREFIX)"