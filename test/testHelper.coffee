#
# A stub for net.Socket, so we can inspect calls.
#
bcrypt = require 'bcrypt'
Client = require __dirname + '/../lib/client'
models = require __dirname + '/../lib/models'

class SocketStub
  constructor: (@remoteAddress) ->
    @bytesWritten = 0
    @notifications = new Array()

  write: (string) ->
    @bytesWritten += string.length
    @notifications.push string

  close: () ->

    # Return true if the socket has received the specified message.
    # If message is a string, it must be a full, exact match for one
    # of the received messages. If the message argument is a RegExp,
    # it must match one of the received messages.
  hasReceived: (msg) ->
    @notifications.some (notification) ->
      if msg instanceof RegExp
        notification.match(msg)
      else
        notification is msg

class UserBuilder
  @create = (name, email, password, callback) =>
    salt = bcrypt.genSaltSync()
    hash = bcrypt.hashSync(password, salt)
    user = models.User.build name: name, cryptedPassword: hash, email: email
    user.save().success (user) ->
      callback(user)

class ClientBuilder
  @create = (ipAddress) ->
    new Client(new SocketStub(ipAddress))

module.exports['SocketStub'] = SocketStub
module.exports['UserBuilder'] = UserBuilder
module.exports['ClientBuilder'] = ClientBuilder