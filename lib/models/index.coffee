Sequelize = require 'sequelize'
config    = require __dirname + '/../../config'

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

User = sequelize.define 'users',
  name: Sequelize.STRING,
  cryptedPassword: Sequelize.STRING,
  email: Sequelize.STRING,
  lastConnection: Sequelize.DATE

module.exports['sequelize'] = sequelize
module.exports['User'] = User