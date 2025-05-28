defmodule PVM.Trace do
  alias PVM.Trace.HTML
  require Logger
  use PVM.Encoder

  @default_log_file "pvm_trace.log"

  def enabled? do
    # Check if trace was enabled via config
    config_enabled = Application.get_env(:pvm, :trace, false)

    # Check if --trace-pvm flag was passed
    cli_enabled = System.get_env("MIX_TEST_PVM_TRACE") == "true"

    config_enabled || cli_enabled
  end

  def init_trace_file(trace_name \\ nil) do
    if enabled?() do
      # Use the provided trace_name or default if nil
      log_file = get_log_filename(trace_name)
      # html_file = get_html_filename(trace_name)

      # Store the current trace filenames in the process dictionary
      Process.put(:trace_log_file, log_file)
      # Process.put(:trace_html_file, html_file)

      File.write!(log_file, "")
      # HTML.init(html_file)
      Process.put(:trace_counter, 1)
    end
  end

  defp get_log_filename(nil), do: @default_log_file
  defp get_log_filename(name), do: "pvm_trace_#{name}.log"

  # defp get_html_filename(nil), do: "pvm_trace.html"
  # defp get_html_filename(name), do: "pvm_trace_#{name}.html"

  def instruction_executed(opcode, pc, post_state) do
    if enabled?() do
      counter = Process.get(:trace_counter, 1)

      counter_str = String.pad_leading("#{counter}", 5)
      pc_str = String.pad_leading("#{pc}", 5)

      regs = Enum.join(PVM.Registers.to_list(post_state.registers), " ")
      line = "#{counter_str}: PC #{pc_str} #{instruction_str(opcode)} g=#{post_state.gas} reg=[#{regs}]"

      log_file = Process.get(:trace_log_file) || @default_log_file
      File.write!(log_file, line <> "\n", [:append])
      # HTML.write_line(Process.get(:trace_html_file), "instruction", line)

      Process.put(:trace_counter, counter + 1)
    end
  end

  defp instruction_str(opcode), do: to_string(opcode) |> String.upcase() |> String.pad_trailing(20)

  defp pvm_hash(%PVM.State{} = state) do
    registers =
      PVM.Registers.to_list(state.registers) |> Enum.map(&e_le(&1, 8)) |> Enum.join(<<>>)

    pages = PVM.Memory.Util.pages_with_data(state.memory) |> Enum.sort()

    # Create a binary with each page's address and content
    pages_binary =
      pages
      |> Enum.map(fn page_num ->
        page_content = PVM.Memory.Util.get_page_binary(state.memory, page_num)

        <<page_num::32-little, page_content::binary>>
      end)
      |> Enum.join(<<>>)

    bin = <<registers::binary, state.gas::64-little, pages_binary::binary>>

    # 4. Compute Blake2b hash of the binary data
    hash = Blake2.hash2b(bin, 32)

    # 5. Format hash as a shortened string like "9724..2f0e"
    prefix = Base.encode16(binary_part(hash, 0, 2), case: :lower)
    suffix = Base.encode16(binary_part(hash, byte_size(hash), -2), case: :lower)

    "#{prefix}..#{suffix}"
  end

  def close_trace_file do
    if enabled?() do
      HTML.close(Process.get(:trace_html_file))
    end
  end
end
