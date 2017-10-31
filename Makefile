#
# Makefile for a Video Disk Recorder plugin
#
# $Id$

# The official name of this plugin.
# This name will be used in the '-P...' option of VDR to load the plugin.
# By default the main source file also carries this name.

PLUGIN = sc

### The version number of this plugin (taken from the main source file):
DISTFILE = .distvers
HGARCHIVE = .hg_archival.txt
RELEASE := $(shell grep 'define SC_RELEASE' sc-version.h | awk '{ print $$3 }' | sed -e 's/[";]//g')
SUBREL  := $(shell if test -d .hg; then \
                     echo -n "HG-"; (hg identify 2>/dev/null || echo -n "Unknown") | sed -e 's/ .*//'; \
                   elif test -r $(HGARCHIVE); then \
                     echo -n "AR-"; grep "^node" $(HGARCHIVE) | awk '{ printf "%.12s",$$2 }'; \
                   elif test -r $(DISTFILE); then \
                     cat $(DISTFILE); \
                   else \
                     echo -n "Unknown"; \
                   fi)
VERSION := $(RELEASE)-$(SUBREL)
SCAPIVERS := $(shell sed -ne '/define SCAPIVERS/ s/^.[a-zA-Z ]*\([0-9]*\).*$$/\1/p' sc-version.h)
### The directory environment:

# Use package data if installed...otherwise assume we're under the VDR source directory:
PKGCFG = $(if $(VDRDIR),$(shell pkg-config --variable=$(1) $(VDRDIR)/vdr.pc),$(shell pkg-config --variable=$(1) vdr || pkg-config --variable=$(1) ../../../vdr.pc))
LIBDIR = $(call PKGCFG,libdir)
LOCDIR = $(call PKGCFG,locdir)
PLGCFG = $(call PKGCFG,plgcfg)
#

SYSDIR  = ./systems
PREDIR  = ./systems-pre
LIBS   := -lcrypto
TMPDIR ?= /tmp

### The compiler options:

export CFLAGS   = $(call PKGCFG,cflags)
export CXXFLAGS = $(call PKGCFG,cxxflags)
export SCAPIVERS
export APIVERSION

### The version number of VDR's plugin API:

APIVERSION = $(call PKGCFG,apiversion)

### Allow user defined options to overwrite defaults:

-include $(PLGCFG)

### The name of the distribution archive:

ARCHIVE = $(PLUGIN)-$(VERSION)
PACKAGE = vdr-$(ARCHIVE)

### The name of the shared object file:

SOFILE = libvdr-$(PLUGIN).so

### Includes and Defines (add further entries here):

INCLUDES +=

DEFINES += -DPLUGIN_NAME_I18N='"$(PLUGIN)"'

### The object files (add further files here):

OBJS = $(PLUGIN).o data.o filter.o system.o misc.o cam.o device.o sc-version.o \
       smartcard.o network.o crypto.o system-common.o parse.o log.o \
       override.o

# max number of CAIDs per slot
MAXCAID := 64

# FFdeCSA
PARALLEL   ?= PARALLEL_128_SSE2
CSAFLAGS   ?= -fexpensive-optimizations -fomit-frame-pointer -funroll-loops -O3 -mmmx -msse -msse2 -msse3
FFDECSADIR  = FFdecsa
FFDECSA     = $(FFDECSADIR)/FFdecsa.o
DECSALIB    = $(FFDECSA)

### The main target:

all: $(SOFILE) systems-pre systems i18n


### Implicit rules:

%.o: %.c
	$(CXX) $(CXXFLAGS) -c $(DEFINES) $(INCLUDES) -o $@ $<

### Dependencies:

MAKEDEP = $(CXX) -MM -MG
DEPFILES = $(subst i18n.c,,$(subst sc-version.c,,$(OBJS:%.o=%.c)))
$(DEPFILE): $(DEPFILES) $(wildcard *.h)
	@$(MAKEDEP) $(CXXFLAGS) $(DEFINES) $(INCLUDES) $(OBJS:%.o=%.c) > $@

