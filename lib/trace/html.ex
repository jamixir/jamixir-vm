defmodule PVM.Trace.HTML do
  @html_file "pvm_trace.html"

  def init do
    # First clear the file
    File.write!(@html_file, "")

    # Then append the header
    html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="color-scheme" content="dark light">
    <style>
    @media (prefers-color-scheme: dark) {
      body {
        background: #1e1e1e;
        color: #d4d4d4;
      }
      .header { color: #569cd6; }
      .instruction { color: #dcdcaa; }
      .data { color: #4ec9b0; }
      .branch { color: #c586c0; }
      .state { color: #9cdcfe; }
    }
    @media (prefers-color-scheme: light) {
      body {
        background: #ffffff;
        color: #000000;
      }
      .header { color: #0000ff; }
      .instruction { color: #795e26; }
      .data { color: #267f99; }
      .branch { color: #af00db; }
      .state { color: #001080; }
    }
    body {
      font-family: monospace;
      padding: 20px;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
    }
    </style>
    </head>
    <body>
    """
    File.write!(@html_file, html, [:append, :utf8])
  end

  def write_line(class, message) do
    escaped_message = String.replace(message, "<", "&lt;")
    |> String.replace(">", "&gt;")
    html_line = "<pre class='#{class}'>#{escaped_message}</pre>\n"
    File.write!(@html_file, html_line, [:append, :utf8])
  end

  def close do
    File.write!(@html_file, "</body></html>", [:append, :utf8])
  end
end
