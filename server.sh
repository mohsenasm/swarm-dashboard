if [ "$ENABLE_HTTPS" == "true" ]; then
    if lego --path $LEGO_PATH list | grep -q 'No certificates found.'; then
        echo "running lego new command"
        lego --path $LEGO_PATH $LEGO_NEW_COMMAND_ARGS
    else
        echo "running lego renew command"
        no_random_sleep_option="--no-random-sleep"
        if [ "$USE_RENEW_DELAY_ON_START" == "true" ]; then
            no_random_sleep_option=""
        fi
        lego --path $LEGO_PATH $LEGO_RENEW_COMMAND_ARGS $no_random_sleep_option
    fi
fi

{ node server/index.js;  } &
{ crond -f -d 8;  } &
wait -n
echo kill all
pkill -P $$
echo exit parent