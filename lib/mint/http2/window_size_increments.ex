defmodule Mint.HTTP2.WindowSizeIncrements do
  @moduledoc "TODO"

  import Mint.HTTP2.Frame, only: [window_update: 1, encode: 1]

  defstruct [connection: 0, streams: %{}]

  def new, do: %__MODULE__{}

  def increment_stream(window_size_increments, _stream_id, 0) do
    window_size_increments
  end

  def increment_stream(window_size_increments, stream_id, size_increment) do
    # When refilling a stream, refill the connection too.
    %__MODULE__{
      window_size_increments |
        streams: Map.update(window_size_increments.streams, stream_id, size_increment, &(&1 + size_increment)),
        connection: window_size_increments.connection + size_increment
    }
  end

  def discard_stream(window_size_increments, stream_id) do
    # Remove the size increment for the stream but keep the size
    # increment for the connection.
    %__MODULE__{window_size_increments | streams: Map.delete(window_size_increments.streams, stream_id)}
  end

  def frames(%__MODULE__{connection: connection, streams: streams}) do
    if connection > 0 do
      stream_frames = Enum.map(streams, fn {stream_id, size_increment} ->
        frame = window_update(stream_id: stream_id, window_size_increment: size_increment)
        encode(frame)
      end)

      connection_frame = window_update(stream_id: 0, window_size_increment: connection)

      [encode(connection_frame) | stream_frames]
    else
      []
    end
  end
end
