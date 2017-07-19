ifeq ($(findstring clean,$(MAKECMDGOALS)),)
-include Makefile.config
endif

all: opam-lib opam opam-installer
	@

ifeq ($(JBUILDER),)
JBUILDER_DEP=src_ext/jbuilder/_build/install/default/bin/jbuilder.exe
JBUILDER:=$(shell echo "$(JBUILDER_DEP)" | cygpath -f - -a)
else
JBUILDER_DEP=
endif

src_ext/jbuilder/_build/install/default/bin/jbuilder.exe: src_ext/jbuilder.stamp
	cd src_ext/jbuilder && ocaml bootstrap.ml && ./boot

src_ext/jbuilder.stamp:
	make -C src_ext jbuilder.stamp

jbuilder: $(JBUILDER_DEP)
	@$(JBUILDER) build @install

ALWAYS:
	@

opam-lib opam opam-installer all: ALWAYS

#backwards-compat
compile with-ocamlbuild: all
	@
install-with-ocamlbuild: install
	@
libinstall-with-ocamlbuild: libinstall
	@

byte:
	$(MAKE) all USE_BYTE=true

src/%:
	$(MAKE) -C src $*

# Disable this rule if the only build targets are cold, download-ext or configure
# to suppress error messages trying to build Makefile.config
ifneq ($(or $(filter-out cold download-ext lib-pkg configure,$(MAKECMDGOALS)),$(filter own-goal,own-$(MAKECMDGOALS)goal)),)
%:
	$(MAKE) -C src $@
endif

lib-ext:
	$(MAKE) -j -C src_ext lib-ext

lib-pkg:
	$(MAKE) -j -C src_ext lib-pkg

download-ext:
	$(MAKE) -C src_ext archives

download-pkg:
	$(MAKE) -C src_ext archives-pkg

clean-ext:
	$(MAKE) -C src_ext distclean

clean: fastclean
	$(MAKE) -C src $@
	$(MAKE) -C doc $@
	rm -f *.install *.env *.err *.info *.out
	rm -rf _obuild _build

distclean: clean clean-ext
	rm -rf autom4te.cache bootstrap
	rm -f .merlin Makefile.config config.log config.status src/core/opamVersion.ml src/core/opamCoreConfig.ml aclocal.m4
	rm -f src/*.META src/*/.merlin src/ocaml-flags-standard.sexp

OPAMINSTALLER_FLAGS = --prefix "$(DESTDIR)$(prefix)"
OPAMINSTALLER_FLAGS += --mandir "$(DESTDIR)$(mandir)"

# With ocamlfind, prefer to install to the standard directory rather
# than $(prefix) if there are no overrides
ifdef OCAMLFIND
ifndef DESTDIR
ifneq ($(OCAMLFIND),no)
    LIBINSTALL_DIR ?= $(shell $(OCAMLFIND) printconf destdir)
endif
endif
endif

ifneq ($(LIBINSTALL_DIR),)
    OPAMINSTALLER_FLAGS += --libdir "$(LIBINSTALL_DIR)"
endif

opam-%.install: ALWAYS
	$(MAKE) -C src ../opam-$*.install

