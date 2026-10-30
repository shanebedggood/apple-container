FROM ubuntu:24.04
ARG K8S_VERSION=v1.37.0

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl wget vim nano jq less \
      openssh-client iputils-ping dnsutils netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /usr/local/bin/kubectl \
      https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/arm64/kubectl \
 && curl -fsSLo /usr/local/bin/yq \
      https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64 \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/yq

RUN printf '%s\n' \
      'source /usr/share/bash-completion/bash_completion' \
      'source <(kubectl completion bash)' \
      'alias k=kubectl' \
      'complete -o default -F __start_kubectl k' \
      'export KUBECONFIG=/root/lab/kubeconfig' >> /root/.bashrc

WORKDIR /root/lab
