defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent do
  use PriceSpotterWeb, :live_component

  alias PriceSpotter.Marketplaces

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header :if={@variant != :inline}>
        <%= @title %>
        <:subtitle>
          <%= gettext("Use this form to manage product records in your database.") %>
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class={fields_class(@variant)}>
          <.input field={@form[:name]} type="text" label={gettext("Name")} />
          <.input
            field={@form[:price]}
            type="number"
            label={gettext("Price")}
            step="any"
          />
          <.input field={@form[:category]} type="text" label={gettext("Category")} />
          <.input
            field={@form[:supplier_name]}
            type="text"
            label={gettext("Supplier name")}
          />
          <.input field={@form[:ean]} type="number" label={gettext("EAN")} />
          <.input
            field={@form[:internal_id]}
            type="text"
            label={gettext("Internal id")}
          />
          <.input
            field={@form[:img_url]}
            type="text"
            label={gettext("Img url")}
            container_class={span_class(@variant)}
          />
          <.input
            field={@form[:supplier_url]}
            type="text"
            label={gettext("Supplier url")}
            container_class={span_class(@variant)}
          />
        </div>

        <div class={actions_class(@variant)}>
          <.button phx-disable-with={gettext("Saving...")}>
            <%= gettext("Save Product") %>
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{product: product} = assigns, socket) do
    changeset = Marketplaces.change_product(product)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:variant, fn -> :modal end)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Marketplaces.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    save_product(socket, socket.assigns.action, product_params)
  end

  defp save_product(socket, :edit, product_params) do
    case Marketplaces.update_product(socket.assigns.product, product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Product updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_product(socket, :new, product_params) do
    case Marketplaces.create_product(product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Product created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp fields_class(:inline), do: "grid grid-cols-1 gap-3 sm:grid-cols-2"
  defp fields_class(_variant), do: "mt-2 space-y-8"

  defp actions_class(:inline), do: "mt-4 flex items-center justify-end"
  defp actions_class(_variant), do: "mt-6 flex items-center justify-end"

  defp span_class(:inline), do: "sm:col-span-2"
  defp span_class(_variant), do: ""
end
