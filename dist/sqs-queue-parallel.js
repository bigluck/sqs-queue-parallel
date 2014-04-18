/**
 * sqs-queue-parallel 0.1.5 <https://github.com/bigluck/sqs-queue-parallel>
 * Create a poll of Amazon SQS queue watchers and each one can receive 1+ messages
 *
 * Available under MIT license <https://github.com/bigluck/sqs-queue-parallel/raw/master/LICENSE>
 */
(function() {
  var AWS, SqsQueueParallel, async, events, globalConfig, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  AWS = require('aws-sdk');

  events = require('events');

  async = require('async');

  _ = require('lodash');

  globalConfig = {};

  module.exports = SqsQueueParallel = (function(_super) {
    __extends(SqsQueueParallel, _super);

    SqsQueueParallel.configure = function(config) {
      if (config == null) {
        config = {};
      }
      return globalConfig = _.extend(globalConfig, config);
    };

    function SqsQueueParallel(config) {
      var readQueue, self;
      if (config == null) {
        config = {};
      }
      this.config = _.extend({
        region: process.env.AWS_REGION,
        accessKeyId: process.env.AWS_ACCESS_KEY,
        secretAccessKey: process.env.AWS_SECRET_KEY,
        visibilityTimeout: null,
        waitTimeSeconds: 20,
        maxNumberOfMessages: 1,
        name: '',
        concurrency: 1,
        debug: false
      }, globalConfig, config);
      this.client = null;
      this.url = null;
      self = this;
      readQueue = function(index) {
        if (!(self.listeners("message").length && self.url)) {
          return;
        }
        return async.waterfall([
          function(next) {
            var options;
            if (self.config.debug) {
              console.log("SqsQueueParallel " + self.config.name + "[" + index + "]: waiting messages");
            }
            return self.client.receiveMessage((options = {
              QueueUrl: self.url,
              MaxNumberOfMessages: self.config.maxNumberOfMessages,
              WaitTimeSeconds: self.config.waitTimeSeconds
            }, self.config.visibilityTimeout != null ? options.VisibilityTimeout = self.config.visibilityTimeout : void 0, options), next);
          }, function(queue, next) {
            var _ref;
            if (!((_ref = queue.Messages) != null ? _ref[0] : void 0)) {
              return next(null);
            }
            if (self.config.debug) {
              console.log("SqsQueueParallel " + self.config.name + "[" + index + "]: " + queue.Messages.length + " new messages");
            }
            return async.eachSeries(queue.Messages, function(message, next) {
              return self.emit("message", {
                type: 'message',
                data: JSON.parse(message.Body) || message.Body,
                message: message,
                metadata: queue.ResponseMetadata,
                url: self.url,
                name: self.config.name,
                next: next,
                deleteMessage: function(cb) {
                  next();
                  return self.deleteMessage(message.ReceiptHandle, cb);
                },
                delay: function(timeout, cb) {
                  return self.changeMessageVisibility(message.ReceiptHandle, timeout, cb);
                },
                changeMessageVisibility: function(timeout, cb) {
                  next();
                  return self.changeMessageVisibility(message.ReceiptHandle, timeout, cb);
                }
              });
            }, function() {
              return next(null);
            });
          }
        ], function(err) {
          if (err) {
            self.emit.apply(self, ["error"].concat(__slice.call(arguments)));
          }
          return process.nextTick(function() {
            return readQueue(index);
          });
        });
      };
      this.addListener('newListener', function(name) {
        if (name !== 'message') {
          return;
        }
        if (self.config.debug) {
          console.info("SqsQueueParallel " + self.config.name + ": new listener");
        }
        if (!this.client || this.listeners("message").length === 1) {
          return this.connect(function(err) {
            if (err || !self.url || !self.listeners("message").length) {
              return;
            }
            return _.times(self.config.concurrency || 1, function(index) {
              return readQueue(index);
            });
          });
        }
      });
      if (this.config.debug) {
        this.on('connection', function(urls) {
          return console.log("SqsQueueParallel: connection to SQS", urls);
        });
        this.on('connect', function() {
          return console.log("SqsQueueParallel " + self.config.name + ": connected with url `" + self.url + "`");
        });
        this.on('error', function(e) {
          return console.log("SqsQueueParallel " + self.config.name + ": connection failed", e);
        });
      }
    }

    SqsQueueParallel.prototype.connect = function(cb) {
      var self;
      if (!(this.client && this.url)) {
        this.once('connect', function() {
          return cb(null);
        });
        if (this.client && !this.url) {
          return;
        }
      }
      if (this.client) {
        return cb(null);
      }
      self = this;
      this.client = new AWS.SQS({
        region: this.config.region,
        accessKeyId: this.config.accessKeyId,
        secretAccessKey: this.config.secretAccessKey
      });
      async.waterfall([
        function(next) {
          return self.client.listQueues({
            QueueNamePrefix: self.config.name
          }, next);
        }, function(data, next) {
          var re, url, _i, _len, _ref;
          re = new RegExp("/[\\d]+/" + self.config.name + "$");
          self.emit('connection', data.QueueUrls);
          _ref = data.QueueUrls;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            url = _ref[_i];
            if (re.test(url)) {
              self.emit('connect', self.url = url);
            }
          }
          if (!self.url) {
            self.emit('error', new Error('Queue not found'));
            return next('Queue not found');
          }
        }
      ], function(err) {
        if (!err) {
          return;
        }
        self.emit('error', err);
        return cb.apply(null, arguments);
      });
      return this;
    };

    SqsQueueParallel.prototype.sendMessage = function(message, cb) {
      var self;
      if (message == null) {
        message = {};
      }
      if (cb == null) {
        cb = function() {};
      }
      self = this;
      this.connect(function(err) {
        var params;
        if (err) {
          return cb.apply(null, arguments);
        }
        if (self.config.debug) {
          console.log("SqsQueueParallel " + self.config.name + ": before sendMessage with url `" + self.url + "`");
        }
        params = {
          MessageBody: JSON.stringify(message.body || {}),
          QueueUrl: self.url
        };
        if (message.delay != null) {
          params.DelaySeconds = message.delay;
        }
        return self.client.sendMessage(params, cb);
      });
      return this;
    };

    SqsQueueParallel.prototype.deleteMessage = function(receiptHandle, cb) {
      var self;
      if (cb == null) {
        cb = function() {};
      }
      self = this;
      this.connect(function(err) {
        if (err) {
          return cb.apply(null, arguments);
        }
        if (self.config.debug) {
          console.log("SqsQueueParallel " + self.config.name + ": before deleteMessage " + receiptHandle + " with url `" + self.url + "`");
        }
        return self.client.deleteMessage({
          QueueUrl: self.url,
          ReceiptHandle: receiptHandle
        }, cb);
      });
      return this;
    };

    SqsQueueParallel.prototype.changeMessageVisibility = function(receiptHandle, timeout, cb) {
      var self;
      if (timeout == null) {
        timeout = 30;
      }
      if (cb == null) {
        cb = function() {};
      }
      self = this;
      this.connect(function(err) {
        if (err) {
          return cb.apply(null, arguments);
        }
        if (self.config.debug) {
          console.log("SqsQueueParallel " + self.config.name + ": before changeMessageVisibility " + receiptHandle + " with url `" + self.url + "`");
        }
        return self.client.changeMessageVisibility({
          QueueUrl: self.url,
          ReceiptHandle: receiptHandle,
          VisibilityTimeout: timeout
        }, cb);
      });
      return this;
    };

    return SqsQueueParallel;

  })(events.EventEmitter);

}).call(this);
