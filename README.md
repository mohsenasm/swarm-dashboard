# Swarm Dashboard

A simple monitoring dashboard for Docker in Swarm Mode.

![Example Dashboaerd](./swarm.gif)

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

> TODO finish when an initial version is tagged and published to Docker Hub

## Rough roadmap

* Show node details (role, state and availability, resources, ...)
* Show more service details (published port, image name and version)
* Show overlay networks
* Allow hiding failed tasks
* Node / Service / Task details panel
* Harden for potential production use

Both feature requests and pull requests are welcome