opam.install:
	@echo 'bin: [' >$@
	@echo '  "src/opam$(EXE)"' >>$@
	@echo '  "src/opam-installer$(EXE)"' >>$@
	@echo ']' >>$@
	@echo 'man: [' >>$@
	@$(patsubst %,echo '  "'%'"' >>$@;,$(wildcard doc/man/*.1))
	@echo ']' >>$@
	@echo 'doc: [' >>$@
	@$(foreach x,$(wildcard doc/man-html/*.html),\
	  echo '  "$x" {"man/$(notdir $x)"}' >>$@;)
	@$(foreach x,$(wildcard doc/pages/*.html),\
	  echo '  "$x" {"$(notdir $x)"}' >>$@;)
	@echo ']' >>$@

opam-devel.install:
	@echo 'libexec: [' >$@
	@echo '  "_obuild/opam/opam.asm" {"opam"}' >>$@
	@echo '  "_obuild/opam-installer/opam-installer.asm" {"opam-installer"}' >>$@
	@echo ']' >>$@

OPAMLIBS = core format solver repository state client

installlib-%: opam-installer opam-%.install src/opam-%$(LIBEXT)
	$(if $(wildcard src_ext/lib/*),\
	  $(error Installing the opam libraries is incompatible with embedding \
	          the dependencies. Run 'make clean-ext' and try again))
	src/opam-installer $(OPAMINSTALLER_FLAGS) opam-$*.install

uninstalllib-%: opam-installer opam-%.install src/opam-%$(LIBEXT)
	src/opam-installer -u $(OPAMINSTALLER_FLAGS) opam-$*.install

libinstall: opam-admin.top $(OPAMLIBS:%=installlib-%)
	@

install: opam.install
	src/opam-installer $(OPAMINSTALLER_FLAGS) $<

libuninstall: $(OPAMLIBS:%=uninstalllib-%)
	@

uninstall: opam.install
	src/opam-installer -u $(OPAMINSTALLER_FLAGS) opam.install

.PHONY: tests tests-local tests-git
tests:
	$(MAKE) -C tests all

# tests-local, tests-git
tests-%:
	$(MAKE) -C tests $*

.PHONY: doc
doc: all
	$(MAKE) -C doc

.PHONY: man man-html
man man-html: opam opam-installer
	$(MAKE) -C doc $@

configure: configure.ac m4/*.m4
	aclocal -I m4
	autoconf

release-tag:
	git tag -d latest || true
	git tag -a latest -m "Latest release"
	git tag -a $(version) -m "Release $(version)"

fastlink:
	@$(foreach b,opam opam-installer opam-check,\
	   ln -sf ../_obuild/$b/$b.asm src/$b;)
	@$(foreach l,core format solver repository state client,\
	   $(foreach e,a cma cmxa,ln -sf ../_obuild/opam-$l/opam-$l.$e src/opam-$l.$e;)\
	   $(foreach e,o cmo cmx cmxs cmi cmt cmti,\
	       $(foreach f,$(wildcard _obuild/opam-$l/*.$e),\
		   ln -sf ../../$f src/$l;)))
	@ln -sf ../_obuild/opam-admin.top/opam-admin.top.byte src/opam-admin.top
	@$(foreach e,o cmo cmx cmxs cmi cmt cmti,\
	   $(foreach f,$(wildcard _obuild/opam-admin.top/*.$e),\
	       ln -sf ../../$f src/tools/;))

rmartefacts: ALWAYS
	@rm -f $(addprefix src/, opam opam-installer opam-check)
	@$(foreach l,core format solver repository state client tools,\
	   $(foreach e,a cma cmxa,rm -f src/opam-$l.$e;)\
	   $(foreach e,o cmo cmx cmxs cmi cmt cmti,rm -f $(wildcard src/$l/*.$e);))

prefast: rmartefacts src/client/opamGitVersion.ml src/state/opamScript.ml src/core/opamCompat.ml src/core/opamCompat.mli
	@

fast: prefast
	@rm -f src/x_build_libs.ocp
	@ocp-build init
	@ocp-build
	@$(MAKE) fastlink

opam-core opam-format opam-solver opam-repository opam-state opam-client opam-devel opam-tools: prefast ALWAYS
	@ocp-build init
	@echo "build_libs = [ \"$@\" ]" > src/x_build_libs.ocp
	@ocp-build
	@rm -f src/x_build_libs.ocp

opam-devel: opam-devel.install

fastclean: rmartefacts
	@rm -f src/x_build_libs.ocp
	@ocp-build -clean 2>/dev/null || ocp-build clean 2>/dev/null || true
	@rm -rf src/*/_obuild

cold:
	./shell/bootstrap-ocaml.sh
	env PATH="`pwd`/bootstrap/ocaml/bin:$$PATH" ./configure $(CONFIGURE_ARGS)
	env PATH="`pwd`/bootstrap/ocaml/bin:$$PATH" $(MAKE) lib-ext
	env PATH="`pwd`/bootstrap/ocaml/bin:$$PATH" $(MAKE)
