# Swarm Dashboard

A simple monitoring dashboard for Docker in Swarm Mode.

![Example Dashboard](./swarm.gif)

## About

Swarm dashboard shows you all the tasks running on a Docker Swarm organised
by service and node. It provides a visualisation that's space efficient
and works well at a glance.

You can use it as a simple live dashboard of the state of your Swarm.

The Dashboard has a node.js server which streams swarm updates to an Elm client
over a websocket.

### Prior art

* Heavily inspired by [Docker Swarm Visualiser](https://github.com/dockersamples/docker-swarm-visualizer)

## Running

At the moment, the dashboard needs to be deployed on one of the swarm managers.
You can configure it with the following Docker compose file:

```yml
# compose.yml
version: "3"

services:
  dashboard:
    image: charypar/swarm-dashboard
    volumes:
    - "/var/run/docker.sock:/var/run/docker.sock"
    ports:
    - 8080:8080
    environment:
      PORT: 8080
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
```

and deploy with

```
$ docker stack deploy -c compose.yml svc
```

## Rough roadmap

* Show more service details (published port, image name and version)
* Show overlay networks
* Node / Service / Task details panel
* Reduce polling and network transfer
* Show resources (CPU & Memory)
* Harden for potential production use

Both feature requests and pull requests are welcome
