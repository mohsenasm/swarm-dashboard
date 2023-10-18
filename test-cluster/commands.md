# Up
    vagrant up

# Run swarm-dashboard
    vagrant ssh manager1 # password: docker
    docker stack deploy -c /vagrant/compose.yml sd

# Shutdown
    vagrant halt

# Destroy
    vagrant destroy -f