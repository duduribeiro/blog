---
title: "Using Devcontainers to set up your development environment"
layout: post
date: 2023-09-28 12:00:00 -0300
image: /assets/images/devcontainerslogo.png
headerImage: true
tag:
- docker
- devcontainers
- development environment
- developer experience
category: blog
author: dudribeiro
description: "How can you use DevContainers to simplify the development environment setup."
hidden: false
---

One common problem in software development is setting up the project's development environment. Have you ever joined a project, opened the README.md, and found a README HELL, filled with endless instructions on how to configure the project? And halfway through the instructions, you encounter an error while running a command because you're not on the same operating system version as the person who wrote the README, or because the documentation is outdated.

Quoting [Vladimir Dementyev](https://twitter.com/palkan_tula){:target="_blank"} in his amazing talk [Terraforming Legacy Rails applications:](https://speakerdeck.com/palkan/railsconf-2019-terraforming-legacy-rails-applications){:target="_blank"}
> Developers should be able to run project with the least possible effort

for example, cloning the code and running a few scripts for server setup and start.

GitHub published a [blog post](https://github.blog/2015-06-30-scripts-to-rule-them-all/){:target="_blank"} in 2015 where they demonstrated how they did this at the time. They state:
> Having a bootstraping experience for projects reduces friction and encourages contribution.

`Reduces friction`: This is very interesting when we think about onboarding a new person to the project. Do you remember the past times when a newcomer would take days to get the project up and running on their computer?

And in this post, GitHub shows how they solved this in 2015: A set of scripts, with a standard naming convention across all projects, that handle dependency installation and updates, project setup, test execution, and environment configuration. They refer to this set of scripts as 'Scripts to Rule Them All.'

| ![oneringtorulethemall](/assets/images/oneringtorulethemall.jpg) | 
|:--:| 
| *https://www.youtube.com/watch?v=HgOha2D5kt8&themeRefresh=1* |

This model greatly helped new hires at the company configure and start projects within half a day. In [another post](https://github.blog/2021-08-11-githubs-engineering-team-moved-codespaces/){:target="_blank"}, they mention that `in the vast majority of cases, everything worked without issues` and that `when something didn't work, there was a Slack channel called #friction where others debugged and helped resolve system issues`. Event with nvironment setup scripts, issues persisted because the company scripts were based on macOS, while individuals might use different operating systems like Linux or even a more recent macOS version not yet supported by the scripts. These errors continued to create friction when starting a development environment for the project.


How can we further reduce friction? Enter `DevContainers`.

## What are DevContainers?

`Development Containers` (or `DevContainers`) is an [open specification](https://containers.dev/){:target="_blank"} that allows containers to be used as a complete development environment, enabling us to run our applications, dependencies like databases and messaging services, and other tools necessary for the development lifecycle. DevContainers can be run locally or in a remote environment (including services like [GitHub Codespaces](https://github.com/features/codespaces){:target="_blank"} and [GitPod](https://gitpod.io/){:target="_blank"}).

In this text, I won't enter into the basics of containers/docker. If you'd like to learn and know more, please visit [https://www.docker.com/](https://www.docker.com/){:target="_blank"} and [https://cloud.google.com/learn/what-are-containers](https://cloud.google.com/learn/what-are-containers){:target="_blank"}.

The `DevContainers` specification states that your project have a folder called `.devcontainer` with a `devcontainer.json` file. To read the complete specification, visit [this link](https://containers.dev/implementors/json_reference/){:target="_blank"}. In summary, the file contains the image (or Dockerfile) to be used, the container's forwarded ports, specific product customizations (e.g., installing extensions by default in VSCode), and more.

One of the inclusions in the specification is the `DevContainer Features`, which are independent and shareable units containing installation or configuration code for the container. These features are installed on top of the image used in the DevContainer. The idea behind features is to easily add more tools and libraries to the DevContainer. The following example demonstrates how to install the `GitHub CLI`, for instance:

```json
// .devcontainer/devcontainer.json
{
  "name": "MyApp DevContainer",
  //...
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {
        "version": "latest"
    }  
  }
}
```

A list of existing `Features` can be found [here](https://containers.dev/features){:target="_blank"}.

## Advantages and disadvantages of using DevContainers

One of the evident advantages we observe in using DevContainers is reducing friction in project setup. Having this reproducible development environment ensures that everyone on the team is using the same environment, making project setup easier. This will make new team members onboarding much faster and easier. It's common that we don't see problem with slow onboarding because we assume it will only happen once, which is not always true (maybe you got a brandly new computer?). Another advantage is that no matter which operating system you are using, the development environment will work, and you don't need separate instructions in the docs (no more "if you are on Linux, do this" in your README).

But of course, this approach may have some disadvantages. Possible speed reduction (especially on macOS). We know that Docker on macOS runs on top of a virtual machine, which impacts performance a bit, as discussed in [this article](https://www.cncf.io/blog/2023/02/02/docker-on-macos-is-slow-and-how-to-fix-it/){:target="_blank"}. There are some alternatives that promise to improve Docker's speed on macOS, such as [Colima](https://github.com/abiosoft/colima){:target="_blank"} and [OrbStack](https://orbstack.dev). My friend [Felipe Vaz](https://twitter.com/fvztdk){:target="_blank"} is using Colima and said it is good. I am currently testing OrbStack based on a recommendation from [Rob Zolkos](https://twitter.com/robzolkos){:target="_blank"}.
![rob zolkos Twitter Post](/assets/images/robzolkos-orbstack-post.png)

Also, stuff that works well, such as integration tests with browsers (e.g., using Selenium), can be a trickier to set up and get working perfectly.

As with everything in software development, it's a tradeoff, and you should consider the pros and cons to see if it's worth it in your case. For me, the advantages outweigh the disadvantages, and it's worth using. It may not be the case for you.


## Production Containers vs. DevContainers

> If I already have containers and a Dockerfile for my production app running, why not use them instead of a separate container for development?

When we talk about reproducible environments with DevContainers, this question often arises, and it's a good question. One of the [12factors](https://12factor.net/dev-prod-parity){:target="_blank"} suggests having parity between development and production, which leads us to try using the same production container image in development. However, note that this advice emphasizes making environments `as similar as POSSIBLE`, not `EXACTLY THE SAME`."

> Keep development, staging, and production as similar AS POSSIBLE

This is a subtle distinction but makes a difference when we deploy our development containers. One of the points that the "Dev/prod parity" factor addresses is:

> [Backing services](https://12factor.net/backing-services){:target="_blank"}, such as the app’s database, queueing system, or cache, is one area where dev/prod parity is important. Many languages offer libraries which simplify access to the backing service, including *adapters* to different types of services....

> Developers sometimes find great appeal in using a lightweight backing service in their local environments, while a more serious and robust backing service will be used in production. For example, using SQLite locally and PostgreSQL in production; or local process memory for caching in development and Memcached in production.


> **The twelve-factor developer resists the urge to use different backing services between development and production**

And that's the idea that `Dev/prod parity` brings. Try to make your development environment as similar as POSSIBLE to production. If you use PostgreSQL in production, don't use SQLite as your development database because there are differences between them that can cause compatibility issues in your application, and you'll only notice them in production. Note that the primary focus of `Dev/prod parity` is on using different backing services, not telling you to use the SAME IMAGE used in production for development.

Production containers have different requirements from development containers!

When we think about deploying our application in containers, we have concern such as:
* Attempting to minimize the size of the final container image as much as possible
* Having as few dependencies as possible
* Exposing the minimum number of open ports
* Reducing the application's memory consumption

Furthermore, the images we use as a base for our production containers are based on very small and highly suitable images for a production environment (such as debian-slim or alpine), but they are not as suitable for a development environment. (You'll want to run `fzf` in your DevContainer, but it doesn't make sense to have it in your production image, for example.)

In the development environment, we want a complete system (such as ubuntu or debian) with various utilities and auxiliary tools to assist the daily work of project contributors (e.g., installing `fzf` for searching, `vim` for quick file editing, a more comprehensive shell with multiple auto-completions) and  we can leave more ports open to facilitate application debugging.

On the [Overview page of DevContainers](https://containers.dev/overview#Development-vs-production){:target="_blank"}, in the `Development vs production` section, you can find the following passage:
> While deployment and development containers may resemble one another, you may not want to include tools in a deployment image that you use during development."

| ![different images for different stages of your dev lifecycle](/assets/images/dev-container-stages.png) | 
|:--:| 
| *https://containers.dev/overview#Development-vs-production* |

*In the image, we can see that a DevContainer for a development environment (inner loop) can include various things that are not necessary for production. In fact, we can consider that in the Outer loop (CI), this DevContainer can be used with even fewer items included.*

Considering these points, it might make sense to have two container definitions, one for production and one for development. To achieve this, I like to have two `Dockerfile` definitions. One at the root of the project to define the production image and another inside `.devcontainer` for the development environment using DevContainers.

So, the project structure looks like this:

```
% tree -a | grep Dockerfile -C 1
├── .devcontainer
│   ├── Dockerfile
--
├── Dockerfile
```

## Practical Example: A Ruby on Rails Application

For this practical example, I'll be using a Ruby on Rails application. It's also necessary to have prior knowledge of containers, Docker, and Docker Compose.

[This GitHub repository](https://github.com/duduribeiro/devcontainer-rails-demo){:target="_blank"} contains the source code used in this post and it's broken down into [tags](https://github.com/duduribeiro/devcontainer-rails-demo/tags){:target="_blank"} containing the progress. The tag [0-initial](https://github.com/duduribeiro/devcontainer-rails-demo/releases/tag/0-initial){:target="_blank"} contains the base application used from here on.

This application was generated using Rails 7.1. Rails 7.1 [introduced a feature](https://edgeguides.rubyonrails.org/7_1_release_notes.html#generate-dockerfiles-for-new-rails-applications){:target="_blank"} that generates a `Dockerfile` by default when you create a new application. However, this `Dockerfile` is optimized for production, as stated in the release note:

> It's important to note that these files are not meant for development purposes.

As we've seen earlier, the purpose of a `Dockerfile` for the development environment is different from one for production. So, let's create our `Dockerfile` that will be used in our `DevContainer`.


### The Dockerfile for the DevContainer.

Let's begin by creating our Dockerfile that will be used in our DevContainer. Inside the .devcontainer folder, I will create my Dockerfile:

```dockerfile
# .devcontainer/Dockerfile

ARG DEBIAN_FRONTEND=noninteractive
ARG VARIANT=bullseye

FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT}

RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    build-essential gnupg2 tar git zsh libssl-dev zlib1g-dev libyaml-dev curl libreadline-dev \
    postgresql-client libpq-dev \
    imagemagick libjpeg-dev libpng-dev libtiff-dev libwebp-dev libvips \
    tzdata \
    tmux \
    vim

# Install rbenv and ruby
USER vscode

ARG RUBY_VERSION="3.2.2"
RUN git clone https://github.com/rbenv/rbenv.git /home/vscode/.rbenv  \
    && echo '[ -f "/home/vscode/.rbenv/bin/rbenv" ] && eval "$(rbenv init - bash)" # rbenv' >> /home/vscode/.zshrc \
    && echo '[ -f "/home/vscode/.rbenv/bin/rbenv" ] && eval "$(rbenv init - bash)" # rbenv' >> /home/vscode/.bashrc \
    && echo 'export PATH="/home/vscode/.rbenv/bin:$PATH"' >> /home/vscode/.zshrc \
    && echo 'export PATH="/home/vscode/.rbenv/bin:$PATH"' >> /home/vscode/.bashrc \
    && mkdir -p /home/vscode/.rbenv/versions \
    && mkdir -p /home/vscode/.rbenv/plugins \
    && git clone https://github.com/rbenv/ruby-build.git /home/vscode/.rbenv/plugins/ruby-build

ENV PATH "/home/vscode/.rbenv/bin/:HOME/.rbenv/shims/:$PATH"

RUN rbenv install $RUBY_VERSION && \
    rbenv global $RUBY_VERSION && \
    rbenv versions

COPY .devcontainer/welcome.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt
```

I won't go into much detail on how it works but will instead explain the reasons behind some decisions made. To understand more about how a `Dockerfile` works, the [official documentation](https://docs.docker.com/engine/reference/builder/){:target="_blank"} is the best reference.

#### The base image used.


In the first instructions, we define which base image we will use:

```dockerfile
# .devcontainer/Dockerfile

ARG VARIANT=bullseye

FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT}
```

The [FROM instruction](https://docs.docker.com/engine/reference/builder/#from){:target="_blank"} specifies to Docker which image to use as the base for ours. And here, we've already made the first decision. Which one will we use?

We can use any base image for ours (including using debian directly). So, could we use the ruby:3 image directly? Yes.

```dockerfile
FROM ruby:3
```
is a valid `Dockerfile` to use as a DevContainer, and in fact, some open-source projects (e.g., [Forem](https://github.com/forem/forem/blob/main/Containerfile.base){:target="_blank"}) use it. However, Microsoft's `mcr.microsoft.com/vscode/devcontainers/` images are specifically prepared for use in DevContainers, adding various development tools. [Here](https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/common-debian.sh){:target="_blank"}, for example, you can see one of the scripts executed in the `mcr.microsoft.com/vscode/devcontainers/` images.

For this reason, I prefer to use the `mcr.microsoft.com/vscode/devcontainers` images. It's just a personal preference and doesn't mean that using other images as DevContainers is wrong. You can use any Docker image as a base.

#### And why use `mcr.microsoft.com/vscode/devcontainers/base` instead of `mcr.microsoft.com/vscode/devcontainers/ruby`?

This is another decision made based on preference. I recently used `mcr.microsoft.com/vscode/devcontainers/base` in my projects and manually installed Ruby due to a small "issue" (which might be specific to me 😀) I found in `mcr.microsoft.com/vscode/devcontainers/ruby`. The `mcr.microsoft.com/vscode/devcontainers/ruby` image installs two version managers: [rbenv](https://github.com/rbenv/rbenv){:target="_blank"} and [rvm](https://rvm.io/){:target="_blank"}, which can cause some issues. One issue I noticed is when your project has a `.ruby-version` file (as in [our example](https://github.com/duduribeiro/devcontainer-rails-demo/blob/main/.ruby-version){:target="_blank"}, generated by Rails). The `.ruby-version` file tells the version managers which Ruby version to install. However, what I noticed is that when you don't have this file, the `mcr.microsoft.com/vscode/devcontainers/ruby` image installs Ruby using `rbenv`, and when you do have this file in the project, it installs Ruby using `rvm`.

And what's the problem with installing it using `rvm`? Technically, there's no issue, but you may run into some cases like I did. I was using the VSCode extension for `ruby-lsp`, and the extension's version manager detection was set to `auto` (https://github.com/Shopify/vscode-ruby-lsp#ruby-version-managers){:target="_blank"}. The extension tried to detect the installed version using `rbenv`, but my DevContainer was using `rvm`. Check out these two issues, [https://github.com/devcontainers/images/issues/572](https://github.com/devcontainers/images/issues/572){:target="_blank"} and [https://github.com/microsoft/vscode-dev-containers/issues/704](https://github.com/microsoft/vscode-dev-containers/issues/704){:target="_blank"}, for more details.

Also, it's not necessary to have a version manager in a container. When you need to use a different Ruby version, you can install it directly in the container, avoiding the installation of multiple versions together.

Because of this difference, I preferred to use the `base` image and manually install `Ruby` with the following instructions:
```dockerfile
# Install rbenv and ruby
USER vscode

ARG RUBY_VERSION="3.2.2"
RUN git clone https://github.com/rbenv/rbenv.git /home/vscode/.rbenv  \
    && echo '[ -f "/home/vscode/.rbenv/bin/rbenv" ] && eval "$(rbenv init - bash)" # rbenv' >> /home/vscode/.zshrc \
    && echo '[ -f "/home/vscode/.rbenv/bin/rbenv" ] && eval "$(rbenv init - bash)" # rbenv' >> /home/vscode/.bashrc \
    && echo 'export PATH="/home/vscode/.rbenv/bin:$PATH"' >> /home/vscode/.zshrc \
    && echo 'export PATH="/home/vscode/.rbenv/bin:$PATH"' >> /home/vscode/.bashrc \
    && mkdir -p /home/vscode/.rbenv/versions \
    && mkdir -p /home/vscode/.rbenv/plugins \
    && git clone https://github.com/rbenv/ruby-build.git /home/vscode/.rbenv/plugins/ruby-build

ENV PATH "/home/vscode/.rbenv/bin/:/home/vscode/.rbenv/.rbenv/shims/:$PATH"

RUN rbenv install $RUBY_VERSION && \
    rbenv global $RUBY_VERSION && \
    rbenv versions
```

The last instruction in the `Dockerfile` simply copies the file `.devcontainer/welcome.txt` to the location `/usr/local/etc/vscode-dev-containers/first-run-notice.txt` in the container. This file sets up a message that will be displayed when we open the terminal in VSCode.

![vscode welcome message](/assets/images/vscode-welmcome-message.png)

Let's create our `.devcontainer/welcome.txt` then.

```
👋 Welcome to "DemoApp"!

🛠️  Your environment is fully setup with all the required software.
```

Our Dockerfile is ready. We can build the image to see if everything is okay by running `docker build` in the root of the project:

```shell
% docker build -f .devcontainer/Dockerfile .

[+] Building 0.1s (10/10) FINISHED                                                                                                                                                                    docker:orbstack
 => [internal] load build definition from Dockerfile                                                                                                                                                             0.0s
 => => transferring dockerfile: 1.47kB                                                                                                                                                                           0.0s
 => [internal] load .dockerignore                                                                                                                                                                                0.0s
 => => transferring context: 766B                                                                                                                                                                                0.0s
 => [internal] load metadata for mcr.microsoft.com/vscode/devcontainers/base:bullseye                                                                                                                            0.0s
 => [internal] load build context                                                                                                                                                                                0.0s
 => => transferring context: 265B                                                                                                                                                                                0.0s
 => [1/5] FROM mcr.microsoft.com/vscode/devcontainers/base:bullseye                                                                                                                                              0.0s
 => CACHED [2/5] RUN apt-get update &&     apt-get -y install --no-install-recommends     build-essential gnupg2 tar git zsh libssl-dev zlib1g-dev libyaml-dev curl libreadline-dev     postgresql-client libpq  0.0s
 => CACHED [3/5] RUN git clone https://github.com/rbenv/rbenv.git /home/vscode/.rbenv      && echo '[ -f "/home/vscode/.rbenv/bin/rbenv" ] && eval "$(rbenv init - bash)" # rbenv' >> /home/vscode/.zshrc     &  0.0s
 => CACHED [4/5] RUN rbenv install 3.2.2 &&     rbenv global 3.2.2 &&     rbenv versions                                                                                                                         0.0s
 => [5/5] COPY .devcontainer/welcome.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt                                                                                                               0.0s
 => exporting to image                                                                                                                                                                                           0.0s
 => => exporting layers                                                                                                                                                                                          0.0s
 => => writing image sha256:1ca67988b183ade50ca4f4a76e24d7cf76de0f7e7a12b0ea1d516fc25a67b501
 ```

The output indicates that our image is okay, and now we can proceed with building our `devcontainer.json`.

The source code up to this point: [Link](https://github.com/duduribeiro/devcontainer-rails-demo/releases/tag/1-dockerfile){:target="_blank"}

### Specifying our development container in the `devcontainer.json`.

As we saw at the beginning, the `.devcontainer/devcontainer.json` file contains the necessary configurations for our DevContainer so that [tools and services that support the devcontainer specification](https://containers.dev/supporting){:target="_blank"} can start up and connect to the DevContainer. With this specification, we will be able to make VSCode set up our environment when it detects the project.

```json
// .devcontainer/devcontainer.json

// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: https://github.com/devcontainers/templates/tree/main/src/ruby-rails-postgres
{
    "name": "DemoApp DevContainer",
    "build": {
        "dockerfile": "Dockerfile",
        "context": ".."
    },
    "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
    "remoteEnv": {
        "GIT_EDITOR": "code --wait"
    }
}
```

The complete specification and documentation for `devcontainer.json` can be found [here](https://containers.dev/implementors/json_reference/){:target="_blank"}, but to summarize, here we define that our DevContainer is named "DemoApp DevContainer" and specify that it will use our Dockerfile created in the previous step. If we open our project with VSCode, we will receive a message indicating that it has detected a DevContainer specification and suggests opening the project inside the container:

![vscode reopen in container option](/assets/images/vscode-reopen-in-container.png)

In this popup, we can click on `Reopen in container`, or in the command palette, you can search for the command directly.

![vscode reopen in container command](/assets/images/vscode-command-reopen-in-container.png)

Demo time!

<video width="600" height="400" controls src="/assets/videos/demotime.webm"></video>

In the demo, we see that when we use the "Reopen in container" option, VSCode opens the project inside the container. Extensions run within the container and not on the local operating system. This allows extensions (e.g., LSP) to run their clients within the container itself. [Read here](https://code.visualstudio.com/docs/devcontainers/containers){:target="_blank"} for more information on the DevContainers architecture. The image below illustrates this:

| ![DevContainers Architecture](/assets/images/architecture-containers.png) |
|:--:| 
| *https://code.visualstudio.com/docs/devcontainers/containers* |


We also see that the tools are already installed in our container. We have `ruby` and even `vim` inside the container. And this is the difference from a production container. Here, we have everything we need for a complete development environment.

Source code up to this point: [Link](https://github.com/duduribeiro/devcontainer-rails-demo/releases/tag/2-basic-devcontainer){:target="_blank"}

### Project Dependencies

Inside our DevContainer, if we try to run the `bin/setup` command of our project (which installs dependencies and sets up the database), we will encounter some errors.

The first error we receive:

```shell
bin/setup:8:in `system': No such file or directory - bun (Errno::ENOENT)
        from bin/setup:8:in `system!'
        from bin/setup:21:in `block in <main>'
        from /home/vscode/.rbenv/versions/3.2.2/lib/ruby/3.2.0/fileutils.rb:244:in `chdir'
        from /home/vscode/.rbenv/versions/3.2.2/lib/ruby/3.2.0/fileutils.rb:244:in `cd'
        from bin/setup:11:in `<main>'
```

![devcontainer setup error](/assets/images/devcontainer-setup-error.png)

Our Rails project was generated using [bun](bun.sh) as the JavaScript package manager and bundler. (Rails now supports Bun thanks to the great work of [Jason Meller](https://twitter.com/jmeller){:target="_blank"} in this [PR](https://github.com/rails/rails/pull/49241){:target="_blank"}). However, our DevContainer does not have `bun` installed. We can fix this in two ways:

* Modify our Dockerfile to install `bun`
* Use the [DevContainer Features](https://containers.dev/features) `ghcr.io/shyim/devcontainers-features/bun`

We will proceed with the second option. It's a simple option for installing tools when they are available. We modify our `devcontainer.json` to include the following instruction:

```json
    "features": {
        "ghcr.io/shyim/devcontainers-features/bun:0": {}
    },
```

Our `devcontainer.json` looks like this now:
```json
// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: https://github.com/devcontainers/templates/tree/main/src/ruby-rails-postgres
{
    "name": "DemoApp DevContainer",
    "build": {
        "dockerfile": "Dockerfile",
        "context": ".."
    },
    "features": {
        "ghcr.io/shyim/devcontainers-features/bun:0": {}
    },
    "workspaceFolder": "/workspace",
    "remoteEnv": {
        "GIT_EDITOR": "code --wait"
    }
}
```

VSCode notices that we have modified the specification of our DevContainer and suggests rebuilding it:
![rebuild container option](/assets/images/rebuild-container-option.png)

After finishing the DevContainer build, if we run `bun -v`, we will see that it is now installed:

```shell
vscode ➜ /workspace (main) $ bun -v
1.0.3
```

Running `bin/setup` again, and now the failure occurs when preparing the database.

```shell
PG::ConnectionBad: could not connect to server: No such file or directory
        Is the server running locally and accepting
        connections on Unix domain socket "/var/run/postgresql/.s.PGSQL.5432"?
```

![postgres error on devcontainer](/assets/images/devcontainer-pg-error.png)

Our project is configured to use PostgreSQL, and this error occurs because we don't have it running in our container. Let's run our database using [Docker Compose](https://containers.dev/guide/dockerfile#docker-compose){:target="_blank"}, which allows us to define a development environment with multiple containers. Instead of adding PostgreSQL to our Dockerfile, we'll add an additional container to our environment via Compose.

Let's create our `.devcontainer/docker-compose.yml` file. Refer to the [documentation](https://docs.docker.com/compose/) for more information on Docker Compose specification.

```yaml
version: '3'

services:
  app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile

    volumes:
      - ..:/workspace:cached
      - $HOME/.ssh/:/home/vscode/.ssh/
    depends_on:
      - postgres
    environment:
      - DATABASE_URL=postgres://postgres:postgres@postgres:5432

    # Overrides default command so things don't shut down after the process ends.
    command: sleep infinity

    # Runs app on the same network as the database container, allows "forwardPorts" in devcontainer.json function.
    network_mode: service:postgres

  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
      POSTGRES_PASSWORD: postgres
    healthcheck:
      test: pg_isready -U postgres -h 127.0.0.1
      interval: 5s

volumes:
  postgres-data:
```

In summary, in our Compose file, we define two services: the `app`, which will be our `devcontainer` and is built based on our Dockerfile, and the `postgres`, which will use the official `postgres` image. We add an environment variable `DATABASE_URL` with the value `postgres://postgres:postgres@postgres:5432` to inform our project about this database endpoint. In our `devcontainer`, we override the default command with `command: sleep infinity` to prevent the container from exiting when the main process finishes.

We also modify the `.devcontainer/devcontainer.json` file to use Docker Compose instead of just our Dockerfile. We remove the `build` directive and add the `dockerComposeFile` and `service` sections. Here's the resulting file:

```json
// .devcontainer/devcontainer.json

// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: https://github.com/devcontainers/templates/tree/main/src/ruby-rails-postgres
{
    "name": "DemoApp DevContainer",
    "dockerComposeFile": "docker-compose.yml",
    "service": "app",
    "features": {
        "ghcr.io/shyim/devcontainers-features/bun:0": {}
    },
    "workspaceFolder": "/workspace",
    "remoteEnv": {
        "GIT_EDITOR": "code --wait"
    }
}
```

After rebuilding the DevContainer and accessing it, we run `bin/setup` again, and now the database is created, and our setup is completed successfully.

![devcontainer setup finished](/assets/images/devcontainer-setup-finished.png)

Project code up to this point: [link](https://github.com/duduribeiro/devcontainer-rails-demo/releases/tag/4-use-compose){:target="_blank"}

### Running the project


With the project set up, we can start the project with the command `bin/dev`.

![running the project](/assets/images/running-the-project.png)

The application will start inside the container, and VSCode will give us the option to open the browser. When we access at http://localhost:3000 it show the page with success:

![page opened with success](/assets/images/devcontainer-rails-page.png)

Everything is set up, and our project is running, achieving our goal. We have a development environment that anyone who clones the project can run in just a few minutes.

## Some improvements to our DevContainer


Let's add a few more things to our DevContainer to improve our experience.

The first change we'll make is to add an `onCreateCommand`. This directive tells the DevContainer what command to run when it's created. Cloud DevContainer services (like GitHub Codespaces) also use this command for caching and prebuilding the container to reduce setup time. In our `onCreateCommand` script, we'll update system gems (like Bundler) and run `bin/setup`. This way, every time a DevContainer is created, we won't need to run `bin/setup` and can directly start the server when we initiate the container.

```json
// .devcontainer/devcontainer.json

 "onCreateCommand": ".devcontainer/onCreateCommand.sh"
```

```sh
#!/usr/bin/env bash

# .devcontainer/onCreateCommand.sh

echo "Updating RubyGems..."
gem update --system -N

echo "Setup.."
bin/setup

echo "Seeding database..."
bin/rails db:seed

echo "Done!"
```

Another improvement we can make is to install extensions and add VSCode settings by default. This way, everyone who starts a DevContainer will have the project's standard extensions installed. In the example below, we have some extensions like `ruby-lsp` and `sqltools` for connecting to the database. We also adjust the `sqltools` settings to include the database connection information.

```json
// .devcontainer/devcontainer.json

    "customizations": {
        "vscode": {
            // Set *default* container specific settings.json values on container create.
            "settings": {
                "sqltools.connections": [
                    {
                        "name": "Development Database",
                        "driver": "PostgreSQL",
                        "previewLimit": 50,
                        "server": "postgres",
                        "port": 5432,
                        "database": "devcontainer_rails_demo_development",
                        "username": "postgres",
                        "password": "postgres"
                    },
                    {
                        "name": "Test Database",
                        "driver": "PostgreSQL",
                        "previewLimit": 50,
                        "server": "postgres",
                        "port": 5432,
                        "database": "devcontainer_rails_demo_test",
                        "username": "postgres",
                        "password": "postgres"
                    }
                ],
                "editor.formatOnSave": true
            },
            "extensions": [
                "Shopify.ruby-lsp",
                "manuelpuyol.erb-linter",
                "GitHub.github-vscode-theme",
                "eamodio.gitlens",
                "aki77.rails-db-schema",
                "bung87.rails",
                "mtxr.sqltools-driver-pg",
                "mtxr.sqltools",
                "testdouble.vscode-standard-ruby"
            ],
            "rubyLsp.enableExperimentalFeatures": true
        }
    },
```

We can also fix the ports that are accessible from the container. When we start the server, VSCode identifies that port 3000 is open and performs an auto-forward. However, we can pre-establish this in the `devcontainer.json` and even open the database port:

```json
    // .devcontainer/devcontainer.json

    // Use 'forwardPorts' to make a list of ports inside the container available locally.
    "forwardPorts": [
        3000,
        5432,
    ],
    "portsAttributes": {
        "3000": {
            "label": "web",
            "onAutoForward": "notify",
            "requireLocalPort": true
        },
        "5432": {
            "label": "postgres"
        }      
    }
```

With these final improvements, our DevContainer is now ready for use. The final version up and running:

<video width="600" height="400" controls src="/assets/videos/finalversion.webm"></video>

And with that, we've achieved the goal: using containers to reduce friction in setting up your development environment. The final source code of the project is available at [https://github.com/duduribeiro/devcontainer-rails-demo/](https://github.com/duduribeiro/devcontainer-rails-demo/){:target="_blank"}. You can clone it and set up the environment in just a few minutes to try it out for yourself.

<hr>

Bonus: 

Now that you have your development environment setup with DevContainers, you can also easily use services like [GitHub Codespaces](https://github.com/features/codespaces){:target="_blank"}

<video width="600" height="400" controls src="/assets/videos/codespacesdemo.webm"></video>


Even this blog post was [written inside a DevContainer](https://github.com/duduribeiro/blog/commit/a0740c12fb9f95ce6a9aecea2e087911658e9384){:target="_blank"}. I needed to install Ruby 2.6.8 and some dependencies failed to intall on my machine. So I decided to run this on a DevContainer to have a easy way to run the project every time I want to write a new post. 

<hr>

References: 
* https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces/adding-a-dev-container-configuration/introduction-to-dev-containers
* https://speakerdeck.com/palkan/railsconf-2019-terraforming-legacy-rails-applications
* https://github.blog/2015-06-30-scripts-to-rule-them-all/
* https://github.blog/2021-08-11-githubs-engineering-team-moved-codespaces/
* https://containers.dev/
* https://code.visualstudio.com/docs/devcontainers/containers
* https://12factor.net/dev-prod-parity
* https://github.com/forem/forem/tree/main/.devcontainer
* https://github.com/robzolkos/rails-devcontainer/
* https://github.com/microsoft/vscode-dev-containers/issues/704

<br>
<br>



Thanks ☕️
