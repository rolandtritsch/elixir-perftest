# A simple Rabbit MQ perftest

The gold standard to run a perftest againt a Rabbit MQ cluster is (you
guessed it): [perftest][].

This is a very small `mix task` that allows you to kind-a do the same
with `elixir`, just to make sure whatever you do in your elixir app
is as fast as it can be.

## Setup

To make this work you need to ...

* install [asdf][]
* run `asdf install erlang latest && asdf local erlang latest`
* run `asdf install elixir latest && asdf local elixir latest`
* run `mix deps.get && mix perftest`

## Running it

```bash
export RABBITMQ_URL=amqps://<username>:<password>@<hostname>:5671&verify=verify_none
mix perftest 1000 100 1 1 1 1 classic
```

This will run a perftest against the cluster you have specified with ...

* 1000 messages
* of size 100 bytes
* with 1 producer (task)
* using 1 connection
* using 1 channel (per connection)
* creating a queue with a `x-max-length` of 1 (you can increase this value to
  make the cluster keep more messages in mem, thus creating back-pressure that
  will then put the channels into `flow`)
* using a `classic` queue (with `quorum` being the other option)

Note: The pool of tasks will randomly use one of the channels from the
pool of connections.

Other notable (hard-coded) configurations are ...

* We are creating a `durable`, `topic` exchange with `auto_delete:true`
* We are creating a queue with `auto_delete:true`
  * ... and bind it to the exchange with `routing_key:#`
  * This will simulate that the messages get consumed (see also how
  to configure `x-max-length` above)
  * You can make [perftest][] behave the same way with `--consumers 0`
* We create the channels with `publish_confirm:false` (the default)
* We publish the messages with `persistent:false` (the default)

Note: With `publish_confirm:false` we need to wait for the inboxes of 
the channel gen_servers to get drained, before we can call it a day.

## Compare to [perftest][]

Afterwards you can run perfest against the same exchange/queue with ...

```bash
export URI=amqps://<username>:<password>@<hostname>:5671&verify=verify_none
docker run --interactive --tty --rm --env URI pivotalrabbitmq/perf-test:latest --producers 1 --producer-channel-count 1 --consumers 0 --consumer-channel-count 0 --size 2000 --time 10 --id "1:1:0:0:2000:a" --autoack --type topic --exchange perftest
```

[asdf]: https://asdf-vm.com/
[perftest]: https://rabbitmq.github.io/rabbitmq-perf-test/stable/htmlsingle/
