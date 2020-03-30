## 使用docker-compose build --build-arg DockerID=$(cat /etc/group|grep docker|cut -d':' -f3)
# 更新 jenkins ,tini ,docker version
FROM ubuntu:18.04

###########################################################################
# ARG app Version
###########################################################################

ARG DockerID=999

###########################################################################
# ENV for Master
###########################################################################
ENV user=jenkins
ENV group=jenkins
ENV uid=1000
ENV gid=1000
ENV http_port=8080
ENV agent_port=50000
ENV TINI_VERSION=v0.18.0
ENV JENKINS_VERSION=2.222.1
ENV JENKINS_SHA=5a6cbb836ceb79728c2d9f72645d0680f789cdb09a44485076aba6143bea953e
ENV JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log
ENV DEBIAN_FRONTEND noninteractive
ENV DOCKER_VERSION=19.03.0

###########################################################################
# EXPOSE
###########################################################################
EXPOSE ${http_port}
EXPOSE ${agent_port}

###########################################################################
# COPY
###########################################################################
COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy
COPY init_login.groovy /usr/share/jenkins/ref/init.groovy.d/set-user-security.groovy

###########################################################################
# RUN
###########################################################################

## apt update && apt-get clean
RUN echo "######### apt update ##########" \
  && apt-get update && apt-get install -y apt-utils default-jdk gnupg sudo wget git curl locales unzip --assume-yes  \
  && rm -rf /var/lib/apt/lists/* && apt-get clean

RUN echo "######### dash > bash ##########" \
  && mv /bin/sh /bin/sh.old && ln -s bash /bin/sh \
  && echo "######### add root bashrc ##########" \
  && locale-gen zh_TW.UTF-8 && echo 'export LANGUAGE="zh_TW.UTF-8"' >> /root/.bashrc \
  && echo 'export LANG="zh_TW.UTF-8"' >> /root/.bashrc \
  && echo 'export LC_ALL="zh_TW.UTF-8"' >> /root/.bashrc && update-locale LANG=zh_TW.UTF-8 \
  && echo "######### ssh_config ##########" \
  && echo "Host *" >> /etc/ssh/ssh_config \
  && echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config \
  && echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

## add jenkins user
RUN echo "########## add jenkins user ##########" \
  && mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -G sudo -s /bin/bash ${user} \
  && echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

### install TINI
RUN echo "########## install TINI ##########" \
  && mkdir -p /usr/share/jenkins/ref/init.groovy.d \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

## install jenkins
RUN echo "######### install jenkins ##########" \
  && curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c - \
  && chown -R ${user} ${JENKINS_HOME} /usr/share/jenkins/ref \
  && /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

## docker client
RUN echo "######### docker client #########"         \
  && curl -L -o docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  && tar xf docker.tgz  \
  && mv docker/docker /usr/local/bin/docker \
  && chmod a+x /usr/local/bin/docker \
  && rm -rf docker && rm -f docker.tgz \
  && groupadd docker -g ${DockerID} \
  && touch /var/run/docker.sock \
  && chown root:${DockerID} /var/run/docker.sock \
  && usermod -aG docker jenkins

## apt update && apt-get clean
RUN echo "######### apt update ##########" \
  && apt-get update && apt-get install -y iputils-ping dnsutils netcat --assume-yes  \
  && rm -rf /var/lib/apt/lists/* && apt-get clean

###########################################################################
# USER
###########################################################################
USER ${user}

###########################################################################
# VOLUME
###########################################################################
VOLUME ["${JENKINS_HOME}"]

###########################################################################
# ENTRYPOINT
###########################################################################
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
