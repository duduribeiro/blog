---
title: "Reduce your Docker images (an example with Ruby)"
layout: post
date: 2019-02-26 12:00:00 -0300
image: /assets/images/reduce_docker_image.jpg
headerImage: true
tag:
- docker
- ruby
category: blog
author: dudribeiro
description: "A big problem that we have doing a production deploy using Docker is the size of the image. Let's see how can we reduce it."
hidden: false
---
A big problem that we face when deploying Docker into production is the image size. Large images take longer to download, consume much of your cloud network traffic quota, cost more money to be stored on the repository and don’t bring any good value.

In most situations, when we create a Docker image, we add steps and dependencies that sometimes we don’t need in the final image that will run in production.

I will use the following application as an example:
[https://github.com/opensanca/opensanca_jobs](https://github.com/opensanca/opensanca_jobs)

This is the Dockerfile that generates our image

{% highlight docker %}
FROM ruby:2.5.0-alpine
LABEL maintainer="contato@opensanca.com.br"
ARG rails_env="development"
ARG build_without=""
ENV SECRET_KEY_BASE=dumb
RUN apk update \
&& apk add \
openssl \
tar \
build-base \
tzdata \
postgresql-dev \
postgresql-client \
nodejs \
&& wget https://yarnpkg.com/latest.tar.gz \
&& mkdir -p /opt/yarn \
&& tar -xf latest.tar.gz -C /opt/yarn --strip 1 \
&& mkdir -p /var/app
ENV PATH="$PATH:/opt/yarn/bin" BUNDLE_PATH="/gems" BUNDLE_JOBS=2 RAILS_ENV=${rails_env} BUNDLE_WITHOUT=${bundle_without}
COPY . /var/app
WORKDIR /var/app
RUN bundle install && yarn && bundle exec rake assets:precompile
CMD rails s -b 0.0.0.0
{% endhighlight %}

And the command used to build it:

{% highlight shell %}
docker build -t openjobs:latest --build-arg build_without="development test" --build-arg rails_env="production" .
{% endhighlight %}

![first_image](https://miro.medium.com/proxy/1*RujRaeSrBXgUJHVNWjQMIg.png)

This build generated an image with almost 1GB!!! 😱.

This image has some unnecessary stuff, like node but yarn (we only need them to precompile the assets but not to execute the application itself).

<div class="breaker"></div>

## Multi-Stage build

Docker introduced the concept of [Multi-Stage build](https://docs.docker.com/develop/develop-images/multistage-build/) in version 17.05. This build technic allows us to split our Dockerfile into several statements `FROM`. Each statement can use a different base image and you can copy artifacts from one stage to another, without bringing stuff that you don’t want in the final image. Our final image will only contain the build wrote in the last stage.

Now we have a Dockerfile divided into two stages. Pre-build and Final-Build.


{% highlight docker %}
# pre-build stage
FROM ruby:2.5.0-alpine AS pre-builder
ARG rails_env="development"
ARG build_without=""
ENV SECRET_KEY_BASE=dumb
RUN apk add --update --no-cache \
openssl \
tar \
build-base \
tzdata \
postgresql-dev \
postgresql-client \
nodejs \
&& wget https://yarnpkg.com/latest.tar.gz \
&& mkdir -p /opt/yarn \
&& tar -xf latest.tar.gz -C /opt/yarn --strip 1 \
&& mkdir -p /var/app
ENV PATH="$PATH:/opt/yarn/bin" BUNDLE_PATH="/gems" BUNDLE_JOBS=2 RAILS_ENV=${rails_env} BUNDLE_WITHOUT=${bundle_without}
COPY . /var/app
WORKDIR /var/app
RUN bundle install && yarn && bundle exec rake assets:precompile
# final build stage
FROM ruby:2.5.0-alpine
LABEL maintainer="contato@opensanca.com.br"
RUN apk add --update --no-cache \
openssl \
tzdata \
postgresql-dev \
postgresql-client
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /var/app /var/app
ENV RAILS_LOG_TO_STDOUT true
WORKDIR /var/app
EXPOSE 3000
CMD rails s -b 0.0.0.0
{% endhighlight %}

In the pre-build stage we install node and yarn, all dependencies and precompile the assets. In the final stage, we use an alpine image (which is very small) with ruby, we install only the necessary dependencies to run the application and we then copy the libraries and assets generated in the build-stage with the following command:

{% highlight docker %}
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /var/app /var/app
{% endhighlight %}

Doing the build with this Dockerfile, we have now a 562MB image.

![image_2](https://miro.medium.com/proxy/1*G7h0VTW1JD9tKZ7DHnqM9w.png)

We have already reduced almost half the image size, but can we reduce it further?? 🤔

Yes. We can do some actions to reduce more this image.

<div class="breaker"></div>

## Removing unnecessary files

We can delete files that are not necessary from the image, like cache and temporary files used by the installed libraries. We can add a .dockerignore file, telling the build what not to send to the image.

{% highlight docker %}
# build stage
FROM ruby:2.5.0-alpine AS pre-builder
ARG rails_env="development"
ARG build_without=""
ENV SECRET_KEY_BASE=dumb
RUN apk add --update --no-cache \
openssl \
tar \
build-base \
tzdata \
postgresql-dev \
postgresql-client \
nodejs \
&& wget https://yarnpkg.com/latest.tar.gz \
&& mkdir -p /opt/yarn \
&& tar -xf latest.tar.gz -C /opt/yarn --strip 1 \
&& mkdir -p /var/app
ENV PATH="$PATH:/opt/yarn/bin" BUNDLE_PATH="/gems" BUNDLE_JOBS=4 RAILS_ENV=${rails_env} BUNDLE_WITHOUT=${bundle_without}
COPY . /var/app
WORKDIR /var/app
RUN bundle install && yarn && bundle exec rake assets:precompile \
&& rm -rf /gems/cache/*.gem \
&& find /gems/gems/ -name "*.c" -delete \
&& find /gems/gems/ -name "*.o" -delete
# final stage
FROM ruby:2.5.0-alpine
LABEL maintainer="contato@opensanca.com.br"
RUN apk add --update --no-cache \
openssl \
tzdata \
postgresql-dev \
postgresql-client
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /var/app /var/app
ENV RAILS_LOG_TO_STDOUT true
WORKDIR /var/app
EXPOSE 3000
CMD rails s -b 0.0.0.0
{% endhighlight %}

In this new Dockerfile, we added this part that removes caches and temporary C files used to build the libraries:


{% highlight shell %}
&& rm -rf /gems/cache/*.gem \
&& find /gems/gems/ -name "*.c" -delete \
&& find /gems/gems/ -name "*.o" -delete
{% endhighlight %}

We also included our .dockerignore to tell the build process the files that we don’t want in the image:

{% highlight shell %}
.env*
.git
.gitignore
.codeclimate.yml
.dockerignore
.gitlab-ci.yml
.hound.yml
.travis.yml
LICENSE.md
README.md
docker-compose.*
Dockerfile
log/*
node_modules/*
public/assets/*
storage/*
public/packs/*
public/packs-test/*
tmp/*
{% endhighlight %}

With these two steps, now our image has 272MB.

![image_3](https://miro.medium.com/proxy/1*eZJTGWQQHJTdqKyvfyvFjw.png)

We can reduce it even more. For production, we don’t need test folders, npm raw folder (they are already included on the asset pipeline), no precompiled assets and caches.

To remove this files, we can include a strategy of passing an argument to build (we will call it: `to_remove`)


{% highlight docker %}
...
ARG to_remove
...
RUN bundle install && yarn && bundle exec rake assets:precompile  \
&& rm -rf /usr/local/bundle/cache/*.gem \
 && find /usr/local/bundle/gems/ -name "*.c" -delete \
 && find /usr/local/bundle/gems/ -name "*.o" -delete \
 && rm -rf $to_remove   # Here we remove all files that we passed as an argument to the build.
...
{% endhighlight %}

In this argument, we will pass all the files that we don’t want in production:

{% highlight shell %}
docker build -t openjobs:reduced --build-arg build_without="development test" --build-arg rails_env="production" . --build-arg to_remove="spec node_modules app/assets vendor/assets lib/assets tmp/cache"
{% endhighlight %}

Notice the `— build-arg to_remove=”spec node_modules app/assets vendor/assets lib/assets tmp/cache”`. These are the folders that we want to remove from our build process. We don’t need them to run in production.

Removing these files, now we have an image with 164MB, almost 6 times smaller than the original one.

![image_4](https://miro.medium.com/proxy/1*dOtqxq0ssllOzV6v_iVjmw.png)

![reduced](https://miro.medium.com/proxy/1*Lt65Wab0jeBX6OSkgUFcAQ.gif)

If you still don’t believe me and want to see it, this is the PR that generates this reduction: [https://github.com/opensanca/opensanca_jobs/pull/164](https://github.com/opensanca/opensanca_jobs/pull/164)

![thats_all](https://miro.medium.com/proxy/1*eqsPaN0ft0DkhHczXD5vJA.png)

Cheers 🍻

<small>Thanks to Felipe Pelizaro Gentil</small>
