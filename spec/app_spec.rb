# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe ResourceApi do
  let(:payload) do
    {
      sessionId: "s1",
      resourceType: "patient",
      resourceId: "p1",
      resource: { name: "Alice" },
      expiredAt: (Time.now + 3600).iso8601
    }
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def post_json(body)
    post "/resources", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  describe "POST /resources" do
    it "creates a new resource and returns 201" do
      post_json(payload)

      expect(last_response.status).to eq(201)
      expect(json_body["sessionId"]).to eq("s1")
      expect(json_body["resource"]).to eq("name" => "Alice")
    end

    it "updates an existing resource and returns 200" do
      post_json(payload)
      post_json(payload.merge(resource: { name: "Alice Updated" }))

      expect(last_response.status).to eq(200)
      expect(json_body["resource"]).to eq("name" => "Alice Updated")
    end

    it "returns 422 when a required field is missing" do
      post_json(sessionId: "s1")

      expect(last_response.status).to eq(422)
      expect(json_body["error"]).to eq("Missing field: resourceType")
    end
  end

  describe "GET /:session_id/:resource_type/:resource_id" do
    it "returns the resource when found and not expired" do
      post_json(payload)

      get "/s1/patient/p1"

      expect(last_response.status).to eq(200)
      expect(json_body["resourceId"]).to eq("p1")
    end

    it "returns 404 when the resource does not exist" do
      get "/s1/patient/unknown"

      expect(last_response.status).to eq(404)
    end

    it "returns 404 when the resource is expired" do
      post_json(payload.merge(expiredAt: (Time.now - 3600).iso8601))

      get "/s1/patient/p1"

      expect(last_response.status).to eq(404)
    end
  end

  describe "DELETE /sessions/:session_id" do
    it "expires all active resources in the session" do
      post_json(payload)

      delete "/sessions/s1"

      expect(last_response.status).to eq(200)
      expect(json_body).to eq("sessionId" => "s1", "expiredCount" => 1)
    end

    it "returns expiredCount 0 for an unknown session" do
      delete "/sessions/unknown"

      expect(last_response.status).to eq(200)
      expect(json_body).to eq("sessionId" => "unknown", "expiredCount" => 0)
    end
  end
end
