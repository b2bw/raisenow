-include local.mk

.PHONY: build
build: public
	./build.rb

public:
	mkdir $@

.PHONY: deploy
deploy:
	aws s3 sync $(AWS_ARGS) --acl public-read public/ s3://www.bos-schweiz.ch/raisenow-forms/

.PHONY: clean
clean:
	rm -rf public
