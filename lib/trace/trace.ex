defmodule PVM.Trace do
  alias PVM.Trace.HTML

  @default_log_file "pvm_trace.log"

  def enabled? do
    # Check if trace was enabled via config
    config_enabled = Application.get_env(:pvm, :trace, false)

    # Check if --trace-pvm flag was passed
    cli_enabled = System.get_env("MIX_TEST_PVM_TRACE") == "true"

    # Enable if either method is used
    config_enabled || cli_enabled
  end

  def init_trace_file(trace_name \\ nil) do
    if enabled?() do
      # Use the provided trace_name or default if nil
      log_file = get_log_filename(trace_name)
      html_file = get_html_filename(trace_name)

      # Store the current trace filenames in the process dictionary
      Process.put(:trace_log_file, log_file)
      Process.put(:trace_html_file, html_file)

      File.write!(log_file, "")
      HTML.init(html_file)
      Process.put(:trace_counter, 1)
    end
  end

  defp get_log_filename(nil), do: @default_log_file
  defp get_log_filename(name), do: "pvm_trace_#{name}.log"

  defp get_html_filename(nil), do: "pvm_trace.html"
  defp get_html_filename(name), do: "pvm_trace_#{name}.html"

  def write_line(class, message) do
    if enabled?() do
      # Only add counter for instruction starts (PC lines)
      {prefix, new_counter} =
        if String.contains?(message, "PC:") do
          counter = Process.get(:trace_counter)
          {"#{counter}. ", counter + 1}
        else
          {"", Process.get(:trace_counter)}
        end

      line = prefix <> message
      log_file = Process.get(:trace_log_file) || @default_log_file
      File.write!(log_file, line <> "\n", [:append])
      HTML.write_line(Process.get(:trace_html_file), class, line)

      Process.put(:trace_counter, new_counter)
    end
  end

  def instruction_start(pc, type) do
    if enabled?() do
      write_line("header", "\n----------------------------------------")
      write_line("header", "PC: #{pc} Executing #{type}")
    end
  end

  def instruction_data(type, lines) when is_list(lines) do
    if enabled?() do
      Enum.each(lines, fn line ->
        write_line("instruction", "#{type}: #{line}")
      end)
    end
  end

  # For backwards compatibility
  def instruction(pc, type, data \\ nil) when is_integer(pc) do
    instruction_start(pc, type)
    if data, do: write_line("instruction", "#{type}: #{data}")
  end

  def branch(from, to) do
    if enabled?() do
      write_line("branch", "branch: Branching to PC #{to} step #{to - from}")
    end
  end

  def djump(from, to) do
    if enabled?() do
      write_line("branch", "djump: Djumping to PC #{to} step #{to - from}")
    end
  end

  def state_change(registers, memory_chunks, gas) do
    if enabled?() do
      write_line("state", "New Gas: #{gas}")
      write_line("state", "New Registers: #{inspect(registers)}")

      Enum.each(memory_chunks, fn chunk ->
        write_line("state", "New Memory chunk: #{inspect(chunk)}")
      end)

      write_line("header", "------------------------------")
    end
  end

  def close_trace_file do
    if enabled?() do
      HTML.close(Process.get(:trace_html_file))
    end
  end
end
