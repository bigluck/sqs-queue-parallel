# sqs-queue-parallel.js

sqs-queue-parallel is a **node.js** library build on top of **Amazon AWS SQS** with **concurrency and parallel** message poll support.

You can create a poll of SQS queue watchers, each one can receive 1 or more messages from Amazon SQS.

With sqs-queue-parallel you need just to configure your AWS private keys, setup your one o more `message` event callbacks and wait for new messages to be processed.



# Example

```javascript
var SqsQueueParallel = require('sqs-queue-parallel');

// Simple configuration:
//  - 2 concurrency listeners
//  - each listener can receive up to 4 messages
// With this configuration you could receive and parse 8 `message` events in parallel
var queue = new SqsQueueParallel({
	name: "sqs-test",
	maxNumberOfMessages: 4,
	concurrency: 2
});
queue.on('message', function (e, next)
{
	console.log('New message: ', e.metadata, e.data.MessageId)
	e.deleteMessage()
});
queue.on('error', function (err)
{
	console.log('There was an error: ', err);
});
```


# Download

You can download and install this library using Node Package Manager (npm):

```bash
npm install sqs-queue-parallel --save
```


# Summary

* [Constructor](#constructor):
	* new SqsQueueParallel(options = {})
* [Methods](#methods):
	* sendMessage(message = {}, callback)
	* deleteMessage(receiptHandle, callback)
	* changeMessageVisibility(receiptHandle, timeout, callback)
* [Properties](#properties):
	* client
	* url
* [Events](#events):
	* connection
	* connect
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
* **visibilityTimeout** (Integer) — duration (in seconds) that the received messages are hidden from subsequent retrieve requests after being retrieved by a ReceiveMessage request.
* **waitTimeSeconds** (Integer) — duration (in seconds) for which the call will wait for a message to arrive in the queue before returning. If a message is available, the call will return sooner than WaitTimeSeconds. Default is 20
* **maxNumberOfMessages** (Integer) — maximum number of messages to return. Amazon SQS never returns more messages than this value but may return fewer. Default is 1
* **concurrency** (Integer) — number of concurrency fetcher to start. Default is 1
* **debug** (Boolean) — enable debug mode. Default is false


**Important**:

Each `concurrency` queue can read `maxNumberOfMessages` messages from Amazon SQS.

For example, **2** `concurrency` queue with **5** `maxNumberOfMessages` can trigger a max of **5 * 2 = 10** `message` events; so it's very important to be carefull, expecially if you're working with I/O streams.



# Properties


## queue.client

Returns the SQS client object used by the queue.


## queue.url

Url of the connected queue.



# Methods


## queue.sendMessage(params = {}, callback)

Build on the top of `SQS.sendMessage()` allow you to easly push a message to the connected queue.

**Parameters:**

* **params** (Object)
	* body (Any type) — default to {}
	
		An arbitrary message, could be a string, a number or a object.
	* delay (Integer)
	
		The number of seconds (0 to 900 - 15 minutes) to delay a specific message. Messages with a positive DelaySeconds value become available for processing after the delay time is finished. If you don't specify a value, the default value for the queue applies

**Callback (callback):**

```javascript
function(err, data) {}
```

For more information take checkout the [official AWS documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#sendMessage-property).

**Esample:**

```javascript
var SqsQueueParallel = require('src/sqs-queue-parallel');

var queue = new SqsQueueParallel({ name: "sqs-test" });
queue.sendMessage({
	body: 'my message',
	delay: 10
});
queue.sendMessage({
	body: [1, 2, 3]
}, function (err, data)
{
	if (err)
		console.log('There was a problem: ', err);
	else
		console.log('Item pushed', data);
});
```


## queue.changeMessageVisibility(receiptHandle, timeout, callback)

Build on the top of `SQS.changeMessageVisibility()` allow you to easly delay a message from the connected queue.

**Parameters:**

* **receipHandler** (String)

	The receipt handle associated with the message to delay.

* **timeout** (Integer)

	The new value (in seconds - from 0 to 43200 - maximum 12 hours) for the message's visibility timeout.

**Callback (callback):**

```javascript
function(err, data) {}
```

For more information take checkout the official [AWS documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#changeMessageVisibility-property).

**Esample:**

```javascript
var SqsQueueParallel = require('src/sqs-queue-parallel');

var queue = new SqsQueueParallel({ name: "sqs-test" });
queue.changeMessageVisibility('receipt-handle-to-delay-1', 30);
queue.on('message', function (job)
{
	if (myTest is true)
		job.deleteMessage();
	else
		job.changeMessageVisibility(30);
	job.next();
});
```


## queue.deleteMessage(receiptHandle, callback)

Build on the top of `SQS.deleteMessage()` allow you to easly delete a message from the connected queue.

**Parameters:**

* **receipHandler** (String)

	The receipt handle associated with the message to delete.

**Callback (callback):**

```javascript
function(err, data) {}
```

For more information take checkout the official [AWS documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#deleteMessage-property).

**Esample:**

```javascript
var SqsQueueParallel = require('src/sqs-queue-parallel');

var queue = new SqsQueueParallel({ name: "sqs-test" });
queue.deleteMessage('receipt-handle-to-delete-1');
queue.on('message', function (job)
{
	if (myTest is true)
		job.deleteMessage();
});
```



# Events


## connection

```javascript
function(urls) { }
```

Triggered when a connection is established with the remote server.

* **urls** (Array): list of all remotes urls


## connect

```javascript
function(url) { }
```

Triggered when the required queue `name` is found in the remote list of queues.

* **url** (Object): url of the connected queue


## message

```javascript
function(message) { }
```

Event triggered each time a new message has been received from the remote queue.

* **message** (Object)
	* type (String): default is "Message"
	* data (Unknown): JSON.parsed message.Body or a string (if could not be parsed)
	* message (Object): reference to the received message
	* metadata (Object): reference to the metadata of the received message
	* name (String): name of the remote queue
	* url (String): url of the connected queue
	* **deleteMessage(callback)** (Function):
	
		Helper to deleteMessage (or `SQS.deleteMessage()`) when the job is completed; `callback` is the same of the public `deleteMessage()` method
	* **changeMessageVisibility(timeout, callback)** (Function):
	
		Helper to changeMessageVisibility (or `SQS.changeMessageVisibility()`) when the job is completed; `callback` is the same of the public `changeMessageVisibility()` method
	* **delay(timeout, callback)** (Function):
	
		Helper to changeMessageVisibility (or `SQS.changeMessageVisibility()`) without completing the job; `callback` is the same of the public `changeMessageVisibility()` method
	* **sendMessage(params = {}, callback)** (Function): send a new message in the queue
	* **next()** (Function): call this method when you've completed your jobs in the event callback.


## error

```javascript
function(error) { }
```



# License

(The MIT License)

Copyright (c) 2014 Luca Bigon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
