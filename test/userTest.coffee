models     = require __dirname + '/../lib/models'
testHelper = require __dirname + '/testHelper'

describe 'The User model', ->
  it 'should be able to tell whether a user name is available', (done) ->
    testHelper.UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

      models.User.isNameAvailable 'noSuchUser', (isAvailable) ->
        isAvailable.should.be.true
        done()

  it 'should be able to tell whether a user name is in use', (done) ->
    testHelper.UserBuilder.create 'joeBob', 'joeBob@example.com', 'foo5bar', (user) ->

      models.User.isNameAvailable 'joeBob', (isAvailable) ->
        isAvailable.should.be.false
        done()
