# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

PATONET_DRIVER_INCLUDES:= -I $(d) -I $(DRIVERS_DIR)/SVG $(PACK_DRIVER_Patonet)
PATONET_DRIVER_DEPS_INCLUDES:= -I $(d) -I $(DRIVERS_DIR)/SVG $(DEPS_PACK_DRIVER_Patonet)

$(d)/%.ml.depends: INCLUDES += $(PATONET_DRIVER_DEPS_INCLUDES)
$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx: INCLUDES += $(PATONET_DRIVER_INCLUDES)

SRC_$(d):=$(wildcard $(d)/*.ml)
DEPENDS_$(d) := $(addsuffix .depends,$(SRC_$(d)))
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(DEPENDS_$(d))
endif
endif

# cmi race condition
$(d)/Patonet.cmx: %.cmx: %.cmo

$(d)/Patonet.cma: $(d)/Patonet.cmo
	$(ECHO) "[MKL] $@"
	$(Q)$(OCAMLC) $(INCLUDES) $(OFLAGS) -a -o $@ $^

$(d)/Patonet.cmxa: $(d)/Patonet.cmx
	$(ECHO) "[MKL] $@"
	$(Q)$(OCAMLOPT) $(INCLUDES) $(OFLAGS) -a -o $@ $^

$(d)/Patonet.cmxs: $(d)/Patonet.cmx
	$(ECHO) "[SHR] $@"
	$(Q)$(OCAMLOPT) $(INCLUDES) $(OFLAGS) -linkpkg -shared -o $@ $^


CLEAN +=

DISTCLEAN += $(DEPENDS_$(d))

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
