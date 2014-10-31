SqsQueueParallel = require 'src/sqs-queue-parallel'

queue = new SqsQueueParallel
	name: "sqs-test"
	maxNumberOfMessages: 4
	concurrency: 2

queue.on 'message', (e) ->
	console.log 'New message: ', e.metadata, e.data.MessageId
	e.deleteMessage()
	e.next()

queue.on 'error', (err) ->
	console.log 'There was an error: ', err
