#!/usr/bin/env bash

# This is a sample script to register a tweetbot instance as a service for systemd.

tools_dir="$(cd "$(dirname "$0")" && pwd)"
pidfile="/tmp/.tweetbot.pidfile"

cd "$tools_dir"

if [ -f "$pidfile" ]
then
  pid="$(cat "$pidfile")"
  kill "$pid"
  rm "$pidfile"
fi

if [ "$1" != 'stop' ]
then
  #export TWEETBOT_DEBUG=1
  "$tools_dir/tweetbot.sh/watch.sh" &
  echo "$!" > "$pidfile"
fi
