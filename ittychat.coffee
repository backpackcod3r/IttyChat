Server = require('./lib/server')
util = require 'util'
sqlite3 = require 'sqlite3'

args = process.argv.splice(2)

if args.length < 1 or args.length > 2
  console.log "Usage: coffee ittychat.coffee [-l] <port>"

#
# See if we want to bind to localhost only
#
localOnly = false
for arg in args
  localOnly = true if arg is "-l"

port = parseInt args.pop()

if port > 1024

  # TODO: IPv6, etc.
  if localOnly
    addr = '127.0.0.1'
  else
    addr = '0.0.0.0'

  ittychat = new Server(addr, port)
  ittychat.start()

else
  console.log "Port must be > 1024"
  process.exit 1