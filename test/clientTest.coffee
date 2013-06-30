Client = require '../lib/client'
models = require '../lib/models/index'
bcrypt = require 'bcrypt'
util = require 'util'
should = require 'should'
sinon = require 'sinon'
fs = require 'fs'
path = require 'path'

#
# A stub for net.Socket, so we can inspect calls.
#
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

# Intercept calls to 'fs.readFile' for testing.
sinon.stub(fs, 'readFile')

describe 'Clients', ->
  before (done) ->
    models.sequelize.sync(force: true).success( ->
      done()
    ).error( ->
      throw new Error('Unable to synchronize database')
    )

  beforeEach () ->
    models.User.destroyAll()
    Client.resetAll()

  describe 'The Client Collection', ->

    it 'should start with no clients', ->
      Client.count().should.eql 0

    it 'should increment the count when adding a client', ->
      oldCount = Client.count()
      client = ClientBuilder.create '192.168.1.1'
      Client.addClient(client)
      Client.count().should.eql oldCount + 1

    it 'should be able to find a client by socket', ->
      socket = new SocketStub('192.168.1.1')
      client = new Client(socket)

      Client.addClient(client)
      Client.findClient(socket).should.eql client

    it 'should be able to remove a client', ->
      Client.count().should.eql 0

      client1 = ClientBuilder.create '192.168.1.1'
      client2 = ClientBuilder.create '192.168.1.2'

      Client.addClient(client1)
      Client.addClient(client2)
      Client.count().should.eql 2

      Client.removeClient(client1)
      Client.count().should.eql 1


    it 'should notify both authenticated and unauthenticated clients with notifyAll', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

        authedClient = ClientBuilder.create '192.168.1.1'
        unauthedClient = ClientBuilder.create '192.168.1.2'

        authedClient.authenticate 'joeBob', 'foo5bar', (client) ->
          authedClient.isAuthenticated().should.be.true

          Client.addClient(authedClient)
          Client.addClient(unauthedClient)

          Client.count().should.eql 2

          Client.notifyAll("A test message")

          authedClient.socket.hasReceived(/A test message/).should.be.true
          unauthedClient.socket.hasReceived(/A test message/).should.be.true

          done()

    it 'should notify only authenticated clients with notifyAuthed', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

        authedClient = ClientBuilder.create '192.168.1.1'
        unauthedClient = ClientBuilder.create '192.168.1.2'

        authedClient.authenticate 'joeBob', 'foo5bar', (client) ->
          authedClient.isAuthenticated().should.be.true

          Client.addClient(authedClient)
          Client.addClient(unauthedClient)

          Client.count().should.eql 2

          Client.notifyAuthed("A test message")

          authedClient.socket.hasReceived(/A test message/).should.be.true
          unauthedClient.socket.hasReceived(/A test message/).should.be.false

          done()

    it 'should increment the count of clients when adding one', ->
      client = ClientBuilder.create('192.168.1.1')

      oldCount = Client.count()
      Client.addClient(client)
      Client.count().should.eql(oldCount + 1)

    it 'should decrement the count of clients when removing one', ->
      client = ClientBuilder.create '192.168.1.1'

      Client.addClient(client)
      oldCount = Client.count()
      Client.removeClient(client)
      Client.count().should.eql(oldCount - 1)

    it 'should give access to the set of authed clients', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

        authedClient = ClientBuilder.create '192.168.1.1'
        unauthedClient = ClientBuilder.create '192.168.1.2'

        authedClient.authenticate 'joeBob', 'foo5bar', (client) ->
          authedClient.isAuthenticated().should.be.true

          Client.addClient(authedClient)
          Client.addClient(unauthedClient)

          Client.count().should.eql 2
          Client.authedClients().should.eql [authedClient]

          done()

    it 'should be able to tell whether a user name is available', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

        Client.isNameInUse 'noSuchUser', (inUse) ->
          inUse.should.be.false
          done()

    it 'should be able to tell whether a user name is in use', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

        Client.isNameInUse 'joeBob', (inUse) ->
          inUse.should.be.true
          done()

  describe 'Client Registration', ->
    it 'should create a new User model on registration', (done) ->
      client = ClientBuilder.create '192.168.1.1'

      models.User.count().success (beforeCount) ->
        client.register 'joeBob', 'foo5bar', 'joebob@example.com', (err, client) ->
          models.User.count().success (afterCount) ->
            afterCount.should.eql beforeCount + 1
            done()

    it 'should be able to change its name', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->
        client = ClientBuilder.create('192.168.1.1')
        client.authenticate 'joeBob', 'foo5bar', (error, client) ->
          client.name().should.eql 'joeBob'
          client.changeName 'billyBob', (error, client) ->
            client.name().should.eql 'billyBob'
            done()

    it 'should not be able to change its name to an invalid name', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->
        client = ClientBuilder.create('192.168.1.1')
        client.authenticate 'joeBob', 'foo5bar', (error, client) ->
          client.name().should.eql 'joeBob'
          # Spaces aren't allowed
          client.changeName 'billy bob', (error, client) ->
            error.should.eql 'That is not a valid name, sorry.'
            client.name().should.eql 'joeBob'
            done()

    it 'should save its new name in the database when changing', (done) ->
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->
        client = ClientBuilder.create('192.168.1.1')
        client.authenticate 'joeBob', 'foo5bar', (error, client) ->
          client.name().should.eql 'joeBob'
          client.changeName 'billyBob', (error, client) ->
            should.not.exist(error)
            should.exist(client)
            Client.isNameInUse 'billyBob', (isInUse) ->
              isInUse.should.be.true
              done()

    it 'should should not allow a name change to something already in use', (done) ->
      UserBuilder.create 'billyBob', 'billyBob@example.com', 'foo5bar', (user) ->
        UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->
          client = ClientBuilder.create('192.168.1.1')
          client.authenticate 'joeBob', 'foo5bar', (error, client) ->
            client.name().should.eql 'joeBob'
            client.changeName 'billyBob', (error, client) ->
              error.should.eql 'That name is already taken!'
              client.name().should.eql 'joeBob'
              done()

    it 'should be able to connect only once with the same name', (done) ->
      client1 = ClientBuilder.create '192.168.1.1'
      client2 = ClientBuilder.create '192.168.1.2'
      Client.addClient(client1)
      Client.addClient(client2)
      UserBuilder.create 'billyBob', 'billyBob@example.com', 'foo5bar', (user) ->
        client1.authenticate 'billyBob', 'foo5bar', (error, client) ->
          should.not.exist(error)
          should.exist(client)
          # First authentication, no problem.
          client1.isAuthenticated().should.be.true
          client2.authenticate 'billyBob', 'foo5bar', (error, client) ->
            client2.isAuthenticated().should.be.false
            should.exist(error)
            error.should.eql "That user is already connected!"
            done()

    it 'should allow multiple users with different names', (done) ->
      client1 = ClientBuilder.create '192.168.1.1'
      client2 = ClientBuilder.create '192.168.1.2'
      Client.addClient(client1)
      Client.addClient(client2)
      UserBuilder.create 'billyBob', 'billyBob@example.com', 'foo5bar', (user) ->
        UserBuilder.create 'joeBob', 'joeBob@example.com', 'bar5foo', (user) ->
          client1.authenticate 'billyBob', 'foo5bar', (error, client) ->
            should.not.exist(error)
            should.exist(client)
            client1.isAuthenticated().should.be.true
            client2.authenticate 'joeBob', 'bar5foo', (error, client) ->
              should.not.exist(error)
              should.exist(client)
              client2.isAuthenticated().should.be.true
              done()

  describe 'A Client', ->

    it "should write to client socket", ->
      client = ClientBuilder.create '192.168.1.1'
      client.notify('1234')
      client.socket.hasReceived("1234\r\n").should.be.true

    it 'should not be authenticated when created', ->
      client = ClientBuilder.create '192.168.1.1'
      client.isAuthenticated().should.be.false

    it 'should not validate a name over 16 characters long', ->
      client = ClientBuilder.create '192.168.1.1'
      client.isValidName('foobarfoobarfoob').should.be.true
      client.isValidName('foobarfoobarfooba').should.be.false

    it 'should not validate a name with spaces in it', ->
      client = ClientBuilder.create '192.168.1.1'
      client.isValidName('foo bar').should.be.false

    it 'should have a socket', ->
      client = ClientBuilder.create '192.168.1.1'
      client.should.have.property('socket')

    it "should get socket's remote address", ->
      client = ClientBuilder.create '192.168.1.1'
      client.address.should.eql(client.socket.remoteAddress)

    it 'should have no name if not authenticated', ->
      client = ClientBuilder.create '192.168.1.1'
      should.not.exist(client.name())

    it 'should have a name if authenticated', (done) ->
      client = ClientBuilder.create '192.168.1.1'
      UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->
        client.authenticate 'joeBob', 'foo5bar', (error, client) ->
          client.name().should.eql 'joeBob'
          done()

    it 'should be able to get a list of connected users with .who', (done) ->
      billyBob = ClientBuilder.create '192.168.1.1'
      joeBob = ClientBuilder.create '192.168.1.2'
      jimBob = ClientBuilder.create '192.168.1.2'
      Client.addClient(billyBob)
      Client.addClient(joeBob)
      Client.addClient(jimBob)

      UserBuilder.create 'billyBob', 'billyBob@example.com', 'foo5bar', (user) ->
        UserBuilder.create 'joeBob', 'joeBob@example.com', 'bar5foo', (user) ->
          UserBuilder.create 'jimBob', 'jimBob@example.com', 'foobar5', (user) ->
            billyBob.authenticate 'billyBob', 'foo5bar', (error, client) ->
              joeBob.authenticate 'joeBob', 'bar5foo', (error, client) ->
                jimBob.authenticate 'jimBob', 'foobar5', (error, client) ->

                  joeBob.handleInput('.who\r\n')
                  joeBob.socket.hasReceived("The following users are connected:\r\n").should.be.true
                  joeBob.socket.hasReceived("    billyBob\r\n").should.be.true
                  joeBob.socket.hasReceived("    jimBob\r\n").should.be.true
                  joeBob.socket.hasReceived("    joeBob\r\n").should.be.true

                  # But the other sockets have not been told.
                  jimBob.socket.hasReceived("The following users are connected:\r\n").should.be.false
                  jimBob.socket.hasReceived("    billyBob\r\n").should.be.false
                  jimBob.socket.hasReceived("    jimBob\r\n").should.be.false
                  jimBob.socket.hasReceived("    joeBob\r\n").should.be.false

                  billyBob.socket.hasReceived("The following users are connected:\r\n").should.be.false
                  billyBob.socket.hasReceived("    billyBob\r\n").should.be.false
                  billyBob.socket.hasReceived("    jimBob\r\n").should.be.false
                  billyBob.socket.hasReceived("    joeBob\r\n").should.be.false

                  done()