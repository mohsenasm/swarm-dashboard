# Up
    vagrant up

# Run swarm-dashboard
    vagrant ssh manager1 # password: docker
    docker stack deploy -c /vagrant/compose.yml sd

<!-- # Run swarm-dashboard (build locally)
    vagrant ssh manager1 # password: docker
    docker stack deploy -c /vagrant_parent/test-cluster/test-swarm-compose.yml sd
    docker-compose -f /vagrant_parent/test-cluster/test-local-compose.yml up --build -->

# Shutdown
    vagrant halt

# Destroy
    vagrant destroy -f