/**
 * sqs-queuereceiver 0.1.0 <https://github.com/BigLuck/sqs-queue-parallel>
 * Amazon AWS SQS queue receiver with customized concurrency parallel listener
 *
 * Available under MIT license <https://github.com/BigLuck/sqs-queue-parallel/raw/master/LICENSE>
 */
(function() {
  var AWS, SqsQueueParallel, async, events, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  AWS = require('aws-sdk');

  events = require('events');

  async = require('async');

  _ = require('lodash');

  module.exports = SqsQueueParallel = (function(_super) {
    __extends(SqsQueueParallel, _super);

    function SqsQueueParallel(config) {
      var readQueue, self;
      this.config = _.extend({
        region: process.env.AWS_REGION,
        accessKeyId: process.env.AWS_ACCESS_KEY,
        secretAccessKey: process.env.AWS_SECRET_KEY,
        visibilityTimeout: 30,
        waitTimeSeconds: 20,
        maxNumberOfMessages: 1,
        name: '',
        concurrency: 1,
        debug: true
      }, config || {});
      this.client = null;
      this.url = null;
      self = this;
      readQueue = function(index) {
        if (!(self.listeners("message").length && self.url)) {
          return;
        }
        return async.waterfall([
          function(next) {
            if (self.config.debug) {
              console.log("SqsQueueParallel " + self.config.name + "[" + index + "]: waiting");
            }
            return self.client.receiveMessage({
              QueueUrl: self.url,
              MaxNumberOfMessages: self.config.maxNumberOfMessages,
              VisibilityTimeout: self.config.visibilityTimeout,
              WaitTimeSeconds: self.config.waitTimeSeconds
            }, next);
          }, function(queue, next) {
            var _ref;
            if (!((_ref = queue.Messages) != null ? _ref[0] : void 0)) {
              return next();
            }
            if (self.config.debug) {
              console.log("SqsQueueParallel " + self.config.name + "[" + index + "]: " + queue.Messages.length + " new messages");
            }
            return async.eachSeries(queue.Messages, function(message, cb) {
              return self.emit("message", {
                type: 'message',
                data: JSON.parse(message.Body) || message.Body,
                message: message,
                metadata: queue.ResponseMetadata,
                url: self.url,
                "delete": function(cb) {
                  console.log('before delete: ', message);
                  return self["delete"](message.ReceiptHandle, cb);
                },
                next: cb
              });
            }, function() {
              return next();
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
      this.addListener('newListener', function(e) {
        if (e !== 'message') {
          return;
        }
        if (self.config.debug) {
          console.info("SqsQueueParallel " + self.config.name + ": new listener");
        }
        if (!this.client || this.listeners("message").length === 1) {
          return this.connect(function(err) {
            if (err) {
              return;
            }
            if (!(self.listeners("message").length && self.url)) {
              return;
            }
            return _.times(self.config.concurrency || 1, function(index) {
              return readQueue(index);
            });
          });
        }
      });
    }

    SqsQueueParallel.prototype.connect = function(cb) {
      var self;
      if (!(this.client && this.url)) {
        this.once('connection', function() {
          return cb();
        });
      }
      if (this.client && !this.url) {
        return;
      }
      if (this.client) {
        return cb(null);
      }
      self = this;
      this.client = new AWS.SQS({
        region: this.config.region || process.env.AWS_REGION,
        accessKeyId: this.config.accessKeyId || process.env.AWS_ACCESS_KEY,
        secretAccessKey: this.config.secretAccessKey || process.env.AWS_SECRET_KEY
      });
      this.client.listQueues({
        QueueNamePrefix: this.config.name
      }, function(err, data) {
        var match, name, url, _i, _len, _ref, _ref1;
        if (data.QueueUrls) {
          _ref = data.QueueUrls;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            url = _ref[_i];
            if (!(_ref1 = (new RegExp("/[\\d]+/" + self.config.name + "$")).exec(url), match = _ref1[0], name = _ref1[1], _ref1)) {
              continue;
            }
            if (self.config.debug) {
              console.log("SqsQueueParallel " + self.config.name + ": connected with url `" + url + "`");
            }
            self.url = url;
            self.emit('connection', {
              client: self.client,
              url: url
            });
          }
        }
        if (!self.url) {
          self.emit('error', new Error('Queue not found'));
          return cb('Queue not found');
        }
      });
      return this;
    };

    SqsQueueParallel.prototype.push = function(message, cb) {
      var self;
      if (message == null) {
        message = {};
      }
      self = this;
      this.connect(function(err) {
        var params;
        if (err) {
          return cb.apply(null, arguments);
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

    SqsQueueParallel.prototype["delete"] = function(receiptHandle, cb) {
      var self;
      self = this;
      this.connect(function(err) {
        if (err) {
          return cb.apply(null, arguments);
        }
        return self.client.deleteMessage({
          QueueUrl: self.url,
          ReceiptHandle: receiptHandle
        }, cb);
      });
      return this;
    };

    return SqsQueueParallel;

  })(events.EventEmitter);

}).call(this);
