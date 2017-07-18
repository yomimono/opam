#!/bin/sh -e

V=ocaml-4.04.0
URL=http://caml.inria.fr/pub/distrib/ocaml-4.04/${V}.tar.gz
mkdir -p bootstrap
cd bootstrap
if [ ! -e ${V}.tar.gz ]; then
  if command -v curl > /dev/null; then
    curl -OL ${URL}
  elif command -v wget > /dev/null; then
    wget ${URL}
  else
    echo "This script requires curl or wget"
    exit 1
  fi
fi
tar -zxf ${V}.tar.gz
cd ${V}
  echo "export PATH:=${PATH_PREPEND}${PREFIX}/bin:\$(PATH)" > ../../src_ext/Makefile.config
  echo "export Lib:=${LIB_PREPEND}\$(Lib)" >> ../../src_ext/Makefile.config
  echo "export Include:=${INC_PREPEND}\$(Include)" >> ../../src_ext/Makefile.config
  echo "export OCAMLLIB=${WINPREFIX}/lib" >> ../../src_ext/Makefile.config
./configure -prefix "`pwd`/../ocaml"
${MAKE:-make} world opt.opt
${MAKE:-make} install
