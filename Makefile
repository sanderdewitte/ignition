.PHONY: clean
DOCKER = /usr/bin/env docker
ENCODER = base64
ENCODING_OPTION = -w0
BUTANE = ignition.bu
BUTANE_OPTIONS = --pretty --strict
IGNITION = $(BUTANE:.bu=.ign)
IGNITION_B64 = $(IGNITION).b64
BUTANE_IMAGE = quay.io/coreos/butane:release

$(IGNITION_B64): $(IGNITION)
	$(ENCODER) $(ENCODING_OPTION) $(IGNITION) > $(IGNITION_B64)

$(IGNITION): $(BUTANE)
	$(DOCKER) run --rm -i $(BUTANE_IMAGE) $(BUTANE_OPTIONS) < $(BUTANE) > $(IGNITION)

clean:
	rm -f $(IGNITION) $(IGNITION_B64)
