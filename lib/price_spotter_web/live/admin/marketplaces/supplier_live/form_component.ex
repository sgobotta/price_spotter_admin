defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.FormComponent do
  use PriceSpotterWeb, :live_component

  alias PriceSpotter.Marketplaces

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle><%= gettext("Use this form to manage supplier records in your database.") %></:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="supplier-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>Save Supplier</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{supplier: supplier} = assigns, socket) do
    changeset = Marketplaces.change_supplier(supplier)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"supplier" => supplier_params}, socket) do
    changeset =
      socket.assigns.supplier
      |> Marketplaces.change_supplier(supplier_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"supplier" => supplier_params}, socket) do
    save_supplier(socket, socket.assigns.action, supplier_params)
  end

  defp save_supplier(socket, :edit, supplier_params) do
    case Marketplaces.update_supplier(socket.assigns.supplier, supplier_params) do
      {:ok, supplier} ->
        notify_parent({:saved, supplier})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Supplier updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_supplier(socket, :new, supplier_params) do
    case Marketplaces.create_supplier(supplier_params) do
      {:ok, supplier} ->
        notify_parent({:saved, supplier})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Supplier created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
