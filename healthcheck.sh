if [ "$ENABLE_HTTPS" == "true" ]; then
    curl --insecure --fail https://localhost:$PORT/_health || exit 1
else
    curl --fail http://localhost:$PORT/_health || exit 1
fi