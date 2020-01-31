defmodule Stamper.Utils do
  @moduledoc false

  @doc """
    генерит uid необходимой длины.
    принимаемый параметр length длина
  """
  @spec uid(non_neg_integer()) :: String.t()
  def uid(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64()
    |> binary_part(0, length)
    |> String.replace("/", "")
  end
end
