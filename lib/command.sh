#!/usr/bin/env bash
command::exists() {
  command -v "$1" &> /dev/null
}
