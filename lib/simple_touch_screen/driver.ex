defmodule SimpleTouchScreen.Driver do
  use Scenic.ViewPort.Driver

  require Logger

  def init(viewport, {_, _}, opts) do
    {path, _} =
      InputEvent.enumerate()
      |> Enum.find(fn {_, %{name: name}} -> name == opts[:device] end)

    InputEvent.start_link(path)

    {:ok, %{path: path, x: 0, y: 0, viewport: viewport, calibration: opts[:calibration]}}
  end

  def handle_info({:input_event, path, events}, %{path: path, x: x, y: y} = state) do
    state =
      events
      |> Enum.reduce(%{touch: nil, x: x, y: y}, fn
        {:ev_abs, :abs_x, x}, event -> %{event | x: x}
        {:ev_abs, :abs_y, y}, event -> %{event | y: y}
        {:ev_key, :btn_touch, touch}, event -> %{event | touch: touch}
        _, event -> event
      end)
      |> case do
        %{touch: 1, x: x, y: y} ->
          pos = calibrate(state.calibration, {x, y})
          Logger.debug("down #{inspect(pos)}")
          Scenic.ViewPort.input(state.viewport, {:cursor_button, {:left, :press, 0, pos}})
          %{state | x: x, y: y}

        %{touch: 0, x: x, y: y} ->
          pos = calibrate(state.calibration, {x, y})
          Logger.debug("up #{inspect(pos)}")
          Scenic.ViewPort.input(state.viewport, {:cursor_button, {:left, :release, 0, pos}})
          %{state | x: x, y: y}

        %{x: x, y: y} ->
          pos = calibrate(state.calibration, {x, y})
          Logger.debug("move #{inspect(pos)}")
          Scenic.ViewPort.input(state.viewport, {:cursor_pos, pos})
          %{state | x: x, y: y}

        event ->
          Logger.debug("unknown event #{inspect(event)}")
          state
      end

    {:noreply, state}
  end

  defp calibrate({{ax, bx, dx}, {ay, by, dy}}, {x, y}) do
    {
      ax * x + bx * y + dx,
      ay * x + by * y + dy
    }
  end
end
