.PHONY: package
package:
	@pack buildpack package example-bash/do-nothing

.PHONY: test
test: package
	@cd test && pack build do-nothing-test
