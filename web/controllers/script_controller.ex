defmodule Lightning.ScriptController do
  use Lightning.Web, :controller
  use Hound.Helpers

  plug :action

  def run(conn, _params) do
    script = _params["script"]
    data = _params["data"]

    hound_session

    result = script
      |> Enum.map(&parse/1)
      |> Enum.reduce(
        %{input: data, debug: [], output: %{}},
        fn (cmd, context) -> execute_command(context, cmd) end
      )

    IO.inspect result

    conn |> json result
  end

  def on_exit _ do
  end
  def setup _ do
  end

  def parse cmd do
    String.split(cmd)
  end

  def execute_command context, cmd do
    step_id = SecureRandom.urlsafe_base64(8)
    result = execute context, cmd

    filename = "screenshots/#{step_id}.png"
    screenshot_path = "priv/static/#{filename}"
    screenshot_url = "/#{filename}"
    take_screenshot(screenshot_path)
    step_debug = %{
      step_id: step_id,
      title: page_title(),
      screenshot_url: screenshot_url
    }

    (case result do
      [key, value] ->
        Dict.put(context, :output,
          Dict.get(context, :output) |> Dict.put(key, value)
        )
      _ -> context
    end)
      |> Dict.put(:debug, [step_debug | Dict.get(context, :debug)])
  end

  def select selector do
    execute_script("document.querySelector(\"#{selector}\").style.border = '3px solid red'")
  end

  def execute context, ["goto", url] do
    navigate_to(url)
  end

  def execute context, ["click", selector] do
    select selector

    find_element(:css, selector)
      |> click()
  end

  def execute context, ["enter", text, "in", selector] do
    select selector

    data = context[:input]
    IO.inspect(context)
    IO.inspect(data)
    normalized_text = Regex.replace(
      ~r/\:(\w+)/,
      text,
      fn (_, x) -> IO.inspect(x); data[x] end
    )
    find_element(:css, selector)
      |> fill_field(normalized_text)
  end

  def execute context, ["return", attr, "from", selector] do
    select selector

    value = find_element(:css, selector)
      |> visible_text()
    [attr, value]
  end
end
