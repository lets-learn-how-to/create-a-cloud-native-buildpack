.PHONY: init
init: bin/dasel

bin/dasel:
	@curl -sL \
		"https://github.com/TomWright/dasel/releases/download/v2.8.1/dasel_linux_amd64" \
		-o "bin/dasel"
	@chmod +x bin/dasel

.PHONY: package
package: init
	@pack buildpack package template/bash

.PHONY: build
build: package
	@cd test && pack build --env BP_TEMPLATE_BASH_MAX_PRIME=10000 template-bash-test

.PHONY: test
test: package
	@cd test && pack build --env BP_TEMPLATE_BASH_MAX_PRIME=2000 template-bash-test
	@docker run -it --rm --platform linux/amd64 --entrypoint test template-bash-test

.PHONY: test/no-cache
test/no-cache: package
	@cd test && pack build --clear-cache --env BP_TEMPLATE_BASH_MAX_PRIME=2000 template-bash-test
	@docker run -it --rm --platform linux/amd64 --entrypoint test template-bash-test

.PHONY: clean
clean:
	@rm -f bin/dasel
