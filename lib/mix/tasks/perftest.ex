defmodule Mix.Tasks.Perftest do
  @shortdoc "Simple perftest tool for RabbitMQ clusters"

  @moduledoc false

  use Mix.Task

  # --- public functions
  @impl true
  @spec run([binary()]) :: :ok
  def run([n, size, n_of_producers, n_of_connections, n_of_channels] = args) do
    Mix.shell().info("Starting perftest with #{inspect(args)} ...")

    {n, ""} = Integer.parse(n)
    {size, ""} = Integer.parse(size)
    {n_of_producers, ""} = Integer.parse(n_of_producers)
    {n_of_connections, ""} = Integer.parse(n_of_connections)
    {n_of_channels, ""} = Integer.parse(n_of_channels)

    channels = open_channels(amqp_url(), n_of_connections, n_of_channels)
    :ok = declare_exchange(channels |> hd())

    {time, _} =
      :timer.tc(fn ->
        publish_messages(channels, n, size, n_of_producers)
      end)

    Mix.shell().info(
      "Published #{n} messages in #{time} microsecs (#{trunc(n / time * 1_000_000)} messages/sec)"
    )

    :ok
  end

  def run([]), do: Mix.shell().info(usage())

  # --- private functions

  defp usage do
    """
    perftest <n> <size> <producers> <connections> <channels>

    n - number of messages to publish
    size - size of every message in bytes
    producers - number of concurrent producer tasks
    connections - number of connections
    channels - number of channels
    """
  end

  defp amqp_url do
    System.get_env("RABBITMQ_URL") || "amqp://guest:guest@localhost"
  end

  defp open_channels(url, n_of_connections, n_of_channels) do
    1..n_of_connections
    |> Enum.map(fn _ ->
      {:ok, conn} = AMQP.Connection.open(url)

      1..n_of_channels
      |> Enum.map(fn _ ->
        {:ok, chan} = AMQP.Channel.open(conn)
        chan
      end)
    end)
    |> List.flatten()
  end

  defp exchange_name(), do: "perftest"
  defp queue_name(), do: "perftest"

  defp declare_exchange(channel) do
    ex_opts = [auto_delete: true, durable: true]
    :ok = AMQP.Exchange.declare(channel, exchange_name(), :topic, ex_opts)

    arguments = [{"x-max-length", :long, 1}]
    q_opts = [auto_delete: true, arguments: arguments]
    {:ok, _queue} = AMQP.Queue.declare(channel, queue_name(), q_opts)

    :ok = AMQP.Queue.bind(channel, queue_name(), exchange_name(), routing_key: "#")
    :ok
  end

  defp publish_messages(channels, n, size, n_of_producers) do
    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - Sending #{n} messages of size #{size} ...")
    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - Starting #{n_of_producers} tasks ...")

    batch_size = trunc(n / n_of_producers)

    pids =
      1..n_of_producers
      |> Enum.map(fn _ ->
        Task.async(fn ->
          for _ <- 1..batch_size do
            AMQP.Basic.publish(
              channels |> Enum.random(),
              exchange_name(),
              "",
              size |> Randomizer.randomizer()
            )
          end
        end)
      end)

    _task_results = Task.await_many(pids, :infinity)
    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - ... #{n_of_producers} tasks finished!")
    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - Waiting for inboxes to empty ...")
    :ok = await_inboxes_empty()
    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - ... inboxes empty!")
  end

  defp await_inboxes_empty(), do: await_inboxes_empty({-1, self(), ""})

  defp await_inboxes_empty({0, _, _}), do: :ok

  defp await_inboxes_empty(_) do
    mqls =
      Process.list()
      |> Enum.map(fn pid ->
        {:registered_name, name} = pid |> Process.info(:registered_name)
        {:message_queue_len, mql} = pid |> Process.info(:message_queue_len)
        {mql, pid, name}
      end)
      |> Enum.sort(:desc)

    Mix.shell().info("#{DateTime.now!("Etc/UTC")} - Draining #{inspect(mqls |> hd)} ...")
    Process.sleep(1000)
    await_inboxes_empty(mqls |> hd)
  end
end
