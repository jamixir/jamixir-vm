defmodule PVM.Trace do
  alias PVM.Trace.HTML

  @log_file "pvm_trace.log"

  def enabled? do
    # Check if trace was enabled via config
    config_enabled = Application.get_env(:pvm, :trace, false)

    # Check if --trace-pvm flag was passed
    cli_enabled = System.get_env("MIX_TEST_PVM_TRACE") == "true"

    # Enable if either method is used
    config_enabled || cli_enabled
  end

  def init_trace_file do
    if enabled?() do
      # Clear log file
      File.write!(@log_file, "")
      HTML.init()
    end
  end

  def write_line(class, message) do
    if enabled?() do
      # Write plain text to log file
      File.write!(@log_file, message <> "\n", [:append])
      # Delegate HTML formatting to HTML module
      HTML.write_line(class, message)
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
      HTML.close()
    end
  end
end
