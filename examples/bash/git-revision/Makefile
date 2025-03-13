.PHONY: init
init: bin/dasel

bin/dasel:
	@curl -sL \
		"https://github.com/TomWright/dasel/releases/download/v2.8.1/dasel_linux_amd64" \
		-o "bin/dasel"
	@chmod +x bin/dasel

.PHONY: package
package: init
	@pack buildpack package bash-examples/git-revision

.PHONY: test/with-git
test/with-git: package
	@cd test/with-git && \
		git init 2> /dev/null && \
		git add . && \
	  git commit --no-gpg-sign -m "initial commit"
	@cd test/with-git && pack build local-template-test-with-git
	@cd test/with-git && pack build local-template-test-with-git
	@rm -rf test/with-git/.git/
	@docker run -it --rm --platform linux/amd64 --entrypoint test local-template-test-with-git

.PHONY: test/without-git
test/without-git: package
	@cd test/without-git && pack build local-template-test-without-git

.PHONY: clean
clean:
	@rm -f bin/dasel
	@rm -rf test/with-git/.git/
