# Build Stage
FROM aflplusplus/aflplusplus as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git automake flex gettext gperf graphviz gzip help2man texinfo valgrind wget make perl rsync tar autopoint

ADD . /bison
WORKDIR /bison
RUN git submodule update --init
RUN git submodule update --recursive --remote

## Update autoconf to latest version
WORKDIR /bison/submodule/autoconf
RUN git submodule update --remote --merge

## Install autoconf 2.7.1
WORKDIR /
RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz
RUN tar -xf autoconf-2.71.tar.xz
WORKDIR /autoconf-2.71
RUN ./configure && make -j$(nproc) && make install

## Install libtextstyle
#WORKDIR /
#RUN wget https://alpha.gnu.org/gnu/gettext/libtextstyle-0.20.5.tar.gz
#RUN tar -xf libtextstyle-0.20.5.tar.gz
#WORKDIR /libtextstyle-0.20.5
#RUN ./configure && make -j$(nproc) && make install

## Build
ENV CC="afl-clang-fast"
ENV CXX="afl-clang-fast++"

WORKDIR /bison
RUN ./bootstrap
RUN mv doc/fdl.texi~ doc/fdl.texi
RUN ./configure enable_yacc=no
RUN make -j$(nproc)
RUN make install

## Package Stage
FROM aflplusplus/aflplusplus
COPY --from=builder /bison/src/bison /bison
#COPY --from=builder /libtextstyle-0.20.5 /libtextstyle
#COPY --from=builder /usr/local/lib/libtextstyle.so.0 /usr/lib

# Make test directory for debugging
RUN mkdir -p /tests && echo seed > /tests/seed

ENTRYPOINT ["afl-fuzz", "-i", "/tests", "-o", "/out"]
CMD ["/bison", "@@", "-d", "--output=/dev/stdout"]
