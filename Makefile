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
	rsync -avz public/ 2q8l5_phil@185.125.27.16:sites/static.bos-schweiz.ch/raisenow-forms/

.PHONY: clean
clean:
	rm -rf public/*

.PHONY: watch
watch:
	ls -1 assets/* *.yml *.rb */*.erb | entr make
