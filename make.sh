#!/bin/bash


bash wrapper.sh &
wrapper_pid=$!
wait $wrapper_pid

scp /path/to/source/file user@remote:/path/to/destination/