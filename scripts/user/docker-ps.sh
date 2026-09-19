#!/bin/bash

dps() {
  local filter_args=()

  for name in "$@"; do
    filter_args+=(--filter "name=$name")
  done

  # Run the docker command with your custom format layout
  docker container ls --no-trunc "${filter_args[@]}" --format "\n\
Names: \t\t {{.Names}}\n\
ID: \t\t {{.ID}}\n\
Image ID: \t {{.Image}}\n\
Command: \t {{.Command}}\n\
Created At: \t {{.CreatedAt}}\n\
Elapsed time: \t {{.RunningFor}}\n\
Exposed ports: \t {{.Ports}}\n\
Status: \t {{.State}} - {{.Status}}\n\
Disk size: \t {{.Size}}\n\
Volumes: \t {{.Mounts}}\n\
Networks: \t {{.Networks}}\n"
}

dps "$@"
