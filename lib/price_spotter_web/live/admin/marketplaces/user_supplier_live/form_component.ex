defmodule PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.FormComponent do
  use PriceSpotterWeb, :live_component

  alias PriceSpotter.Marketplaces

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>
          <%= gettext(
            "Use this form to manage User Supplier records in your database."
          ) %>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="user_supplier-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:role]}
          type="select"
          label={gettext("Role")}
          prompt={gettext("Choose a value")}
          options={
            Ecto.Enum.values(
              PriceSpotter.Marketplaces.Relations.UserSupplier,
              :role
            )
          }
        />
        <.input
          field={@form[:user_id]}
          type="select"
          label={gettext("User")}
          prompt={gettext("Choose a value")}
          options={get_user_options()}
        />
        <.input
          field={@form[:supplier_id]}
          type="select"
          label={gettext("Supplier")}
          prompt={gettext("Choose a value")}
          options={get_supplier()}
        />
        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>
            <%= gettext("Save User supplier") %>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{user_supplier: user_supplier} = assigns, socket) do
    changeset = Marketplaces.change_user_supplier(user_supplier)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"user_supplier" => user_supplier_params},
        socket
      ) do
    changeset =
      socket.assigns.user_supplier
      |> Marketplaces.change_user_supplier(user_supplier_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user_supplier" => user_supplier_params}, socket) do
    save_user_supplier(socket, socket.assigns.action, user_supplier_params)
  end

  defp save_user_supplier(socket, :edit, user_supplier_params) do
    case Marketplaces.update_user_supplier(
           socket.assigns.user_supplier,
           user_supplier_params
         ) do
      {:ok, user_supplier} ->
        notify_parent({:saved, user_supplier})

        {:noreply,
         socket
         |> put_flash(:info, gettext("User supplier updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user_supplier(socket, :new, user_supplier_params) do
    case Marketplaces.create_user_supplier(user_supplier_params) do
      {:ok, user_supplier} ->
        notify_parent({:saved, user_supplier})

        {:noreply,
         socket
         |> put_flash(:info, gettext("User supplier created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp get_user_options do
    PriceSpotter.Accounts.list_users()
    |> Enum.reduce(Keyword.new(), fn %PriceSpotter.Accounts.User{
                                       email: email,
                                       id: id
                                     },
                                     acc ->
      Keyword.put(acc, String.to_atom(email), id)
    end)
  end

  defp get_supplier do
    PriceSpotter.Marketplaces.list_suppliers()
    |> Enum.reduce(Keyword.new(), fn %PriceSpotter.Marketplaces.Supplier{
                                       id: id,
                                       name: name
                                     },
                                     acc ->
      supplier_name =
        name
        |> String.replace("-", " ")
        |> String.capitalize()
        |> String.to_atom()

      Keyword.put(acc, supplier_name, id)
    end)
  end
end
