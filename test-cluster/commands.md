# Up
    vagrant up

# Run swarm-dashboard (image from Docker Hub)
    vagrant ssh manager1
    docker stack deploy -c /vagrant/compose-all.yml sd

# Run swarm-dashboard (build locally)
    vagrant ssh manager1
    docker stack deploy -c /vagrant_parent/test-cluster/compose-metrics.yml sd
    docker-compose -f /vagrant_parent/test-cluster/compose-dashboard.yml up --build

# Shutdown
    vagrant halt

# Destroy
    vagrant destroy -f