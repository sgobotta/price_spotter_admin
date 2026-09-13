defmodule PriceSpotterWeb.Admin.Extractor.CandidateLive.Index do
  @moduledoc """
  Admin-only review of pending EAN match candidates.

  Lists the pending candidate sets grouped by product, lets the reviewer
  expand a product to inspect each candidate's evidence, and approve or
  disapprove a candidate. Submitting a decision removes the set from the
  pending list immediately. Non-admins cannot reach the page (router
  `:admin` pipeline) nor drive the mutation events (guarded here too).
  """
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts
  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.EanMatchCandidateSet
  alias PriceSpotterWeb.Admin.ExpandableList

  @filter_keys ~w(name ean_candidate supplier category)

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if Accounts.can_review_ean_candidates?(socket.assigns[:current_user]) do
      {:ok,
       socket
       |> assign(
         page_title: gettext("Match candidates"),
         filters: empty_filters(),
         expanded: ExpandableList.new(),
         decision_confirm: nil
       )
       |> load_candidate_sets()}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Unauthorised"))
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("toggle_expand", %{"key" => key}, socket) do
    {:noreply, update(socket, :expanded, &ExpandableList.toggle(&1, key))}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:filters, take_filters(params))
     |> load_candidate_sets()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, empty_filters())
     |> load_candidate_sets()}
  end

  @impl true
  def handle_event(
        "prompt_decision",
        %{"set_id" => set_id, "ean" => ean, "decision" => decision},
        socket
      )
      when decision in ["approved", "disapproved"] do
    with :ok <- authorize(socket),
         %EanMatchCandidateSet{} = set <- find_set(socket, set_id),
         %{} = candidate <- find_candidate(set, ean) do
      {:noreply,
       assign(socket, :decision_confirm, %{
         set_id: set.id,
         ean: candidate.ean_candidate,
         decision: decision,
         product_name: set.product_name,
         supplier: candidate.supplier
       })}
    else
      _other -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_decision", _params, socket) do
    {:noreply, assign(socket, :decision_confirm, nil)}
  end

  @impl true
  def handle_event("confirm_decision", _params, socket) do
    case socket.assigns.decision_confirm do
      nil ->
        {:noreply, socket}

      confirm ->
        submit_decision(assign(socket, :decision_confirm, nil), confirm)
    end
  end

  defp submit_decision(socket, %{set_id: set_id, ean: ean, decision: decision}) do
    with :ok <- authorize(socket),
         %EanMatchCandidateSet{} = set <- find_set(socket, set_id) do
      set
      |> apply_decision(decision, ean)
      |> handle_decision_result(socket, decision)
    else
      _other -> {:noreply, socket}
    end
  end

  defp apply_decision(set, "approved", ean),
    do: Extractor.approve_candidate(set, ean)

  defp apply_decision(set, "disapproved", ean),
    do: Extractor.disapprove_candidate(set, ean)

  defp handle_decision_result({:ok, _result}, socket, decision) do
    {:noreply,
     socket
     |> put_flash(:info, decision_flash(decision))
     |> load_candidate_sets()}
  end

  defp handle_decision_result({:error, :candidate_not_found}, socket, _decision) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("That candidate is no longer available."))
     |> load_candidate_sets()}
  end

  defp handle_decision_result({:error, _reason}, socket, _decision) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       gettext("We couldn't save that decision. Please try again.")
     )
     |> load_candidate_sets()}
  end

  defp decision_flash("approved"), do: gettext("Candidate approved.")
  defp decision_flash("disapproved"), do: gettext("Candidate disapproved.")

  defp authorize(socket) do
    if Accounts.can_review_ean_candidates?(socket.assigns[:current_user]) do
      :ok
    else
      :error
    end
  end

  defp load_candidate_sets(socket) do
    sets =
      Extractor.list_pending_candidate_sets(
        active_filters(socket.assigns.filters)
      )

    socket
    |> assign(:candidate_sets, sets)
    |> assign(:expanded, prune_expanded(socket.assigns.expanded, sets))
  end

  # Drop expansion state for sets that no longer exist so a resolved product
  # doesn't leave a dangling expanded key around.
  defp prune_expanded(expanded, sets) do
    ids = MapSet.new(sets, & &1.id)

    Enum.reduce(expanded, ExpandableList.new(), fn key, acc ->
      if MapSet.member?(ids, key),
        do: ExpandableList.toggle(acc, key),
        else: acc
    end)
  end

  defp find_set(socket, set_id),
    do: Enum.find(socket.assigns.candidate_sets, &(&1.id == set_id))

  defp find_candidate(%EanMatchCandidateSet{candidates: candidates}, ean),
    do: Enum.find(candidates, &(&1.ean_candidate == ean))

  defp empty_filters, do: Map.new(@filter_keys, &{&1, ""})

  defp take_filters(params) do
    Map.new(@filter_keys, fn key ->
      {key, params |> Map.get(key, "") |> to_string() |> String.trim()}
    end)
  end

  # Only forward non-blank filters to the context, keyed by atom.
  defp active_filters(filters) do
    for {key, value} <- filters, value not in [nil, ""], into: %{} do
      {String.to_existing_atom(key), value}
    end
  end

  defp any_filters?(filters), do: Enum.any?(filters, fn {_k, v} -> v != "" end)

  defp format_price(nil), do: gettext("No price")
  defp format_price(price), do: "$#{Decimal.to_string(price, :normal)}"

  defp format_fetched_at(nil), do: gettext("Never fetched")

  defp format_fetched_at(datetime),
    do:
      PriceSpotterWeb.Utils.DatetimeUtils.human_readable_datetime(
        datetime,
        :shift_timezone
      )

  # Only render externally sourced URLs (scraper input) when they carry an
  # http/https scheme, so a persisted `javascript:`/`data:` value can't be
  # turned into an executable href or image src in the admin origin.
  defp safe_url(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme}} when scheme in ["http", "https"] -> url
      _other -> nil
    end
  end

  defp safe_url(_url), do: nil
end
