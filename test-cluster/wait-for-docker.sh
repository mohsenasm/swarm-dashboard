until docker info > /dev/null
do
    echo "waiting for docker info"
    sleep 1
done