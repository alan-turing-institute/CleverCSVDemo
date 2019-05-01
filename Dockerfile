FROM python:3.7-slim

RUN apt-get update && \
	apt-get install -y --no-install-recommends git build-essential

RUN pip install --no-cache --upgrade pip && \
	pip install --no-cache notebook clevercsv requests

ARG NB_USER
ARG NB_UID
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
	--gecos "Default user" \
	--uid ${NB_UID} \
	${NB_USER}

COPY . ${HOME}
USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}

WORKDIR ${HOME}
