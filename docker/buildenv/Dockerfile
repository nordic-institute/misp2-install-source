FROM ubuntu:18.04 AS BUILD
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qq update \
    && apt-get -qq upgrade \
    && apt-get -qq install \
        curl software-properties-common gawk wget devscripts openjdk-8-jdk-headless maven ant build-essential git unzip debhelper locales \
    && locale-gen en_US.UTF-8 \
    && update-locale "LANG=en_US.UTF-8"

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID builder && useradd -m -u $UID -g $GID builder

USER builder
WORKDIR /home/builder
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV LANG=en_US.UTF-8

RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB \
    && mkdir /home/builder/bin \
    && mkdir /home/builder/misp2

COPY --chown=builder:builder build_misp2_packages.sh /home/builder/bin/

ENV PATH /home/builder/bin:$PATH
CMD bash -l


