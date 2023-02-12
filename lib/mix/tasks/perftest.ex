defmodule Mix.Tasks.Perftest do
  @shortdoc "Simple perftest tool for RabbitMQ clusters"

  @moduledoc false

  use Mix.Task

  # --- public functions
  @impl true
  @spec run([binary()]) :: :ok
  def run([n, size, producers, connections, channels] = args) do
    Mix.shell().info("Starting perftest with #{inspect(args)} ...")

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
end
