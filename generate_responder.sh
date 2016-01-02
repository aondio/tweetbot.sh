#!/usr/bin/env bash

work_dir="$(pwd)"
tools_dir="$(cd "$(dirname "$0")" && pwd)"
source "$tools_dir/common.sh"

echo 'Generating responder script...' 1>&2
echo "  sources: $TWEET_BASE_DIR/responses" 1>&2
echo "  output : $responder" 1>&2

cat << FIN > "$responder"
#!/usr/bin/env bash
#
# This file is generated by "generate_responder.sh".
# Do not modify this file manually.

base_dir="\$(cd "\$(dirname "\$0")" && pwd)"

input="\$(cat |
            # remove all whitespaces
            sed 's/[ \f\n\r\t　]+/ /g'
            # normalize waves
            sed 's/〜/～/g')"

choose_random_one() {
  local input="\$(cat)"
  local n_lines="\$(echo "\$input" | wc -l)"
  local index=\$(((\$RANDOM % \$n_lines) + 1))
  echo "\$input" | sed -n "\${index}p"
}

# echo the input with the probability N% (0-100)
echo_with_probability() {
  local probability=\$1
  [ \$((\$RANDOM % 100)) -lt \$probability ] && cat
}

extract_response() {
  local source="\$1"
  if [ ! -f "\$source" ]
  then
    echo ""
    return 0
  fi

  # convert CR+LF => LF for safety at first.
  local responses="\$( nkf -Lu "\$source" |
                        grep -v '^#' |
                        grep -v '^[$whitespaces]*\$')"

  [ "\$responses" = '' ] && return 1

  echo "\$responses" | choose_random_one
}

FIN

cd "$TWEET_BASE_DIR"

if [ -d ./responses ]
then
  ls ./responses/* |
    sort |
    egrep -v '/_|^_' |
    while read path
  do
    matcher="$(\
      # first, convert CR+LF => LF
      nkf -Lu "$path" |
        # extract comment lines as definitions of matching patterns
        grep '^#' |
        # remove comment marks
        $esed -e "s/^#[$whitespaces]*//" \
              -e "/^[$whitespaces]$/d" |
        # concate them to a list of patterns
        paste -s -d '|')"
    [ "$matcher" = '' ] && continue
    cat << FIN >> "$responder"
if echo "\$input" | egrep -i "$matcher" > /dev/null
then
  [ "\$DEBUG" != '' ] && echo "Matched to \"$matcher\", from \"\$base_dir/$path\"" 1>&2
  extract_response "\$base_dir/$path"
  exit \$?
fi

FIN
  done

  pong_file='./responses/_pong.txt'
  connectors_file='./responses/_connectors.txt'
  topics_file='./responses/_topics.txt'
  developments_file='./responses/_developments.txt'
  cat << FIN >> "$responder"
# fallback to generated-patterns
[ "\$DEBUG" != '' ] && echo "Not matched to any case" 1>&2
[ "\$NO_QUESTION" != '' ] && exit 1

[ "\$DEBUG" != '' ] && echo "Generated response" 1>&2
if [ "\$IS_REPLY" = '1' ]
then
  # If it is a reply of continuous context, you can two choices:
  if [ "\$(echo 1 | echo_with_probability $FREQUENCY_OF_CAPRICES)" != '' ]
  then
    [ "\$DEBUG" != '' ] && echo "Try to change the topic" 1>&2
    # 1) Change the topic.
    #    Then we should reply twite: a "pong" and "question about next topic".
    pong="\$(extract_response "\$base_dir/$pong_file")"

    question="\$(extract_response "\$base_dir/$topics_file" | echo_with_probability $NEW_TOPIC)"
    if [ "\$question" != '' ]
    then
      [ "\$DEBUG" != '' ] && echo "Changing topic" 1>&2
      # "pong" can be omitted if there is question
      pong="\$(echo "\$pong" | echo_with_probability 90)"
      [ "\$pong" != '' ] && pong="\$pong "

      connctor="\$(extract_response "\$base_dir/$connectors_file" | echo_with_probability 95)"
      [ "\$connector" != '' ] && connctor="\$connctor "
      question="\$connctor\$question"
    fi
  else
    [ "\$DEBUG" != '' ] && echo "Continue to talk" 1>&2
    # 2) Continue to talk about the current topic.
    #    The continueous question should be a part of "pong".
    pong="\$(extract_response "\$base_dir/$pong_file")"
    following="\$(extract_response "\$base_dir/$developments_file" | echo_with_probability $CONVERSATION_PERSISTENCE)"
    if [ "\$following" != '' ]
    then
      pong="\$(echo "\$pong" | echo_with_probability 50)"
      pong="\$pong \$following"
    fi
  fi
else
  # If it is not a reply, we always start new conversation without "pong".
  question="\$(extract_response "\$base_dir/$topics_file")"
fi

# Then output each responses.
[ "\$pong" != '' ] && echo "\$pong"
[ "\$question" != '' ] && echo "\$question"

exit 0

FIN
fi

chmod +x "$responder"