-include $(DEPFILE)

### Internationalization (I18N):

PODIR     = po
I18Npo    = $(wildcard $(PODIR)/*.po)
I18Nmo    = $(addsuffix .mo, $(foreach file, $(I18Npo), $(basename $(file))))
I18Nmsgs  = $(addprefix $(DESTDIR)$(LOCDIR)/, $(addsuffix /LC_MESSAGES/vdr-$(PLUGIN).mo, $(notdir $(foreach file, $(I18Npo), $(basename $(file))))))
I18Npot   = $(PODIR)/$(PLUGIN).pot

%.mo: %.po
	msgfmt -c -o $@ $<

$(I18Npot): $(wildcard *.c)
	xgettext -C -cTRANSLATORS --no-wrap --no-location -k -ktr -ktrNOOP --package-name=vdr-$(PLUGIN) --package-version=$(VERSION) --msgid-bugs-address='<see README>' -o $@ `ls $^`

%.po: $(I18Npot)
	msgmerge -U --no-wrap --no-location --backup=none -q -N $@ $<
	@touch $@

$(I18Nmsgs): $(DESTDIR)$(LOCDIR)/%/LC_MESSAGES/vdr-$(PLUGIN).mo: $(PODIR)/%.mo
	install -D -m644 $< $@

.PHONY: i18n systems systems-pre
i18n: $(I18Nmo) $(I18Npot)

sc-version.c:
	@echo >$@.new "/* generated file, do not edit */"; \
		echo >>$@.new 'const char *ScVersion =' '"'$(VERSION)'";'; \
		diff $@.new $@ >$@.diff 2>&1; \
		if test -s $@.diff; then mv -f $@.new $@; fi; \
		rm -f $@.new $@.diff;

systems:
	@mkdir -p lib
	@for i in `ls -A -I ".*" $(SYSDIR)`; do  $(MAKE) LIBDIR=../../lib -f ../../Makefile.system -C "$(SYSDIR)/$$i" all || exit 1; done

systems-pre:
	@for i in `ls -A -I ".*" $(PREDIR) | grep -- '-$(SCAPIVERS).so.$(APIVERSION)$$'`; do cp -p "$(PREDIR)/$$i" "$(LIBDIR)"; done

contrib:
	@$(MAKE) -C contrib all

install-i18n: $(I18Nmsgs)

### Targets:

$(SOFILE): $(OBJS) $(FFDECSA)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared $(OBJS) $(FFDECSA) $(LIBS) -o $@

$(FFDECSA): $(FFDECSADIR)/*.c $(FFDECSADIR)/*.h
	@$(MAKE) COMPILER="$(CXX)" FLAGS="$(CXXFLAGS) $(CSAFLAGS)" PARALLEL_MODE=$(PARALLEL) -C $(FFDECSADIR) all

install-lib: $(SOFILE)
	install -D $^ $(DESTDIR)$(LIBDIR)/$^.$(APIVERSION)
	install -D lib/* $(DESTDIR)$(LIBDIR)/

install: install-lib install-i18n

dist: $(I18Npo) clean
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@mkdir -p  $(TMPDIR)/$(ARCHIVE)
	@cp -a * $(TMPDIR)/$(ARCHIVE)
	@tar czf $(PACKAGE).tgz -C $(TMPDIR) $(ARCHIVE)
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@echo Distribution package created as $(PACKAGE).tgz

clean-systems:
	@for i in `ls -A -I ".*" $(SYSDIR)`; do > /dev/null 2>&1 $(MAKE) -f ../../Makefile.system -C "$(SYSDIR)/$$i" clean; done

clean-ffdecsa:
	@-rm -f $(FFDECSADIR)/FFdecsa_test $(FFDECSADIR)/FFdecsa_test.done $(FFDECSADIR)/*.o


clean: clean-systems clean-ffdecsa
	@-rm -f $(PODIR)/*.mo $(PODIR)/*.pot
	@-rm -f $(OBJS) $(DEPFILE) *.so *.tgz core* *~
	@-rm -rf lib
