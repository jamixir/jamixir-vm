defmodule PVM.Trace.HTML do
  @default_html_file "pvm_trace.html"

  def init(html_file \\ nil) do
    html_file = html_file || @default_html_file

    # First clear the file
    File.write!(html_file, "")

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
      .exit { color: #f44747; }
      button {
        background: #333333;
        color: #d4d4d4;
        border: 1px solid #569cd6;
      }
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
      .exit { color: #cd3131; }
      button {
        background: #ffffff;
        color: #000000;
        border: 1px solid #0000ff;
      }
    }
    body {
      font-family: monospace;
      padding: 20px;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
    }
    button {
      position: fixed;
      top: 10px;
      right: 10px;
      padding: 8px 16px;
      border-radius: 4px;
      cursor: pointer;
    }
    .hex-num { display: none; }
    .dec-num { display: inline; }
    body.hex .hex-num { display: inline; }
    body.hex .dec-num { display: none; }
    </style>
    <script>
    function toggleFormat() {
      const isHex = document.body.classList.toggle('hex');
      const btn = document.getElementById('toggleBtn');
      btn.textContent = isHex ? 'Show Decimal' : 'Show Hex';

      const pres = document.getElementsByTagName('pre');
      for (const pre of pres) {
        pre.innerHTML = pre.innerHTML.replace(/\b(0x[0-9a-f]+|[0-9]+)\b/gi, match => {
          if (match.startsWith('0x')) {
            // Convert hex to decimal using BigInt
            return BigInt(match).toString();
          } else {
            // Convert decimal to hex with appropriate padding
            return toHex(match);
          }
        });
      }
    }
    </script>
    </head>
    <body>
    <button id="toggleBtn" onclick="toggleFormat()">Show Hex</button>
    """

    File.write!(html_file, html, [:append, :utf8])
  end

  def write_line(html_file \\ nil, class, message) do
    html_file = html_file || @default_html_file

    # First escape any < or > characters
    escaped_message =
      String.replace(message, ~r/[<>]/, fn
        "<" -> "&lt;"
        ">" -> "&gt;"
      end)

    # Format numbers in both hex and decimal
    formatted_message =
      Regex.replace(~r/\b(\d+|0x[0-9a-fA-F]+)\b/, escaped_message, fn match ->
        number =
          if String.starts_with?(match, "0x") do
            {num, _} = Integer.parse(String.slice(match, 2..-1//1), 16)
            num
          else
            String.to_integer(match)
          end

        hex = "0x#{Integer.to_string(number, 16)}"
        "<span class='dec-num'>#{number}</span><span class='hex-num'>#{hex}</span>"
      end)

    html_line = "<pre class='#{class}'>#{formatted_message}</pre>\n"
    File.write!(html_file, html_line, [:append, :utf8])
  end

  def close(html_file \\ nil) do
    html_file = html_file || @default_html_file
    File.write!(html_file, "</body></html>", [:append, :utf8])
  end
end
