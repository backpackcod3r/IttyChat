winston = require 'winston'

# Bootstrap the environment
class Config

  @environment: () ->
    process.env.ITTYCHAT_ENV or 'development'

  @db: () ->
    __dirname + "/db/ittychat_#{Config.environment()}.db"

  @logfile: () ->
    __dirname + "/logs/ittychat_#{Config.environment()}.log"

  @logger = (() ->
    if Config.environment() == 'development'
      new winston.Logger
        transports:
          [new winston.transports.File(filename: Config.logfile(), timestamp: true),
           new winston.transports.Console(timestamp: true)]
    else
      new winston.Logger(transports: [new winston.transports.File(filename: Config.logfile(), timestamp: true)])

  )()

module.exports = Config