FROM ubuntu:16.04
RUN mv /bin/sh /bin/sh.old && ln -s bash /bin/sh
RUN apt-get update && apt-get upgrade -y && apt-get install default-jre default-jdk sudo vim netcat git curl unzip locales unzip -y && \
    rm -rf /var/lib/apt/lists/* && apt-get clean

RUN locale-gen zh_TW.UTF-8 && echo 'export LANGUAGE="zh_TW.UTF-8"' >> /root/.bashrc && \
    echo 'export LANG="zh_TW.UTF-8"' >> /root/.bashrc && \
    echo 'export LC_ALL="zh_TW.UTF-8"' >> /root/.bashrc && update-locale LANG=zh_TW.UTF-8

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -G sudo -m -s /bin/bash ${user}

# Jenkins cam sudo
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.16.1
COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.176.1}

# jenkins.war checksum, download will be validated using it
#ARG JENKINS_SHA=5bb075b81a3929ceada4e960049e37df5f15a1e3cfc9dc24d749858e70b48919

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war 

#RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
#  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

#ADD http://updates.jenkins-ci.org/download/war/2.164.3/jenkins.war /usr/share/jenkins/jenkins.war

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# set /etc/ssh/ssh_config
RUN echo "Host *" >> /etc/ssh/ssh_config && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

RUN set -eux && apt-get update && apt-get install sudo python wget curl zlib1g-dev rsync python-pip vim -y && \
    rm -rf /var/lib/apt/lists/* && apt-get clean

##  ansible
RUN apt update && apt-get install software-properties-common -y && \
    apt-add-repository ppa:ansible/ansible && \
    apt-get install ansible -y && rm -rf /var/lib/apt/lists/* && apt-get clean

##  nodejs
RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - && \
    apt-get install -y nodejs && rm -rf /var/lib/apt/lists/* && apt-get clean
    
## kubectl client
RUN wget https://dl.k8s.io/v1.10.12/kubernetes-client-linux-amd64.tar.gz && \
    tar -xzvf kubernetes-client-linux-amd64.tar.gz && \
    mv kubernetes/client/bin/kubectl  /usr/bin/ && \
    rm -f kubernetes-client-linux-amd64.tar.gz && \
    rm -rf kubernetes
    
## Helm
RUN wget https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz && \
    tar -zxf helm-v2.11.0-linux-amd64.tar.gz && \
    mv linux-amd64/helm linux-amd64/tiller /usr/bin/ && \
    rm -rf linux-amd64 && \
    rm -f helm-v2.11.0-linux-amd64.tar.gz

## terraform
RUN wget https://releases.hashicorp.com/terraform/0.12.3/terraform_0.12.3_linux_amd64.zip && \
    unzip terraform_0.12.3_linux_amd64.zip && \
    mv terraform /usr/bin/ && \
    rm -f terraform_0.12.3_linux_amd64.zip

## aws cli
RUN apt update && python -m pip install --upgrade pip && pip install awscli && rm -rf /var/lib/apt/lists/* && apt-get clean

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

# Use plugins txt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
