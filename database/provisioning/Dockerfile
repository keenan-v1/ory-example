FROM quay.io/ansible/ansible-runner:latest

COPY src/config/ /runner/config/

ENV PROJECT_NAME=ory
ENV ENVIRONMENT=dev

RUN yum install -y mysql python3-pip && \
    yum clean all && \
    /usr/bin/python3 -m pip install -r /runner/config/pip-requirements.txt && \
    ansible-galaxy collection install -r /runner/config/ansible-requirements.yaml

COPY src/inventory/ /runner/inventory/
COPY src/provisioner.yaml /runner/provisioner.yaml

ENV RUNNER_PLAYBOOK="/runner/provisioner.yaml"
