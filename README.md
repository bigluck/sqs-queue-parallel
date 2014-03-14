# sqs-queue-parallel.js

sqs-queue-parallel is a node.js library build on top of Amazon AWS SQS with concurrency and parallel message poll support.

You can create a poll of SQS queue watchers and each one can receive 1+ messages from Amazon SQS.


# Example
```javascript
var SqsQueueParallel = require('sqs-queue-parallel');

var queue = new SqsQueueParallel({
	name: "sqs-test",
	maxNumberOfMessages: 4,
	concurrency: 2
});
queue.on('message', function (e, next)
{
	console.log('New message: ', e.metadata, e.data.MessageId)
	e.delete()
	e.next()
});
queue.on('error', function (err)
{
	console.log('There was an error: ', err);
});
```


# Download

You can download and install this library using Node Package Manager (npm):

	npm install sqs-queue-parallel --save


# Summary

* Constructor:
	* new SqsQueueParallel(options = {})
* Methods:
	* push(message = {}, callback)
	* delete(receiptHandle, callback)
* Properties:
	* client
	* url
* Events:
	* connection
	* message
	* error

* Global env:
	* AWS_REGION
	* AWS_ACCESS_KEY
	* AWS_SECREY_KEY



# Constructor

## new SqsQueueParallel(options = {})

First you need to initialize a new object instance with a configuration.

**Examples:**

Constructing an object
```javascript
var queue = new SqsQueueParallel({ name: 'sqs-test' });
```

**Options Hash (options):**

* **name** (String) — **_Required_**: name of the remote queue to be watched
* **region** (String) — the region to send/read service requests. Default is `process.env.AWS_REGION`
* **accessKeyId** (String) — your AWS access key ID. Default is `process.env.AWS_ACCESS_KEY`
* **secretAccessKey** (String) — your AWS secret access key. Default is `process.env.AWS_SECRET_KEY`
* **visibilityTimeout** (Integer) — duration (in seconds) that the received messages are hidden from subsequent retrieve requests after being retrieved by a ReceiveMessage request. Default is 30
* **waitTimeSeconds** (Integer) — duration (in seconds) for which the call will wait for a message to arrive in the queue before returning. If a message is available, the call will return sooner than WaitTimeSeconds. Default is 20
* **maxNumberOfMessages** (Integer) — maximum number of messages to return. Amazon SQS never returns more messages than this value but may return fewer. Default is 1
* **concurrency** (Integer) — number of concurrency fetcher to start. Default is 1
* **debug** (Boolean) — enable debug mode. Default is true


**Important**:

Each `concurrency` queue can read `maxNumberOfMessages` messages from Amazon SQS.

For example, **2** `concurrency` queue with **5** `maxNumberOfMessages` can trigger a max of **5 * 2 = 10** `message` events; so it's very important to be carefull, expecially if you're working with I/O streams.


# Properties

## queue.client

Returns the SQS client object used by the queue.

## queue.url

Url of the connected queue.


# Methods

## queue.push(params = {}, callback)

Build on the top of `SQS.sendMessage()` allow you to easly push a message to the connected queue.

**Parameters:**

* **params** (Object)
	* body (Any type) — default to {}
	
		An arbitrary message, could be a string, a number or a object.
	* delay (Integer)
	
		The number of seconds (0 to 900 - 15 minutes) to delay a specific message. Messages with a positive DelaySeconds value become available for processing after the delay time is finished. If you don't specify a value, the default value for the queue applies

**Callback (callback):**

`function(err, data) {} `

For more information take checkout the [official AWS documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#sendMessage-property).

**Esample:**

```javascript
var SqsQueueParallel = require('src/sqs-queue-parallel');

var queue = new SqsQueueParallel({ name: "sqs-test" });
queue.push({
	body: 'my message',
	delay: 10	
});
queue.push({
	body: [1, 2, 3]
}, function (err, data)
{
	if (err)
		console.log('There was a problem: ', err);
	else
		console.log('Item pushed', data);
});
```


## queue.delete(receiptHandle, callback)

Build on the top of `SQS.deleteMessage()` allow you to easly delete a message from the connected queue.

**Parameters:**

* **receipHandler** (String)

	The receipt handle associated with the message to delete.

**Callback (callback):**

`function(err, data) {} `

For more information take checkout the official [AWS documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#deleteMessage-property).

**Esample:**

```javascript
var SqsQueueParallel = require('src/sqs-queue-parallel');

var queue = new SqsQueueParallel({ name: "sqs-test" });
queue.delete('receipt-handle-to-delete-1');
queue.delete('receipt-handle-to-delete-2'); function (err, data)
{
	if (err)
		console.log('There was a problem: ', err);
	else
		console.log('Item deleted', data);
});
```

# Events

## connection

`function(client, url) { }`

* **client** (Object): SQS client object used by the queue
* **url** (Object): url of the connected queue.

## message

`function(message) { }`

SqsQueueParallel emit an `message` event each time a new message has been received from the queue.

* **message** (Object)
	* type (String): default is "Message"
	* data (Unknown): JSON.parsed message.Body or a string (if could not be parsed)
	* message (Object): reference to the received message
	* metadata (Object): reference to the metadata of the received message
	* url (String): url of the connected queue
	* delete(callback) (Function):
	
		Helper to delete (or `SQS.deleteMessage()`) this message; `callback` is the same of the public `delete()` method
	* push(params = {}, callback) (Function): push a new message in the queue
	* **next()** (Function): call this method when you've completed your jobs in the event callback.

## error

`function(error) { }`
