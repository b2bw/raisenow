raisenow.js: raisenow.js.template raisenow.yml
	cat $< | RNW_JSON=$$(yq raisenow.yml -o json) envsubst > $@
