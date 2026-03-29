defmodule ResearchCore.Theme.RawTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Raw

  describe "struct definition" do
    test "creates with raw_text" do
      raw = %Raw{
        raw_text: "Can order-book state help recalibrate cheap OTM prediction contracts?"
      }

      assert raw.raw_text ==
               "Can order-book state help recalibrate cheap OTM prediction contracts?"
    end

    test "defaults to nil for optional fields" do
      raw = %Raw{raw_text: "test theme"}

      assert raw.raw_text == "test theme"
      assert raw.source == nil
      assert raw.inserted_at == nil
      assert raw.updated_at == nil
    end

    test "accepts source metadata" do
      now = DateTime.utc_now()

      raw = %Raw{
        raw_text: "Find transferable literature from options skew",
        source: "slack-channel-research",
        inserted_at: now,
        updated_at: now
      }

      assert raw.source == "slack-channel-research"
      assert raw.inserted_at == now
      assert raw.updated_at == now
    end

    test "enforces raw_text as a required key" do
      assert_raise ArgumentError, fn ->
        struct!(Raw, %{})
      end
    end
  end
end
