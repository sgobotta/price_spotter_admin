defmodule PriceSpotter.Seeds.Users do
  @moduledoc """
  Seeds for the User model
  """

  use PriceSpotter.Seeds.Utils,
    repo: PriceSpotter.Repo,
    json_file: "#{__DIR__}/users.json",
    plural_element: "users",
    element_module: PriceSpotter.Accounts.User,
    date_keys: [:confirmed_at, :inserted_at, :updated_at]
end
