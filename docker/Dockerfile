FROM debian:sid
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install vim locales locales-all git ruby ruby-dev build-essential  
ENV LC_ALL en_GB.UTF-8
ENV LANG en_GB.UTF-8
ENV LANGUAGE en_GB.UTF-8

ARG geckodriver_ver=0.33.0
#ARG build_rev=0


RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends --no-install-suggests \
            ca-certificates curl \
 && update-ca-certificates \ 
 && apt-get install -y --no-install-recommends --no-install-suggests \
            firefox sqlite3 ruby-sqlite3
 
RUN curl  -f -L -o /tmp/geckodriver.tar.gz https://github.com/mozilla/geckodriver/releases/download/v${geckodriver_ver}/geckodriver-v${geckodriver_ver}-linux-aarch64.tar.gz \
 && tar -xzf /tmp/geckodriver.tar.gz -C /tmp/ \
 && chmod +x /tmp/geckodriver \
 && mv /tmp/geckodriver /usr/local/bin/ \
 && rm -rf /var/lib/apt/lists/* \
           /tmp/*


ENV MOZ_HEADLESS=1
ENV DISPLAY=:0.0


ARG DEBIAN_FRONTEND=noninteractive
ARG CUSER=james
ARG CGROUP=james
ARG UID=1001
ARG GID=1001
RUN addgroup --gid $GID $CGROUP
RUN useradd -mN -u $UID -g $GID $CUSER
RUN gem install rake
#RUN gem sources -r https://rubygems.org/
#RUN gem sources -a http://rubygems.org/
RUN gem install rubyXL 
RUN gem install debug
RUN gem install ruby-debug-ide
RUN gem install selenium-webdriver
RUN gem install netrc
USER $CUSER
WORKDIR /home/$CUSER
COPY scripts/* /home/$CUSER/ 
RUN touch /home/$CUSER/.netrc
ENTRYPOINT ["geckodriver"]
CMD ["--binary=/usr/bin/firefox", "--log=debug"]
