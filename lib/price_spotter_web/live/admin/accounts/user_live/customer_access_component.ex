defmodule PriceSpotterWeb.Admin.Accounts.UserLive.CustomerAccessComponent do
  use PriceSpotterWeb, :live_component

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Relations.UserSupplier

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :form_id, fn -> "customer-access-form" end)

    ~H"""
    <div>
      <.header>
        <%= gettext("Customer access") %>
        <:subtitle>
          <%= gettext(
            "Grant this user access to one or more suppliers. Add as many rows as you need, then save them all at once."
          ) %>
        </:subtitle>
      </.header>

      <table :if={@grants != []} class="mt-4 w-full text-sm">
        <thead>
          <tr class="text-left text-zinc-500 dark:text-zinc-400">
            <th class="pb-2"><%= gettext("Supplier") %></th>
            <th class="pb-2"><%= gettext("Role") %></th>
            <th class="pb-2"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={grant <- @grants}
            class="border-t border-zinc-200 dark:border-zinc-700"
          >
            <td class="py-2"><%= grant.supplier.name %></td>
            <td class="py-2"><%= grant.role %></td>
            <td class="py-2 text-right">
              <.link
                phx-click="remove_grant"
                phx-value-id={grant.id}
                phx-target={@myself}
                data-confirm={gettext("Remove this access?")}
                class="inline-flex text-rose-600 hover:text-rose-800"
              >
                <.icon name="hero-trash-solid" class="h-4 w-4" />
                <span class="sr-only"><%= gettext("Remove") %></span>
              </.link>
            </td>
          </tr>
        </tbody>
      </table>
      <p :if={@grants == []} class="mt-4 text-sm text-zinc-500 dark:text-zinc-400">
        <%= gettext("No supplier access granted yet.") %>
      </p>

      <form
        id={@form_id}
        phx-submit="save"
        phx-target={@myself}
        class="mt-6 space-y-3"
      >
        <div
          :for={row <- @draft_rows}
          class="rounded-lg border border-zinc-200 bg-zinc-100 p-3 dark:border-zinc-700 dark:bg-zinc-800/40"
        >
          <div class="flex items-start gap-2">
            <.input
              type="select"
              name={"rows[#{row.ref}][supplier_id]"}
              id={"row-#{row.ref}-supplier"}
              value={row.supplier_id}
              label={gettext("Supplier")}
              prompt={gettext("Choose a supplier")}
              options={@supplier_options}
              errors={row_errors(@row_errors, row.ref)}
              container_class="flex-1"
            />
            <.input
              type="select"
              name={"rows[#{row.ref}][role]"}
              id={"row-#{row.ref}-role"}
              value={row.role}
              label={gettext("Role")}
              prompt={gettext("Choose a role")}
              options={Ecto.Enum.values(UserSupplier, :role)}
              container_class="flex-1"
            />
            <button
              :if={length(@draft_rows) > 1}
              type="button"
              phx-click="remove_row"
              phx-value-ref={row.ref}
              phx-target={@myself}
              class="mt-7 text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200"
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
        </div>

        <div class="flex items-center justify-between gap-3">
          <button
            type="button"
            phx-click="add_row"
            phx-target={@myself}
            class="inline-flex items-center rounded-lg border border-dashed border-zinc-300 px-3 py-2 text-zinc-700 hover:border-zinc-400 hover:bg-zinc-200 dark:border-zinc-600 dark:text-zinc-200 dark:hover:border-zinc-500 dark:hover:bg-zinc-800"
          >
            <.icon name="hero-plus-solid" class="h-4 w-4" />
            <span class="sr-only"><%= gettext("Add another") %></span>
          </button>

          <.button phx-disable-with={gettext("Saving...")}>
            <%= gettext("Save access") %>
          </.button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:grants, Marketplaces.list_user_suppliers_for_user(user))
     |> assign(:draft_rows, [empty_row()])
     |> assign(:row_errors, %{})
     |> assign_supplier_options()}
  end

  @impl true
  def handle_event("add_row", _params, socket) do
    {:noreply, update(socket, :draft_rows, &(&1 ++ [empty_row()]))}
  end

  def handle_event("remove_row", %{"ref" => ref}, socket) do
    ref = String.to_integer(ref)

    {:noreply,
     update(socket, :draft_rows, fn rows ->
       Enum.reject(rows, &(&1.ref == ref))
     end)}
  end

  def handle_event("save", %{"rows" => rows_params}, socket) do
    rows_by_ref =
      Map.new(rows_params, fn {ref, attrs} ->
        {String.to_integer(ref), attrs}
      end)

    submitted_rows =
      Enum.map(socket.assigns.draft_rows, fn row ->
        attrs = Map.get(rows_by_ref, row.ref, %{})

        %{
          ref: row.ref,
          supplier_id: Map.get(attrs, "supplier_id", ""),
          role: Map.get(attrs, "role", "")
        }
      end)

    refs_and_attrs =
      submitted_rows
      |> Enum.map(&{&1.ref, &1})
      |> Enum.reject(fn {_ref, row} -> row.supplier_id in [nil, ""] end)

    refs = Enum.map(refs_and_attrs, fn {ref, _row} -> ref end)

    attrs_list =
      Enum.map(refs_and_attrs, fn {_ref, row} ->
        %{supplier_id: row.supplier_id, role: row.role}
      end)

    case Marketplaces.create_user_suppliers(socket.assigns.user, attrs_list) do
      {:ok, _user_suppliers} ->
        notify_parent(:customer_access_updated)

        {:noreply,
         socket
         |> assign(
           :grants,
           Marketplaces.list_user_suppliers_for_user(socket.assigns.user)
         )
         |> assign(:draft_rows, [empty_row()])
         |> assign(:row_errors, %{})}

      {:error, index, changeset} ->
        failing_ref = Enum.at(refs, index)

        {:noreply,
         socket
         |> assign(:draft_rows, submitted_rows)
         |> assign(:row_errors, %{failing_ref => changeset})}
    end
  end

  def handle_event("remove_grant", %{"id" => id}, socket) do
    grant = Marketplaces.get_user_supplier!(id)
    {:ok, _} = Marketplaces.delete_user_supplier(grant)

    {:noreply,
     assign(
       socket,
       :grants,
       Marketplaces.list_user_suppliers_for_user(socket.assigns.user)
     )}
  end

  defp empty_row,
    do: %{ref: System.unique_integer([:positive]), supplier_id: "", role: ""}

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_supplier_options(socket) do
    options = Marketplaces.list_suppliers() |> Enum.map(&{&1.name, &1.id})
    assign(socket, :supplier_options, options)
  end

  defp row_errors(row_errors, ref) do
    case row_errors[ref] do
      nil ->
        []

      changeset ->
        changeset.errors |> Enum.map(fn {_field, {msg, _opts}} -> msg end)
    end
  end
end
