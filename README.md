# RabbitMQ Web Dispatch

## This was migrated to https://github.com/rabbitmq/rabbitmq-server

This repository has been moved to the main unified RabbitMQ "monorepo", including all open issues. You can find the source under [/deps/rabbitmq_web_dispatch](https://github.com/rabbitmq/rabbitmq-server/tree/master/deps/rabbitmq_web_dispatch).
All issues have been transferred.

## Introduction

rabbitmq-web-dispatch is a thin veneer around Cowboy that provides the
ability for multiple applications to co-exist on Cowboy
listeners. Applications can register static document roots or dynamic
handlers to be executed, dispatched by URL path prefix.

See

 * [Management plugin guide](https://www.rabbitmq.com/management.html)
 * [Web STOMP guide](https://www.rabbitmq.com/web-stomp.html)
 * [Web MQTT guide](https://www.rabbitmq.com/web-mqtt.html)

for information on configuring plugins that expose an HTTP or WebSocket interface.
