#!/usr/bin/bash

function cleanup() {
  # Shutdown all child processes, including jupyter-lab
  pkill -P $$
  exit 1
}

# Make sure we cleanup jupyter-lab if anything goes wrong
trap cleanup ERR SIGINT SIGTERM SIGKILL SIGHUP

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"
source venv/bin/activate # this environment must already be present in the above folder

OUTPUT_LOG="/tmp/jupyter-lab_$(date +%s%N).log"
echo "Saving Jupyter-lab output to $OUTPUT_LOG"
jupyter-lab --no-browser &> "$OUTPUT_LOG" &

# Hang around until jupyter starts
n_retries=50
for i in $(seq 1 $n_retries); do
  echo "Waiting for Jupyter to start... [$i/$n_retries]"
  if grep -q "lab?token=" "$OUTPUT_LOG"; then
    break
  else
    sleep 1
  fi
done

# If we can't find a valid URL after 10 seconds, assume something went wrong
if ! grep -q "lab?token=" "$OUTPUT_LOG"; then
  echo "Something went wrong with Jupyter-lab! Here are the logs:"
  cat "$OUTPUT_LOG"
  exit 1
fi

echo "Jupyter started!"

# Extract URL and port number from jupyter log
URL=$(grep "lab?token=" "$OUTPUT_LOG" | tail -n1 | sed -nE "s/(http:\/\/.*)/\1/p")
PORT=$(echo $URL | sed -nE "s/.*:([0-9]{4})\/lab\?token=.*/\1/p")

# Give user instructions
echo
echo "Open another terminal and run the following command (keep both terminals open!):"
echo "        ssh -J $USER@login8.cosma.dur.ac.uk -L $PORT:127.0.0.1:$PORT $USER@gn001"
echo
echo "Then open the following link in your browser:"
echo "$URL"
echo

read -p "Press Enter to shutdown jupyter-lab." </dev/tty

cleanup
