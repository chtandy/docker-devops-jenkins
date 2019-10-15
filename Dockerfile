## 使用docker-compose build --build-arg DockerID=$(cat /etc/group|grep docker|cut -d':' -f3)
FROM ubuntu:16.04

###########################################################################
# ARG app Version
###########################################################################
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home
ARG TINI_VERSION=v0.16.1
ARG JENKINS_VERSION=2.176.3
ARG JENKINS_SHA=9406c7bee2bc473f77191ace951993f89922f927a0cd7efb658a4247d67b9aa3
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war
ARG KUBECTL=v1.15.3
ARG HELM=v2.11.0
ARG TERRAFORM=0.12.3
ARG DOCKER_VERSION=18.09.0
ARG MAVEN_VERSION=3.6.2
ARG DockerID

###########################################################################
# ENV for Master
###########################################################################
ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

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
## dash > bash
RUN echo "######### dash > bash ##########" \
  && mv /bin/sh /bin/sh.old && ln -s bash /bin/sh

## apt update & apt-get clean
RUN echo "######### apt update ##########" \
  && apt-get update && apt-get install -y default-jre default-jdk sudo vim wget netcat git curl unzip locales jq unzip rsync python python-pip netcat git \
  && rm -rf /var/lib/apt/lists/* && apt-get clean

## add root bashrc
RUN echo "######### add root bashrc ##########" \
  && locale-gen zh_TW.UTF-8 && echo 'export LANGUAGE="zh_TW.UTF-8"' >> /root/.bashrc \
  && echo 'export LANG="zh_TW.UTF-8"' >> /root/.bashrc \
  && echo 'export LC_ALL="zh_TW.UTF-8"' >> /root/.bashrc && update-locale LANG=zh_TW.UTF-8

## ssh_config
RUN echo "######### ssh_config ##########" \
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

## install TINI
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

## install ansible
RUN echo "######### install ansible ##########" \
  && apt-get update && apt-get install software-properties-common -y \
  && apt-add-repository ppa:ansible/ansible \
  && apt-get install ansible -y \
  && rm -rf /var/lib/apt/lists/* && apt-get clean

## install aws cli
RUN echo "######### install aws cli ##########" \
  && apt-get update && apt install awscli groff -y \
  && rm -rf /var/lib/apt/lists/* && apt-get clean

## kubernete clinet
RUN echo "######### kubernete clinet ##########" \
  && wget https://dl.k8s.io/${KUBECTL}/kubernetes-client-linux-amd64.tar.gz \
  && tar -xzvf kubernetes-client-linux-amd64.tar.gz \
  && mv kubernetes/client/bin/kubectl  /usr/bin/ \
  && rm -f kubernetes-client-linux-amd64.tar.gz \
  && rm -rf kubernetes

## Helm
RUN echo "######### Helm ##########" \
  && wget https://storage.googleapis.com/kubernetes-helm/helm-${HELM}-linux-amd64.tar.gz \
  && tar -zxf helm-${HELM}-linux-amd64.tar.gz \
  && mv linux-amd64/helm linux-amd64/tiller /usr/bin/ \
  && rm -rf linux-amd64 \
  && rm -f helm-${HELM}-linux-amd64.tar.gz

## terraform
RUN echo "######### terraform ##########" \
  && wget https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_linux_amd64.zip \
  && unzip terraform_${TERRAFORM}_linux_amd64.zip \
  && mv terraform /usr/bin/ \
  && rm -f terraform_${TERRAFORM}_linux_amd64.zip

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

## install maven
RUN echo "######### install maven  ##########" \
  && wget -c http://ftp.twaren.net/Unix/Web/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && tar -zxvf apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && rm -f apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && mv apache-maven-${MAVEN_VERSION} /usr/local

###########################################################################
# USER
###########################################################################
USER ${user}

###########################################################################
# VOLUME
###########################################################################
VOLUME ${JENKINS_HOME}

###########################################################################
# ENTRYPOINT
###########################################################################
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
