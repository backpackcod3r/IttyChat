#
# IttyChat: A (very!) simple Node.js chat server, written in
# CoffeeScript
#
#
# Copyright (c) 2012 Seth J. Morabito <web@loomcom.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

util   = require 'util'
net    = require 'net'
fs     = require 'fs'
bcrypt = require 'bcrypt'
config = require __dirname + '/../config'
Client = require __dirname + '/client'
models = require __dirname + '/models'

class Server

  # Max string length of 1024 characters (UTF-8, so they may in fact
  # be multibyte)

  MAX_INPUT_LENGTH: 1024

  # Build a new server that will bind to the given IP address
  # and port on startup

  constructor: (address, port) ->
    @address = address
    @port = port

  #
  # Take raw data received from a socket and scrub it
  # of non-printable characters. Returns the scrubbed string.
  #
  cleanInput: (str) ->
    # Remove leading and trailing whitespace, and
    # truncate to our max_length
    cleanedInput = str.substring(0, Server.MAX_INPUT_LENGTH)

    # Remove all control characters. These are conveniently located in
    # the first two pages of the ASCII/UTF8 character space
    cleanedInput = cleanedInput.replace /[\u0000-\u001f\u007f]/g, ''

    cleanedInput.trim()

  # Called when the server receives a SIGINT or SIGKILL
  signalHandler: =>
    config.logger.info "Cleaning up..."
    Client.notifyAll "System going down RIGHT NOW!\r\n"
    config.logger.info "Bye!"
    process.exit 0

  # Called when a client socket emits an 'end' event
  endHandler: (socket) =>
    client = Client.findClient(socket)
    if client?
      Client.removeClient client
      if client.isAuthenticated
        client.notifyOthers "#{client.name()} has left the chat"
      config.logger.info "Disconnect from #{client} [c:#{Client.count()}]"

  # Callled when a client socket connects to the server.
  clientListener: (socket) =>
    # Handle all strings internally as UTF-8.
    socket.setEncoding('utf8')

    # TODO: Do we need to set allowHalfOpen = true?

    client = new Client(socket)
    Client.addClient(client)

    config.logger.info "Connection from #{client} [c:#{Client.count()}]"

    client.sendWelcome()

    socket.on 'data', (data) =>
      client.parseAndExecute @cleanInput(data)

    socket.on 'end', =>
      @endHandler(socket)

  # Make an IttyChat server and start listening on the given address
  # and port.
  start: =>
    models.sequelize.sync().on('success', =>
      process.on 'SIGINT', @signalHandler
      server = net.createServer @clientListener
      server.listen @port, @address, =>
        config.logger.info "Now listening on #{server.address().address}:#{server.address().port}"
    ).on('error', ->
      config.logger.info "Could not synchronize database!"
    )

module.exports = Server