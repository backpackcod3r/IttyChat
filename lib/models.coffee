Sequelize = require 'sequelize'
config    = require __dirname + '/../config'

sequelize =
  new Sequelize('ittychat', null, null, {
    dialect: 'sqlite',
    storage: config.db(),
    logging: config.logger.debug,
    define:
      classMethods:
        # We want to provide a way to reset a table,
        # especially when re-setting the database
        destroyAll: ->
          sequelize.query "DELETE FROM #{@tableName}"
  })

User = sequelize.define 'users', {
    name: Sequelize.STRING,
    cryptedPassword: Sequelize.STRING,
    email: Sequelize.STRING,
    isBuilder: Sequelize.BOOLEAN,
    isProgrammer: Sequelize.BOOLEAN,
    isWizard: Sequelize.BOOLEAN,
    lastConnection: Sequelize.DATE},

  classMethods: {
    # Determines whether a name is in use by a user in the database.
    # The success callback takes one argument, 'isAvailable', which will
    # be true if the name is available, and false otherwise.
    isNameAvailable: (name, callback) ->
      @find(where: {name: name}).success (user) ->
        callback(not user?)
  },

  instanceMethods: {}


module.exports['sequelize'] = sequelize
module.exports['User'] = User