ARG BUILD_FROM
FROM $BUILD_FROM

ENV LANG C.UTF-8

# Install requirements for add-on
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		groff \
		less \
		unzip && \
	rm -rf /var/lib/apt/lists/*

# Install aws cli
RUN mkdir aws && \
	cd aws && \
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
	unzip -q awscliv2.zip && \
	./aws/install && \
	cd .. && \
	rm -rf aws

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
