# Build Stage
FROM aflplusplus/aflplusplus as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git automake flex gettext gperf graphviz gzip help2man texinfo valgrind wget make perl rsync tar autopoint

## Add source code to the build stage. ADD prevents git clone being cached when it shouldn't
WORKDIR /
ADD https://api.github.com/repos/capuanob/bison/git/refs/heads/mayhem version.json
RUN git clone -b mayhem https://github.com/capuanob/bison.git
WORKDIR /bison
RUN git submodule update --init

## Install autoconf 2.7.1
WORKDIR /
RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz
RUN tar -xf autoconf-2.71.tar.xz
WORKDIR /autoconf-2.71
RUN ./configure && make -j$(nproc) && make install

## Install libtextstyle
WORKDIR /
RUN wget https://alpha.gnu.org/gnu/gettext/libtextstyle-0.20.5.tar.gz
RUN tar -xf libtextstyle-0.20.5.tar.gz
WORKDIR /libtextstyle-0.20.5
RUN ./configure && make -j$(nproc) && make install

## Build
ENV CC="afl-clang-fast"
ENV CXX="afl-clang-fast++"

WORKDIR /bison
RUN ./bootstrap
RUN ./configure
RUN make -j$(nproc)
RUN make install

## Prepare all library dependencies for copy
RUN mkdir /deps
RUN cp `ldd ./src/bison | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :
RUN cp `ldd /usr/bin/m4 | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :
RUN cp `ldd /usr/local/bin/afl-fuzz | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :


## Package Stage
FROM --platform=linux/amd64 ubuntu:22.04
COPY --from=builder /bison/src/bison /bison
COPY --from=builder /usr/local/bin/afl-fuzz /afl-fuzz
COPY --from=builder /deps /usr/lib
COPY --from=builder /usr/bin/m4 /usr/bin/m4
COPY --from=builder /usr/local/share /usr/local/share
COPY --from=builder /bison/examples /examples

## Create a corpus for debugging
RUN mkdir /tests && echo seed > /tests/seed

ENV AFL_SKIP_CPUFREQ=1
ENTRYPOINT ["/afl-fuzz", "-i", "/tests", "-o", "/out"]
CMD ["/bison", "@@", "-d", "--output=/dev/stdout"]
