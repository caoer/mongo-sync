FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN apt-get update \
      && apt-get install -y --no-install-recommends \
      numactl \
      && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
&& export GNUPGHOME="$(mktemp -d)" \
&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
&& gosu nobody true \
&& apt-get purge -y --auto-remove ca-certificates wget

ENV GPG_KEYS \
# pub   4096R/A15703C6 2016-01-11 [expires: 2018-01-10]
#       Key fingerprint = 0C49 F373 0359 A145 1858  5931 BC71 1F9B A157 03C6
# uid                  MongoDB 3.4 Release Signing Key <packaging@mongodb.com>
0C49F3730359A14518585931BC711F9BA15703C6
RUN set -ex; \
export GNUPGHOME="$(mktemp -d)"; \
for key in $GPG_KEYS; do \
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
done; \
gpg --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
rm -r "$GNUPGHOME"; \
apt-key list

ENV MONGO_MAJOR 3.4
ENV MONGO_VERSION 3.4.1
ENV MONGO_PACKAGE mongodb-org

RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/$MONGO_MAJOR main" > /etc/apt/sources.list.d/mongodb-org.list

RUN set -x \
&& apt-get update \
&& apt-get install -y \
${MONGO_PACKAGE}=$MONGO_VERSION \
${MONGO_PACKAGE}-server=$MONGO_VERSION \
${MONGO_PACKAGE}-shell=$MONGO_VERSION \
${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
${MONGO_PACKAGE}-tools=$MONGO_VERSION \
python-pip \
cron \
&& pip install awscli \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* \
&& rm -rf /var/lib/mongodb \
&& rm -rf /tmp/*  \
&& mkdir /backup \
&& mv /etc/mongod.conf /etc/mongod.conf.orig

# /* RUN mkdir -p /data/db /data/configdb \ */
# /* 	&& chown -R mongodb:mongodb /data/db /data/configdb */
# /* VOLUME /data/db /data/configdb */

      ADD docker_entrypoint.sh /docker_entrypoint.sh

      ADD backup.sh /backup.sh
      ADD restore.sh /restore.sh
      ADD sync.sh /sync.sh

      VOLUME ["/backup", "/var/log/"]

      ENTRYPOINT ["/docker_entrypoint.sh"]

      CMD ["backup"]
