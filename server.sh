if [ "$ENABLE_HTTPS" == "true" ]; then
    if lego --path $LEGO_PATH list | grep -q 'No certificates found.'; then
        echo "running lego new command"
        lego --path $LEGO_PATH $LEGO_NEW_COMMAND_ARGS
    fi
fi

{ node server/index.js;  } &
{ crond -f -d 8;  } &
wait -n
echo kill all
pkill -P $$
echo exit parent