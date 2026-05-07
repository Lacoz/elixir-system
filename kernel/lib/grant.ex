defmodule Grant do
  @moduledoc false
  @enforce_keys [:principal_id, :capability, :partitions, :permissions, :valid_until]
  defstruct [:principal_id, :capability, :partitions, :permissions, :valid_until, :inserted_at]

  @type t :: %__MODULE__{
          principal_id: String.t(),
          capability: atom(),
          partitions: [String.t()] | :all,
          permissions: [atom()],
          valid_until: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil
        }
end
