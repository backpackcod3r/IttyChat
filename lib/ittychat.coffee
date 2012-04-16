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

util = require 'util'
net  = require 'net'
Client = require './client'

# Max string length of 1024 characters (UTF-8, so they may in fact
# be multibyte)

IttyChat =

  MAX_INPUT_LENGTH: 1024

  #
  # Handle the 'quit' command.
  #
  cmdQuit: (client) ->
    # Just call end, and let the event handler take care of cleanup.
    client.socket.end()

  #
  # Handle the 'help' command.
  #
  cmdHelp: (client) ->
    client.sendHelp()

  #
  # Handle the 'motd' command.
  #
  cmdMotd: (client) ->
    client.sendMotd()

  #
  # Handle the 'say' command.
  #
  cmdSay: (client, msg) ->
    if client.isAuthenticated
      Client.notifyAuthed "[#{client.name}]: #{msg}" if msg? and msg.length > 0
    else
      client.notify "Please log in."

  #
  # Handle the 'connect' command.
  #
  cmdConnect: (client, name) ->
    try
      client.authenticate name
    catch error
      # Ugh... is this really JS best practice, just passing along the
      # message? It seems to be.  Feels so dirty.
      client.notify error

  #
  # Handle the 'nick' command.
  #
  cmdNick: (client, name) ->
    try
      client.changeName name
    catch error
      client.notify error

  #
  # Handle the 'who' command.
  #
  cmdWho: (client) ->
    if Client.noAuthedClients()
      client.notify "No one is connected."
    else
      client.notify "The following users are connected:"
      for c in Client.authedClients()
        client.notify "    #{c.name}"

  #
  # Handle the 'me' command
  #
  cmdMe: (client, msg) ->
    if client.isAuthenticated
      Client.notifyAuthed("* #{client.name} #{msg}") if msg? and msg.length > 0
    else
      client.notify "You must be logged in to do that!"

  #
  # Take raw data received from a socket and scrub it
  # of non-printable characters. Returns the scrubbed string.
  #
  cleanInput: (str) ->
    # Remove leading and trailing whitespace, and
    # truncate to our max_length
    cleanedInput = str.substring(0, IttyChat.MAX_INPUT_LENGTH)

    # Remove all control characters. These are conveniently located in
    # the first two pages of the ASCII/UTF8 character space
    cleanedInput = cleanedInput.replace /[\u0000-\u001f\u007f]/g, ''

    cleanedInput.trim()

  #
  # Receive input from the client, and act on it.
  #
  # TODO = This works for the simplest case, but is very fragile. It
  #       assumes all input comes from the client as a single CR/LF
  #       terminated string. What about very long input? Is it
  #       chunked? What about buffered input?
  #
  inputHandler: (client, data) ->
    cleanedInput = IttyChat.cleanInput(data)

    if cleanedInput.length > 0
      util.log "[#{client.address}]: #{cleanedInput}"

      match = cleanedInput.match /^\.(\w*)\s*(.*)/

      if match?
        command = match[1]
        arg = match[2].trim()

        if command.match /^quit/
          IttyChat.cmdQuit client
        else if command.match /^connect/
          IttyChat.cmdConnect client, arg
        else if command.match /^nick/
          IttyChat.cmdNick(client, arg);
        else if command.match /^who/
          IttyChat.cmdWho client
        else if command.match /^me/
          IttyChat.cmdMe client, arg
        else if command.match /^help/
          IttyChat.cmdHelp client
        else if command.match /^motd/
          IttyChat.cmdMotd client
        else if command.match /^say/
          IttyChat.cmdSay client, arg
        else
          client.notify "Huh?"

      else
        IttyChat.cmdSay client, cleanedInput

  # Called when the server receives a SIGINT or SIGKILL
  signalHandler: ->
    util.log "Cleaning up..."
    Client.notifyAll "System going down RIGHT NOW!\r\n"
    util.log "Bye!"
    process.exit 0

  # Called when a client socket emits an 'end' event
  endHandler: (socket) ->
    client = Client.findClient(socket)
    if client?
      Client.removeClient client
      if client.isAuthenticated
        client.notifyOthers "#{client.name} has left the chat"
      util.log "Disconnect from #{client} [c:#{Client.count()}]"

  # Callled when a client socket connects to the server.
  clientListener: (socket) ->
    # Handle all strings internally as UTF-8.
    socket.setEncoding('utf8')

    client = new Client(socket)
    Client.addClient(client)

    util.log "Connection from #{client} [c:#{Client.count()}]"

    client.sendWelcome()

    socket.on 'data', (data) ->
      IttyChat.inputHandler(client, data)

    socket.on 'end', ->
      IttyChat.endHandler(socket)

  # Make an IttyChat server and start listening on the given address
  # and port.
  createServer: (address, port) ->
    process.on 'SIGINT', IttyChat.signalHandler
    process.on 'SIGKILL', IttyChat.signalHandler
    server = net.createServer IttyChat.clientListener
    server.listen port, address, ->
      util.log "Now listening on #{server.address().address}:#{server.address().port}"

module.exports = IttyChat