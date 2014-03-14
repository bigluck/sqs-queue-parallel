AWS = require 'aws-sdk'
events = require 'events'
async = require 'async'
_ = require 'lodash'

module.exports = class SqsQueueParallel extends events.EventEmitter
	constructor: (config={}) ->
		@config = _.extend
			region: process.env.AWS_REGION
			accessKeyId: process.env.AWS_ACCESS_KEY
			secretAccessKey: process.env.AWS_SECRET_KEY
			visibilityTimeout: 30
			waitTimeSeconds: 20
			maxNumberOfMessages: 1
			name: ''
			concurrency: 1
			debug: true
		, config
		@client = null
		@url = null
		self = @

		readQueue = (index) ->
			return unless self.listeners("message").length and self.url
			async.waterfall [
				(next) ->
					console.log "SqsQueueParallel #{ self.config.name }[#{ index }]: waiting messages" if self.config.debug
					self.client.receiveMessage 
						QueueUrl: self.url
						MaxNumberOfMessages: self.config.maxNumberOfMessages
						VisibilityTimeout: self.config.visibilityTimeout
						WaitTimeSeconds: self.config.waitTimeSeconds
					, next
				(queue, next) ->
					return next null unless queue.Messages?[0]
					console.log "SqsQueueParallel #{ self.config.name }[#{ index }]: #{ queue.Messages.length } new messages" if self.config.debug
					async.eachSeries queue.Messages, (message, cb) ->
						self.emit "message", 
							type: 'message'
							data: JSON.parse(message.Body) or message.Body
							message: message
							metadata: queue.ResponseMetadata
							url: self.url
							delete: (cb) ->
								console.log 'before delete: ', message
								self.delete message.ReceiptHandle, cb
							next: cb
					, ->
						next null
			], (err) ->
				self.emit "error", arguments... if err
				process.nextTick ->
					readQueue index

		@addListener 'newListener', (name) ->
			return unless name is 'message'
			console.info "SqsQueueParallel #{ self.config.name }: new listener" if self.config.debug
			if not @client or @listeners("message").length is 1
				@connect (err) ->
					return if err or not self.url or not self.listeners("message").length
					_.times self.config.concurrency or 1, (index) ->
						readQueue index
		if @config.debug
			@on 'connection', (urls) ->
				console.log "SqsQueueParallel: connection to SQS", urls
			@on 'connect', ->
				console.log "SqsQueueParallel #{ self.config.name }: connected with url `#{ self.url }`"
			@on 'error', (e) ->
				console.log "SqsQueueParallel #{ self.config.name }: connection failed", e
	connect: (cb) ->
		unless @client and @url
			@once 'connect', ->
				cb null
			return if @client and not @url
		return cb null if @client
		self = @
		@client = new AWS.SQS
			region: @config.region
			accessKeyId: @config.accessKeyId
			secretAccessKey: @config.secretAccessKey
		async.waterfall [
			(next) ->
				self.client.listQueues
					QueueNamePrefix: self.config.name
				, next
			(data, next) -> 
				re = new RegExp "/[\\d]+/#{ self.config.name }$"
				self.emit 'connection', data.QueueUrls
				self.emit 'connect', self.url = url for url in data.QueueUrls when re.test url
				unless self.url
					self.emit 'error', new Error 'Queue not found'
					next 'Queue not found'
		], (err) ->
			return unless err
			self.emit 'error', err
			cb arguments...
		@
	push: (message={}, cb) ->
		self = @
		@connect (err) ->
			return cb arguments... if err
			params =
				MessageBody: JSON.stringify message.body or {}
				QueueUrl: self.url
			params.DelaySeconds = message.delay if message.delay?
			self.client.sendMessage params, cb
		@
	delete: (receiptHandle, cb) ->
		self = @
		@connect (err) ->
			return cb arguments... if err
			self.client.deleteMessage
				QueueUrl: self.url
				ReceiptHandle: receiptHandle
			, cb
		@
