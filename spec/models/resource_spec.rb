# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resource do
  def build_resource(expired_at:)
    id = SecureRandom.uuid

    DB[:resources].insert(
      id: id,
      session_id: "s1",
      resource_type: "patient",
      resource_id: "p1",
      resource: Sequel.pg_jsonb("name" => "Alice"),
      expired_at: expired_at
    )

    Resource[id]
  end

  describe "#expired?" do
    it "is true when expired_at is in the past" do
      resource = build_resource(expired_at: Time.now - 3600)

      expect(resource.expired?).to be(true)
    end

    it "is false when expired_at is in the future" do
      resource = build_resource(expired_at: Time.now + 3600)

      expect(resource.expired?).to be(false)
    end
  end
end
