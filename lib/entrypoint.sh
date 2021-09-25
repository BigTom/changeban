#!/bin/bash
# Docker entrypoint script.


# No database so don't need this
# /app/bin/my_app eval "MyApp.Release.migrate"

exec $@
