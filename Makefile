# Dependencies:
#
#   ruby aws-cli entr

-include local.mk

.PHONY: build
build: clean public
	cp -v assets/* public/
	./build.rb

public:
	mkdir $@

.PHONY: deploy
deploy:
	aws s3 sync $(AWS_ARGS) --acl public-read public/ s3://www.bos-schweiz.ch/raisenow-forms/

.PHONY: clean
clean:
	rm -rf public/*

.PHONY: watch
watch:
	ls -1 assets/* *.yml *.rb */*.erb | entr make
