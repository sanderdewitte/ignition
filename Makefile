.PHONY: all generate-ignition generate-butane clean clean-temp clean-ignition clean-butane

.ONESHELL:
SHELL := /bin/bash

DOCKER := /usr/bin/env docker
YAML_PROCESSOR_IMAGE := docker.io/mikefarah/yq:latest
BUTANE_IMAGE := quay.io/coreos/butane:latest

TEMP_DIR := ./temp.d
BUTANE_DIR := ./butane.d

BUTANE := ignition.bu
BUTANE_OPTIONS := --strict
BUTANE_MERGERS := ""
ifneq ("$(wildcard $(BUTANE))","")
	BUTANE_MERGERS := $(foreach BUTANE_MERGE,$(shell awk -F '/' '/^\s+merge:/ && !f{f=1;x=$$0;sub(/[^ ].*/,"",x);x=x" ";next} f {if (substr($$0,1,length(x))==x)print $$NF; else f=0}' ${BUTANE}),$(if $(wildcard ${BUTANE_DIR}/${BUTANE_MERGE}),${BUTANE_DIR}/${BUTANE_MERGE}))
endif

IGNITION := $(BUTANE:.bu=.ign)

all: ignition clean

generate-butane:
	mkdir -p ${TEMP_DIR} && ln -s ../files ${TEMP_DIR}/files
	${DOCKER} run --rm \
		--volume ${PWD}:/workdir:Z \
		${YAML_PROCESSOR_IMAGE} \
		eval-all '. as $$item ireduce ({}; . *+ $$item )' ./${BUTANE} ${BUTANE_MERGERS} \
	        > ${TEMP_DIR}/${BUTANE}
	${DOCKER} run --rm \
		--volume ${PWD}:/workdir:Z \
		${YAML_PROCESSOR_IMAGE} \
		--inplace \
		eval 'del(.ignition.config.merge)' ${TEMP_DIR}/${BUTANE}

butane: clean-butane generate-butane

generate-ignition: butane
	$(DOCKER) run --rm \
		--volume ${PWD}:/pwd \
		--workdir /pwd \
		$(BUTANE_IMAGE) \
		$(BUTANE_OPTIONS) \
		--files-dir ${TEMP_DIR}/ \
		--output ./$(IGNITION) \
		${TEMP_DIR}/${BUTANE}

ignition: clean-ignition generate-ignition

clean-butane:
	rm -f ${TEMP_DIR}/${BUTANE}

clean-ignition:
	rm -f ./$(IGNITION)
	rm -f ${TEMP_DIR}/${IGNITION}

clean-temp:
	rm -rf ${TEMP_DIR}

clean: clean-butane clean-temp
