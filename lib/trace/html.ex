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
    </style>
    <script>
    function toHex(n) {
      // Determine minimum width based on value range
      let width = 2;  // Default for small numbers
      if (n > 0xFFFF) width = 8;  // For 32-bit numbers
      else if (n > 0xFF) width = 4;  // For 16-bit numbers
      return '0x' + n.toString(16).padStart(width, '0');
    }

    function toggleFormat() {
      const isHex = document.body.classList.toggle('hex');
      const btn = document.getElementById('toggleBtn');
      btn.textContent = isHex ? 'Show Decimal' : 'Show Hex';

      const pres = document.getElementsByTagName('pre');
      for (const pre of pres) {
        pre.innerHTML = pre.innerHTML.replace(/\\b(0x[0-9a-f]+|\\d+)\\b/gi, match => {
          if (match.startsWith('0x')) {
            // Convert hex to decimal
            return parseInt(match.slice(2), 16).toString();
          } else {
            // Convert decimal to hex with appropriate padding
            return toHex(parseInt(match));
          }
        });
      }
    }
    </script>
    </head>
    <body>
    <button id="toggleBtn" onclick="toggleFormat()">Show Hex</button>
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
