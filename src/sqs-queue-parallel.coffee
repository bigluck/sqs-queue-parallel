AWS = require 'aws-sdk'
events = require 'events'
async = require 'async'
_ = require 'lodash'


module.exports = class SqsQueueParallel extends events.EventEmitter
	
	constructor: (config) ->
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
		, config or {}

		@client = null
		@url = null
		self = @

		readQueue = (index) ->
			return unless self.listeners("message").length and self.url
			async.waterfall [
				(next) ->
					console.log "SqsQueueParallel #{ self.config.name }[#{ index }]: waiting" if self.config.debug
					self.client.receiveMessage 
						QueueUrl: self.url
						MaxNumberOfMessages: self.config.maxNumberOfMessages
						VisibilityTimeout: self.config.visibilityTimeout
						WaitTimeSeconds: self.config.waitTimeSeconds
					, next
				(queue, next) ->
					return next() unless queue.Messages?[0]
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
						next()
			], (err) ->
				self.emit "error", arguments... if err
				process.nextTick ->
					readQueue index

		@addListener 'newListener', (e) ->
			return unless e is 'message'
			console.info "SqsQueueParallel #{ self.config.name }: new listener" if self.config.debug
			if not @client or @listeners("message").length is 1
				@connect (err) ->
					return if err
					return unless self.listeners("message").length and self.url
					_.times self.config.concurrency or 1, (index) ->
						readQueue index

	connect: (cb) ->
		unless @client and @url
			@once 'connection', ->
				cb()
		return if @client and not @url
		return cb null if @client
		self = @
		@client = new AWS.SQS
			region: @config.region or process.env.AWS_REGION
			accessKeyId: @config.accessKeyId or process.env.AWS_ACCESS_KEY
			secretAccessKey: @config.secretAccessKey or process.env.AWS_SECRET_KEY
		@client.listQueues
			QueueNamePrefix: @config.name
		, (err, data) ->
			if data.QueueUrls
				for url in data.QueueUrls when [match, name] = ( new RegExp "/[\\d]+/#{ self.config.name }$" ).exec url
					console.log "SqsQueueParallel #{ self.config.name }: connected with url `#{ url }`" if self.config.debug
					self.url = url
					self.emit 'connection',
						client: self.client
						url: url
			unless self.url
				self.emit 'error', new Error 'Queue not found'
				cb 'Queue not found'
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
