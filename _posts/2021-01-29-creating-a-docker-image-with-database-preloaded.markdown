---
title: "Creating a Docker image with a preloaded database"
layout: post
date: 2021-01-29 12:00:00 -0300
image: /assets/images/preloaded_database.png
headerImage: true
tag:
- docker
- database
category: blog
author: dudribeiro
description: "Let's see how can we embed a database into a Docker Image"
hidden: false
---
Imagine that we have the following Postgresql database dump:
{% highlight sql %}
--
-- PostgreSQL database dump
--

-- Dumped from database version 11.5
-- Dumped by pg_dump version 11.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: my_db; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE my_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8';


ALTER DATABASE my_db OWNER TO postgres;

\connect my_db

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clients_id_seq OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name) FROM stdin;
1	Client 1
2	Client 2
\.


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_id_seq', 2, true);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--
{% endhighlight %}

It is a simple database with a `Clients` table and 2 records.

If we want to start a Postgresql Docker container with this dump loaded to share with our team, we can add this SQL file into the */docker-entrypoint-initdb.d/* folder inside the container, like [explained into the Postgresql Image docs from DockerHub](https://hub.docker.com/_/postgres).
> Initialization scripts
> If you would like to do additional initialization in an image derived from this one, add one or more *.sql, *.sql.gz, or *.sh scripts under /docker-entrypoint-initdb.d (creating the directory if necessary). After the entrypoint calls initdb to create the default postgres user and database, it will run any *.sql files, run any executable *.sh scripts, and source any non-executable *.sh scripts found in that directory to do further initialization before starting the service.

The following Dockerfile uses *postgres:11-alpine* as base image and copies *test_dump.sql* file to the entrypoint folder.

{% highlight docker %}
FROM postgres:11-alpine

COPY test_dump.sql /docker-entrypoint-initdb.d/
{% endhighlight %}

If we build this image

{% highlight shell %}
$ docker image build . -t preloaded_db:latest
{% endhighlight %}

and start a container with the generated image

{% highlight shell %}
$ docker container run -d --rm -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres --name test_preloaded_db preloaded_db:latest
{% endhighlight %}

we can see in our database that the database was created. (password is `postgres`)

{% highlight shell %}
$ psql -h localhost -U postgres
postgres=# \c my_db
psql (11.3, server 11.5)
You are now connected to database “my_db” as user “postgres”.
my_db=# SELECT * FROM clients;
 id | name
 — — + — — — — —
 1 | Client 1
 2 | Client 2
(2 rows)
{% endhighlight %}

Awesome. Now we have a docker image that has our database loaded. But if we check the log of this container

{% highlight shell %}
$ docker container logs test_preloaded_db
{% endhighlight %}

we can see CREATE DATABASE and CREATE TABLE commands.

{% highlight sql %}
/usr/local/bin/docker-entrypoint.sh: running /docker-entrypoint-initdb.d/test_dump.sql
SET
SET
SET
SET
SET
 set_config
------------

(1 row)

SET
SET
SET
SET
CREATE DATABASE
ALTER DATABASE
...
{% endhighlight %}


This tell us that the dump is being processed every time we create the container. If we destroy this container and create a new one, the dump will be processed again. This works fine but if we have a big database with a big dump file, the startup process of the container will be slow because it can take some time to process the whole dump. We can fix it by keeping the database preloaded in the image.

Before we moving on, let's destroy the container we created

{% highlight shell %}
$ docker container rm -f test_preloaded_db
{% endhighlight %}

<div class="breaker"></div>

## Preloading the database in the image

To preload the database in the image, we need to tell our Dockerfile to execute the same `entrypoint` of the original PostgreSQL image so it can execute the dump in the build step. Let's use [Multi-Stage build](https://docs.docker.com/develop/develop-images/multistage-build) to divide our build in two steps. The first one will execute the `entrypoint` with the dump file and the second one will copy the data folder to the resulting image.

{% highlight docker %}
# dump build stage
FROM postgres:11-alpine as dumper

COPY test_dump.sql /docker-entrypoint-initdb.d/

RUN ["sed", "-i", "s/exec \"$@\"/echo \"skipping...\"/", "/usr/local/bin/docker-entrypoint.sh"]

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV PGDATA=/data

RUN ["/usr/local/bin/docker-entrypoint.sh", "postgres"]

# final build stage
FROM postgres:11-alpine

COPY --from=dumper /data $PGDATA
{% endhighlight %}

In the first step, we have the following instructions:

* **FROM postgres:11-alpine as dumper** We define the base image our step will use. `postgres` with the `11-alpine` tag in this case.
* **COPY test_dump.sql /docker-entrypoint-initdb.d/** Copy the `test_dump.sql` file to the `/docker-entrypoint-initdb.d/` folder.
* **RUN ["sed", "-i", "s/exec \"$@\"/echo \"skipping...\"/", "/usr/local/bin/docker-entrypoint.sh"]** We need to execute this `sed` command in order to remove the `exec "$@"` content that exists in the `docker-entrypoint.sh` file so it will not start the PostgreSQL daemon (we don't need it on this step).
* **ENV POSTGRES_USER=postgres; ENV POSTGRES_PASSWORD=postgres; ENV PGDATA=/data** Sets environment variables to define `user` and `password` and tell PostgreSQL to use `/data` as data folder, so we can copy it in the next step
* **RUN ["/usr/local/bin/docker-entrypoint.sh", "postgres"]** Execute the entrypoint itself. It will execute the dump and load the data into `/data` folder. Since we executed the `sed` command to remove the `$@` content it will not run the PostgreSQL daemon

The second step contains only this instruction:
* **COPY — from=dumper /data $PGDATA** This will copy all files from `/data` folder from the `dumper` step into the $PGDATA from this current step, making our data preloaded when we start the container (without needing to run the dump every time we create a new container).

If we build this Dockerfile
{% highlight shell %}
$ docker image build . -t preloaded_db:new
{% endhighlight %}

We can see in the output the dump being processed and after everything is finished, the image is built.


and we can start the container with this new image
{% highlight shell %}
$ docker container run -d --rm -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres --name test_preloaded_db preloaded_db:latest
{% endhighlight %}

and our database is loaded

{% highlight sql %}
$ psql -h localhost -U postgres
psql (11.3, server 11.5)
Type “help” for help.
postgres=# \c my_db
psql (11.3, server 11.5)
You are now connected to database “my_db” as user “postgres”.
my_db=# SELECT * FROM clients;
 id | name
 — — + — — — — —
 1 | Client 1
 2 | Client 2
(2 rows)
{% endhighlight %}

But if we check the logs now, the dump is not being processed every time we create the container

{% highlight shell %}
$ docker container logs test_preloaded_db
2019–09–16 01:42:22.458 UTC [1] LOG: listening on IPv4 address “0.0.0.0”, port 5432
2019–09–16 01:42:22.458 UTC [1] LOG: listening on IPv6 address “::”, port 5432
2019–09–16 01:42:22.460 UTC [1] LOG: listening on Unix socket “/var/run/postgresql/.s.PGSQL.5432”
2019–09–16 01:42:22.470 UTC [18] LOG: database system was shut down at 2019–09–16 01:41:02 UTC
2019–09–16 01:42:22.473 UTC [1] LOG: database system is ready to accept connections
{% endhighlight %}

We can see that only the PostgreSQL startup is being done. No dump is being executed because it was executed in the `build` image step.

<div class="breaker"></div>

## Creating a Makefile to make the process easier

I like to create a Makefile to make easier the process of making a database dump and creating an image. This Makefile will contain commands to create the dump the database, create an image and tag it by date allowing me to have daily dumps on my registry to download.

{% highlight Makefile %}
default: all

.PHONY: default all fetch_dump

date := `date '+%Y-%m-%d'`
TARGET_IMAGE ?= my_app

all: check_vars fetch_dump generate_image push_to_registry clean finished

check_vars:
	@test -n "$(DB_ENDPOINT)" || (echo "You need to set DB_ENDPOINT environment variable" >&2 && exit 1)
	@test -n "$(DB_NAME)" || (echo "You need to set DB_NAME environment variable" >&2 && exit 1)
	@test -n "$(DESTINATION_REPOSITORY)" || (echo "You need to set DESTINATION_REPOSITORY environment variable" >&2 && exit 1)

fetch_dump: DB_USER ?= postgres
fetch_dump:
	@echo ""
	@echo "====== Fetching remote dump ======"
	@PGPASSWORD="$(DB_PASSWORD)" pg_dump -h $(DB_ENDPOINT) -d $(DB_NAME) -U $(DB_USER) > dump.sql

generate_image:
generate_image:
	@docker build . -t $(TARGET_IMAGE):latest -t $(DESTINATION_REPOSITORY)/$(TARGET_IMAGE):latest -t $(DESTINATION_REPOSITORY)/$(TARGET_IMAGE):$(date)

push_to_registry:
	@echo ""
	@echo "====== Pushing image to repository ======"
	@docker push $(DESTINATION_REPOSITORY)/$(TARGET_IMAGE)

clean:
	@echo ""
	@echo "====== Cleaning used files ======"
	@rm -f dump.sql

finished:
	@echo ""
	@echo "Finished with success. Pushed image to $(DESTINATION_REPOSITORY)/$(TARGET_IMAGE)"
{% endhighlight %}


And I can execute the following command to generate my image with a new dump

{% highlight shell %}
$ make DB_ENDPOINT=127.0.0.1 DB_USER=postgres DB_PASSWORD=postgres DB_NAME=my_db TARGET_IMAGE=myapp-data DESTINATION_REPOSITORY=gcr.io/my_project
{% endhighlight %}

This command usually is integrated in a Cron job in some server to be executed daily. With this I can have on my image registry dumps from each day.

Another interesting thing to do is to add some SQL script to obfuscate users data. [This article can be helpful if you want to achive this](https://blog.taadeem.net/english/2018/10/29/Introducing-PostgreSQL-Anonymizer)

![image tooltip here](/assets/images/thats_all.png)

Thanks ☕️
