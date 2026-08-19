# frozen_string_literal: true

require "spec_helper"
require "json"
require "time"

RSpec.describe ResourceApi do
  let(:payload) do
    {
      sessionId: "s1",
      resourceType: "patient",
      resourceId: "p1",
      resource: { name: "Alice" }
    }
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def post_json(body)
    post "/resources", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  def with_env(vars)
    original = vars.to_h { |key, _| [key, ENV.fetch(key, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
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

    it "sets expiredAt to now plus the default 7-day expiration" do
      with_env("EXPIRATION_MS" => nil) do
        post_json(payload)
      end

      expiration = Time.parse(json_body["expiredAt"]) - Time.parse(json_body["createdAt"])
      expect(expiration).to be_within(5).of(7 * 24 * 60 * 60)
    end

    it "honors a custom EXPIRATION_MS from the environment" do
      with_env("EXPIRATION_MS" => "60000") do
        post_json(payload)
      end

      expiration = Time.parse(json_body["expiredAt"]) - Time.parse(json_body["createdAt"])
      expect(expiration).to be_within(2).of(60)
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
      with_env("EXPIRATION_MS" => "-3600000") do
        post_json(payload)
      end

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
