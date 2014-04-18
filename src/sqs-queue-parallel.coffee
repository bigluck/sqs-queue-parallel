AWS = require 'aws-sdk'
events = require 'events'
async = require 'async'
_ = require 'lodash'

globalConfig = {}

module.exports = class SqsQueueParallel extends events.EventEmitter
	@configure: (config={}) ->
		globalConfig = _.extend globalConfig, config
	constructor: (config={}) ->
		@config = _.extend
			region: process.env.AWS_REGION
			accessKeyId: process.env.AWS_ACCESS_KEY
			secretAccessKey: process.env.AWS_SECRET_KEY
			visibilityTimeout: null
			waitTimeSeconds: 20
			maxNumberOfMessages: 1
			name: ''
			concurrency: 1
			debug: false
		, globalConfig, config
		@client = null
		@url = null
		self = @

		readQueue = (index) ->
			return unless self.listeners("message").length and self.url
			async.waterfall [
				(next) ->
					console.log "SqsQueueParallel #{ self.config.name }[#{ index }]: waiting messages" if self.config.debug
					self.client.receiveMessage (
						options =
							QueueUrl: self.url
							MaxNumberOfMessages: self.config.maxNumberOfMessages
							WaitTimeSeconds: self.config.waitTimeSeconds
						options.VisibilityTimeout = self.config.visibilityTimeout if self.config.visibilityTimeout?
						options
					)
					, next
				(queue, next) ->
					return next null unless queue.Messages?[0]
					console.log "SqsQueueParallel #{ self.config.name }[#{ index }]: #{ queue.Messages.length } new messages" if self.config.debug
					async.eachSeries queue.Messages, (message, next) ->
						self.emit "message", 
							type: 'message'
							data: JSON.parse(message.Body) or message.Body
							message: message
							metadata: queue.ResponseMetadata
							url: self.url
							name: self.config.name
							next: next
							deleteMessage: (cb) ->
								next()
								self.deleteMessage message.ReceiptHandle, cb
							delay: (timeout, cb) ->
								self.changeMessageVisibility message.ReceiptHandle, timeout, cb
							changeMessageVisibility: (timeout, cb) ->
								next()
								self.changeMessageVisibility message.ReceiptHandle, timeout, cb
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
	sendMessage: (message={}, cb=->) ->
		self = @
		@connect (err) ->
			return cb arguments... if err
			console.log "SqsQueueParallel #{ self.config.name }: before sendMessage with url `#{ self.url }`" if self.config.debug
			params =
				MessageBody: JSON.stringify message.body or {}
				QueueUrl: self.url
			params.DelaySeconds = message.delay if message.delay?
			self.client.sendMessage params, cb
		@
	deleteMessage: (receiptHandle, cb=->) ->
		self = @
		@connect (err) ->
			return cb arguments... if err
			console.log "SqsQueueParallel #{ self.config.name }: before deleteMessage #{ receiptHandle } with url `#{ self.url }`" if self.config.debug
			self.client.deleteMessage
				QueueUrl: self.url
				ReceiptHandle: receiptHandle
			, cb
		@
	changeMessageVisibility: (receiptHandle, timeout=30, cb=->) ->
		self = @
		@connect (err) ->
			return cb arguments... if err
			console.log "SqsQueueParallel #{ self.config.name }: before changeMessageVisibility #{ receiptHandle } with url `#{ self.url }`" if self.config.debug
			self.client.changeMessageVisibility
				QueueUrl: self.url
				ReceiptHandle: receiptHandle
				VisibilityTimeout: timeout
			, cb
		@
