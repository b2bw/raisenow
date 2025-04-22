# Dependencies:
#
#   ruby aws-cli entr curl qrencode webfsd

-include local.mk

.PHONY: build
build: clean public pricing.csv
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

IP:=$(shell ip route get 1 | awk '{print $$(NF-2);exit}')
PORT:=4567
URL:=http://$(IP):$(PORT)/

.PHONY: serve
serve:
	@qrencode -t UTF8i $(URL)
	@echo "$(URL)\n"
	@webfsd -F -d -p $(PORT) -r public

.PHONY: pricing.csv
pricing.csv:
	curl -L 'https://docs.google.com/spreadsheets/d/16o9LxUvctPqDZcw3sb4pq0d67AcDdZiNZPYIyLVlc7I/export?format=csv&id=16o9LxUvctPqDZcw3sb4pq0d67AcDdZiNZPYIyLVlc7I&gid=0' > pricing.csv

.PHONY: deploy
deploy-staging:
	rsync -avz public/ 2q8l5_phil@185.125.27.16:sites/static.bos-schweiz.ch/raisenow-forms-staging/
