FROM python:3.7-alpine

RUN apt-get update && \
	apt-get install -y --no-install-recommends git

RUN pip install --no-cache --upgrade pip && \
	pip install --no-cache notebook poetry requests

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

RUN git clone https://github.com/alan-turing-institute/CleverCSV && \
	cd CleverCSV/python && poetry install
